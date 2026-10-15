/* The generated acceptors (src/sls_generic.c): every exact-size routine answers its decompiled request size with a success reply of the table's reply size, and a request of the
 * wrong size with -304. Cases come from test/generic_cases.txt (id, request size, complex, reply size). */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <sys/uio.h>
#include "ws_ipc.h"
#include "mach_compat.h"
int main(void)
{
	int fd = ws_ipc_connect(getenv("WS_SOCKET"));
	FILE *f = fopen("test/generic_cases.txt", "r");
	if (fd < 0 || !f) { fprintf(stderr, "test_generic: cannot connect / no cases\n"); return 1; }
	char line[256]; int checked = 0, fails = 0;
	while (fgets(line, sizeof line, f)) {
		int id, sz, cx, rs;
		if (line[0] == '#' || sscanf(line, "%d %d %d %d", &id, &sz, &cx, &rs) != 4) continue;
		uint8_t m[512]; memset(m, 0, sizeof m);
		mach_msg_header_t *h = (void *)m; h->msgh_id = id; h->msgh_size = sz; h->msgh_bits = 0x13 | (cx ? 0x80000000u : 0);
		if (sz >= 0x20) memcpy(m + 0x18, &WS_NDR, 8);
		if (cx) { uint32_t one = 1; memcpy(m + 0x18, &one, 4); }
		struct iovec v = { m, (size_t)sz }; uint8_t r[4096]; int fds[8], nf = 0;
		if (ws_ipc_send(fd, &v, 1, NULL, 0)) { printf("FAIL %d: send\n", id); fails++; continue; }
		ssize_t n = ws_ipc_recv(fd, r, sizeof r, fds, &nf);
		mach_msg_header_t *rh = (void *)r;
		int want = rs <= 0x24 ? 0x24 : rs; checked++;
		if (n != want || rh->msgh_id != id + 100) { printf("FAIL %d: reply id %d size %zd (want id %d size %d)\n", id, rh->msgh_id, n, id + 100, want); fails++; continue; }
		if (rs <= 0x24 && *(int32_t *)(r + 0x20) != 0) { printf("FAIL %d: retcode %d\n", id, *(int32_t *)(r + 0x20)); fails++; }
		h->msgh_size = sz + 4;                                                     /* wrong size */
		struct iovec v2 = { m, (size_t)sz + 4 };
		ws_ipc_send(fd, &v2, 1, NULL, 0); n = ws_ipc_recv(fd, r, sizeof r, fds, &nf);
		if (*(int32_t *)(r + 0x20) != -304 && rh->msgh_id != 71) { printf("FAIL %d: wrong size not refused (%d)\n", id, *(int32_t *)(r + 0x20)); fails++; }
	}
	printf(fails ? "%d generic mismatches\n" : "generic acceptors: %d checked, all as the decompiled routines require\n", fails ? fails : checked);
	return fails != 0;
}
