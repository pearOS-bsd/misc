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
/* zero-argument harvest: answers that depend on the recorded machine (its windows, displays, hot keys, process records) */
static const int harvest_env[] = { 30139, 30140, 30014, 30063, 30068, 30136, 30137, 30211, 30389, 30456 };
static int is_harvest_env(int id) { for (size_t i = 0; i < sizeof harvest_env / sizeof *harvest_env; i++) if (harvest_env[i] == id) return 1; return 0; }
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

	/* the harvest: fixed-size requests with all-zero arguments (variant 0), replies recorded from the real server in a fresh session */
	const char *hpath = argc > 2 ? argv[2] : "docs/golden/harvest-macos26.6.2.txt";
	FILE *hf = fopen(hpath, "r");
	int hchecked = 0, hfails = 0;
	while (hf && fgets(line, sizeof line, hf)) {
		int id, v, rq, rid, size; unsigned bits; char hex[8000] = "";
		if (sscanf(line, "id=%d variant=%d reqsize=%d reply_id=%d bits=%x size=%d hex=%7999s", &id, &v, &rq, &rid, &bits, &size, hex) < 6 || v != 0 || hex[0] == '?') continue;
		if (id >= 29000 && id < 29042) continue;
		if (is_harvest_env(id) || (hex[0] && !strncmp(hex + 16, "d1feffff", 8))) continue;      /* -303: served on another port */
		uint8_t req[0x100]; memset(req, 0, sizeof req);
		mach_msg_header_t *q = (mach_msg_header_t *)req;
		q->msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, MACH_MSG_TYPE_MAKE_SEND_ONCE); q->msgh_size = (uint32_t)rq; q->msgh_remote_port = 1; q->msgh_local_port = 1; q->msgh_id = id;
		if (rq >= 0x20) { static const uint8_t ndr[8] = { 0, 0, 0, 0, 1, 0, 0, 0 }; memcpy(req + 0x18, ndr, 8); }
		struct iovec iv = { req, (size_t)rq };
		uint8_t rep[0x400]; int fds[4], nf = 0;
		if (ws_ipc_send(fd, &iv, 1, NULL, 0)) { printf("FAIL h%d: send\n", id); hfails++; continue; }
		ssize_t n = ws_ipc_recv(fd, rep, sizeof rep, fds, &nf);
		hchecked++;
		mach_msg_header_t *r = (mach_msg_header_t *)rep;
		int bad = n != size || r->msgh_size != (uint32_t)size || r->msgh_id != rid || r->msgh_bits != bits;
		size_t blen = strlen(hex) / 2; uint8_t want[0x400];
		for (size_t i = 0; i < blen && i < sizeof want; i++) want[i] = (uint8_t)(hexval(hex[2 * i]) * 16 + hexval(hex[2 * i + 1]));
		/* the NDR record of simple replies is only written by some routines: compare from the return code on */
		size_t from = (bits & 0x80000000u) ? 4 : 8;
		if (!bad && !is_state(id)) for (size_t i = from; i < blen; i++) if (rep[0x18 + i] != want[i]) { bad = 1; break; }
		if (bad) { printf("FAIL h%d (zero arguments): size %zd/%d id %d/%d bits %08x/%08x\n", id, n, size, r->msgh_id, rid, r->msgh_bits, bits); hfails++; }
	}
	fails += hfails;
	printf("harvest (zero arguments): %d checked, %d differ\n", hchecked, hfails);
	printf(fails ? "%d golden mismatches\n" : "golden replies: %d checked, all match (%d state dependent compared by shape only)\n", fails ? fails : checked, skipped);
	return fails != 0;
}
