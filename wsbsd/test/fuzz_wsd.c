/* fuzz_wsd: throws random well-framed requests (every SkyLight id 29000..34100 plus the private ids, random sizes and bytes, optional OOL descriptor) at a running wsd and
 * checks it keeps answering. Run under a sanitizer build:  WS_SOCKET=... ./fuzz_wsd [iterations] [seed] */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "ws_ipc.h"
#include "sls_wire.h"
#include "mach_compat.h"
#include "fuzz_sizes.inc"

static uint64_t rs;
static uint32_t rnd(void) { rs ^= rs << 13; rs ^= rs >> 7; rs ^= rs << 17; return (uint32_t)(rs >> 11); }

int main(int argc, char **argv)
{
	int iters = argc > 1 ? atoi(argv[1]) : 20000; rs = argc > 2 ? strtoull(argv[2], 0, 10) : 88172645463325252ull;
	const char *path = getenv("WS_SOCKET"); if (!path) { fprintf(stderr, "WS_SOCKET not set\n"); return 2; }
	int fd = ws_ipc_connect(path); if (fd < 0) { fprintf(stderr, "connect failed\n"); return 2; }
	static uint8_t m[0x12100], rep[WS_IPC_RECV_CAP];
	int answered = 0, reconnects = 0;
	for (int i = 0; i < iters; i++) {
		static const int ranges[][2] = { { 29000, 29040 }, { 30000, 30660 }, { 32000, 32080 }, { 33000, 33060 }, { 34000, 34030 }, { 39001, 39030 }, { 39100, 39102 } };
		int r = rnd() % 7, id = ranges[r][0] + (int)(rnd() % (ranges[r][1] - ranges[r][0] + 1));
		size_t n = (rnd() % 4 == 0) ? 0x18 + (rnd() % 0x2100) : 0x18 + 4 * (rnd() % 40);
		if (rnd() % 10 < 7) { int j = (int)(rnd() % (sizeof fuzz_sizes / sizeof *fuzz_sizes)); id = fuzz_sizes[j].id; n = (size_t)fuzz_sizes[j].size; if (rnd() % 5 == 0) n += 4 * (rnd() % 3); }   /* mostly exact sizes, so the handlers get past the size check */
		n &= ~(size_t)3; if (n < 0x18) n = 0x18;
		for (size_t k = 0; k < n; k++) m[k] = (uint8_t)(rnd() % 3 == 0 ? rnd() : (rnd() % 5 == 0 ? 0xff : 0));
		mach_msg_header_t *h = (mach_msg_header_t *)m;
		h->msgh_bits = (rnd() % 6 == 0) ? MACH_MSGH_BITS_COMPLEX : 0; h->msgh_size = (rnd() % 8 == 0) ? (uint32_t)(rnd() % 0x3000) : (uint32_t)n;
		if ((h->msgh_bits & MACH_MSGH_BITS_COMPLEX) && n >= 0x2c) { uint32_t one = 1; memcpy(m + 0x18, &one, 4); }               /* a count of 1 descriptor slot */
		h->msgh_id = id; h->msgh_remote_port = 0; h->msgh_local_port = 0;
		size_t total = n;
		if ((h->msgh_bits & MACH_MSGH_BITS_COMPLEX) && n >= 0x2c && rnd() % 4) {                      /* one out-of-line descriptor with real appended bytes (a region / plist / array shaped blob) */
			uint32_t k = rnd() % 0x200; static const uint8_t fl[4] = { 0, 1, 0, 1 };
			memset(m + 0x1c, 0, 8); memcpy(m + 0x24, fl, 4); memcpy(m + 0x28, &k, 4);
			for (uint32_t q = 0; q < k && n + k <= sizeof m; q++) m[n + q] = (uint8_t)(rnd() % 4 == 0 ? rnd() : (q < 8 ? 0 : (q & 3) == 0 ? 1 : 0));
			if (n + k <= sizeof m) total = n + k;
		}
		struct iovec v = { m, total };
		if (ws_ipc_send(fd, &v, 1, NULL, 0)) { close(fd); fd = ws_ipc_connect(path); reconnects++; if (fd < 0) { printf("FAIL: wsd gone at iteration %d id %d\n", i, id); return 1; } continue; }
		int fds[WS_IPC_MAX_FDS], nf = 0;
		ssize_t g = ws_ipc_recv(fd, rep, sizeof rep, fds, &nf);
		for (int k = 0; k < nf; k++) close(fds[k]);
		if (g > 0) answered++;
		else { close(fd); fd = ws_ipc_connect(path); reconnects++; if (fd < 0) { printf("FAIL: wsd gone at iteration %d id %d\n", i, id); return 1; } }
	}
	printf("fuzz: %d requests, %d answered, %d reconnects, wsd alive\n", iters, answered, reconnects);
	return 0;
}
