/* Compares wsd's replies with replies recorded from the real WindowServer (see docs/golden) for header-only requests.
 * A reply must match in size, complex bit and, unless the id is listed as state dependent, in every body byte. */
#include "ws_ipc.h"
#include "sls_wire.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static int fails, checked, skipped;

/* ids whose reply depends on live state (pids, times, displays, focus): size and complex bit only */
static const int env_differs[] = { 30139, 30140 };   /* the real session has processes with key focus, a fresh wsd has none */
static const int state_dependent[] = { 30243, 30247, 30356, 30363, 30110, 30054, 30149, 30308, 30309 };
static int is_env(int id) { for (size_t i = 0; i < sizeof env_differs / sizeof *env_differs; i++) if (env_differs[i] == id) return 1; return 0; }
static int is_state(int id) { for (size_t i = 0; i < sizeof state_dependent / sizeof *state_dependent; i++) if (state_dependent[i] == id) return 1; return 0; }

static int hexval(char c) { return c <= '9' ? c - '0' : (c | 32) - 'a' + 10; }

int main(int argc, char **argv)
{
	const char *path = argc > 1 ? argv[1] : "docs/golden/hdr-macos26.6.2.txt";
	FILE *f = fopen(path, "r");
	if (!f) { fprintf(stderr, "test_golden: no %s\n", path); return 1; }
	int fd = ws_ipc_connect(getenv("WS_SOCKET"));
	if (fd < 0) { fprintf(stderr, "test_golden: cannot connect\n"); return 1; }
	char line[8192];
	while (fgets(line, sizeof line, f)) {
		int id, rq, rid, size; unsigned bits; char hex[8000] = "";
		if (sscanf(line, "id=%d reqsize=%d reply_id=%d bits=%x size=%d hex=%7999s", &id, &rq, &rid, &bits, &size, hex) < 5 || rq != 0x18) continue;
		if (id >= 29000 && id < 29042) continue;                                 /* the session subsystem lives on another port */
		if (is_env(id)) continue;
		mach_msg_header_t req; memset(&req, 0, sizeof req);
		req.msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, MACH_MSG_TYPE_MAKE_SEND_ONCE); req.msgh_size = sizeof req; req.msgh_remote_port = 1; req.msgh_local_port = 1; req.msgh_id = id;
		struct iovec v = { &req, sizeof req };
		uint8_t rep[0x400]; int fds[4], nf = 0;
		if (ws_ipc_send(fd, &v, 1, NULL, 0)) { printf("FAIL %d: send\n", id); fails++; continue; }
		ssize_t n = ws_ipc_recv(fd, rep, sizeof rep, fds, &nf);
		checked++;
		mach_msg_header_t *r = (mach_msg_header_t *)rep;
		if (n != size || r->msgh_size != (uint32_t)size || (r->msgh_id != rid && !(r->msgh_id == 71)) || r->msgh_bits != bits) {
			printf("FAIL %d: reply size %zd (want %d) id %d (want %d) bits %08x (want %08x)\n", id, n, size, r->msgh_id, rid, r->msgh_bits, bits); fails++; continue;
		}
		if (is_state(id)) { skipped++; continue; }
		size_t blen = strlen(hex) / 2; uint8_t want[0x400];
		for (size_t i = 0; i < blen && i < sizeof want; i++) want[i] = (uint8_t)(hexval(hex[2 * i]) * 16 + hexval(hex[2 * i + 1]));
		int cx = (bits & 0x80000000u) != 0;
		for (size_t i = 0; i < blen; i++) {
			if (cx && i >= 4 && i < 4 + 4) continue;                              /* port names differ */
			if (rep[0x18 + i] != want[i]) { printf("FAIL %d: body byte %zu is %02x, real server says %02x\n", id, i, rep[0x18 + i], want[i]); fails++; break; }
		}
	}
	printf(fails ? "%d golden mismatches\n" : "golden replies: %d checked, all match (%d state dependent compared by shape only)\n", fails ? fails : checked, skipped);
	return fails != 0;
}
