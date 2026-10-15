/* the lab scenario runner for wsd: runs the same scripts as scen.c (new_window, order, level, raw ...) against wsd instead of the real WindowServer and prints the replies in the same format,
 * so the two outputs can be compared line by line (lab/diff_scen.py). Window ids and connection ids differ between the two servers: the comparison masks them. */
#include "ws_client.h"
#include "ws_ipc.h"
#include "mach_compat.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <sys/uio.h>

static ws_conn *conn; static int cid;
static struct { char name[32]; ws_win w; } wins[32]; static int nwins;
static uint32_t wid_of(const char *n) { for (int i = 0; i < nwins; i++) if (!strcmp(wins[i].name, n)) return wins[i].w.id; return 0; }
static ws_win *win_of(const char *n) { for (int i = 0; i < nwins; i++) if (!strcmp(wins[i].name, n)) return &wins[i].w; return NULL; }

static void raw(int id, char **tok, int nt)
{
	uint8_t req[0x2000]; memset(req, 0, sizeof req); size_t n = 0x18;
	int complex = 0; size_t nlen_at = 0;
	uint8_t payload[0x4000]; size_t plen = 0;
	for (int i = 0; i < nt; i++) {
		char *t = tok[i];
		if (!strcmp(t, "nlen")) { nlen_at = n; n += 4; continue; }
		if (!strncmp(t, "ool:", 4)) {
			size_t hl = strlen(t + 4) / 2;
			for (size_t k = 0; k < hl; k++) { unsigned v; sscanf(t + 4 + 2 * k, "%2x", &v); payload[plen++] = (uint8_t)v; }
			uint32_t one = 1, sz = (uint32_t)hl; uint8_t fl[4] = { 0, 1, 0, 1 };
			memcpy(req + 0x18, &one, 4); memcpy(req + 0x24, fl, 4); memcpy(req + 0x28, &sz, 4); n = 0x2c; complex = 1;
		}
		else if (!strcmp(t, "ndr")) { static const uint8_t ndr[8] = { 0, 0, 0, 0, 1, 0, 0, 0 }; memcpy(req + n, ndr, 8); n += 8; }
		else if (!strncmp(t, "u32:", 4) || !strncmp(t, "i32:", 4)) { uint32_t v = (uint32_t)strtoll(t + 4, NULL, 0); memcpy(req + n, &v, 4); n += 4; }
		else if (!strncmp(t, "wid:", 4)) { uint32_t v = wid_of(t + 4); memcpy(req + n, &v, 4); n += 4; }
		else if (!strcmp(t, "cid")) { uint32_t v = (uint32_t)cid; memcpy(req + n, &v, 4); n += 4; }
		else if (!strncmp(t, "f32:", 4)) { float v = strtof(t + 4, NULL); memcpy(req + n, &v, 4); n += 4; }
		else if (!strncmp(t, "f64:", 4)) { double v = strtod(t + 4, NULL); memcpy(req + n, &v, 8); n += 8; }
		else if (!strncmp(t, "pk:", 3) || !strncmp(t, "pkwid:", 6)) {
			int64_t v = !strncmp(t, "pkwid:", 6) ? (int64_t)wid_of(t + 6) : strtoll(t + 3, NULL, 0);
			if (v == 0 || v == -1) req[n++] = v == 0 ? 0 : 1;
			else { uint64_t u = v < 0 ? (uint64_t)~v : (uint64_t)v; int nb = 1; while (nb < 8 && (u >> (8 * nb))) nb++; req[n++] = (uint8_t)((nb << 4) | (v < 0 ? 1 : 0)); for (int b = nb - 1; b >= 0; b--) req[n++] = (uint8_t)(u >> (8 * b)); }
		}
		else if (!strncmp(t, "pad:", 4)) n += (size_t)atoi(t + 4);
		else if (!strncmp(t, "hex:", 4)) { for (const char *s = t + 4; s[0] && s[1]; s += 2) { unsigned v; sscanf(s, "%2x", &v); req[n++] = (uint8_t)v; } }
		else if (!strncmp(t, "str:", 4)) { size_t l = strlen(t + 4); memcpy(req + n, t + 4, l); n += (l + 3) & ~3u; }
	}
	if (nlen_at) { uint32_t l = (uint32_t)(n - nlen_at - 4); memcpy(req + nlen_at, &l, 4); n = (n + 3) & ~(size_t)3; }
	mach_msg_header_t *hd = (mach_msg_header_t *)req;
	hd->msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, MACH_MSG_TYPE_MAKE_SEND_ONCE) | (complex ? MACH_MSGH_BITS_COMPLEX : 0);
	hd->msgh_size = (uint32_t)n; hd->msgh_remote_port = 1; hd->msgh_local_port = 1; hd->msgh_id = id;
	struct iovec v[2] = { { req, n }, { payload, plen } };
	if (ws_ipc_send(ws_conn_fd(conn), v, plen ? 2 : 1, NULL, 0)) { printf("raw %d send-error\n", id); return; }
	static uint8_t rep[0x20000]; int fds[8], nf = 0; memset(rep, 0, sizeof rep);
	ssize_t got = ws_ipc_recv(ws_conn_fd(conn), rep, sizeof rep, fds, &nf);
	if (got < 0x18) { printf("raw %d recv-error\n", id); return; }
	mach_msg_header_t *r = (mach_msg_header_t *)rep;
	printf("raw %d reqsize=%zu -> reply_id=%d bits=%08x size=%u hex=", id, n, r->msgh_id, r->msgh_bits, r->msgh_size);
	for (uint32_t i = 0x18; i < r->msgh_size && i < 0x600; i++) printf("%02x", rep[i]);
	printf("\n");
	if ((r->msgh_bits & MACH_MSGH_BITS_COMPLEX) && r->msgh_size >= 0x2c && *(uint32_t *)(rep + 0x18) >= 1 && rep[0x27] == 1) {   /* out-of-line data (appended after the message here) */
		uint32_t sz = *(uint32_t *)(rep + 0x28);
		printf("ool size=%u hex=", sz);
		for (uint32_t i = 0; i < sz && i < 0x1000 && r->msgh_size + i < (uint32_t)got; i++) printf("%02x", rep[r->msgh_size + i]);
		printf("\n");
	}
}

int main(int argc, char **argv)
{
	setvbuf(stdout, NULL, _IONBF, 0);
	conn = ws_connect(NULL);
	if (!conn || argc < 2) { fprintf(stderr, "usage: scen_wsd file.scen (WS_SOCKET set)\n"); return 1; }
	cid = ws_conn_id(conn);
	printf("cid=%d port=wsd\n", cid);
	FILE *f = fopen(argv[1], "r"); char line[4096];
	while (fgets(line, sizeof line, f)) {
		char *tok[64]; int nt = 0;
		for (char *p = strtok(line, " \t\r\n"); p && nt < 64; p = strtok(NULL, " \t\r\n")) tok[nt++] = p;
		if (!nt || tok[0][0] == '#') continue;
		if (!strcmp(tok[0], "new_window") && nt >= 6) {
			ws_win w; int e = ws_win_create(conn, (ws_rect){ atoi(tok[2]), atoi(tok[3]), atoi(tok[4]), atoi(tok[5]) }, 0, &w);
			strncpy(wins[nwins].name, tok[1], 31); wins[nwins++].w = w;
			printf("# new_window %s err=%d wid=%u\n", tok[1], e, w.id);
		} else if (!strcmp(tok[0], "order") && nt >= 3) {
			ws_win *w = win_of(tok[1]); int mode = !strcmp(tok[2], "above") ? 1 : !strcmp(tok[2], "below") ? -1 : 0;
			printf("# order %s %s err=%d\n", tok[1], tok[2], w ? ws_win_order(conn, w, mode, 0) : -1);
		} else if (!strcmp(tok[0], "level") && nt >= 3) { ws_win *w = win_of(tok[1]); printf("# level err=%d\n", w ? ws_win_set_level(conn, w, atoi(tok[2])) : -1); }
		else if (!strcmp(tok[0], "port")) { /* wsd has a single socket for every subsystem */ }
		else if (!strcmp(tok[0], "raw") && nt >= 2) { printf("# raw\n"); raw(atoi(tok[1]), tok + 2, nt - 2); }
	}
	return 0;
}
