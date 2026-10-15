/* Window properties, layer context binding and the ordered-in query, with the sizes, codes and layouts observed on the real server (lab/prop1.scen, win1.scen). */
#include "ws_client.h"
#include "ws_ipc.h"
#include "sls_wire.h"
#include "ws_region.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)
static void w32(uint8_t *b, size_t o, uint32_t v) { memcpy(b + o, &v, 4); }
static uint32_t r32(const uint8_t *b, size_t o) { uint32_t v; memcpy(&v, b + o, 4); return v; }

static void hdr(uint8_t *m, uint32_t size, int id, int complex)
{
	memset(m, 0, 0x18);
	w32(m, 0, (complex ? 0x80000000u : 0) | 0x1513); w32(m, 4, size); w32(m, 8, 1); w32(m, 12, 1); w32(m, 20, (uint32_t)id);
}

static int call(int fd, uint8_t *req, size_t n, uint8_t *rep, size_t cap)
{
	struct iovec v = { req, n }; int fds[4], nf = 0;
	if (ws_ipc_send(fd, &v, 1, NULL, 0)) return -1;
	return (int)ws_ipc_recv(fd, rep, cap, fds, &nf);
}

static int rc(int fd, uint8_t *req, size_t n) { uint8_t rep[0x100]; int got = call(fd, req, n, rep, sizeof rep); return got >= 0x24 ? (int)r32(rep, 0x20) : -9999; }

int main(void)
{
	ws_conn *c = ws_connect(NULL);
	if (!c) return 1;
	int fd = ws_conn_fd(c);
	ws_win w;
	if (ws_win_create(c, (ws_rect){ 10, 10, 100, 80 }, 0, &w)) return 1;
	uint8_t m[0x200], rep[0x400];
	const char *key = "kCGSWindowTitle"; uint32_t kl = 16, P = 16;
	const uint8_t data[8] = { 'b', 'p', 'l', 'i', 's', 't', '0', '0' };

	/* WindowIsOrderedIn: 0 before ordering in, 1 after */
	hdr(m, 0x24, SLS_MSG_WindowIsOrderedIn, 0); memcpy(m + 0x18, &WS_NDR, 8); w32(m, 0x20, w.id);
	CHECK(call(fd, m, 0x24, rep, sizeof rep) == 0x28 && r32(rep, 0x24) == 0);
	ws_win_order(c, &w, 1, 0);
	CHECK(call(fd, m, 0x24, rep, sizeof rep) == 0x28 && r32(rep, 0x24) == 1);
	w32(m, 0x20, 99999);
	CHECK(call(fd, m, 0x24, rep, sizeof rep) == 0x28 && r32(rep, 0x24) == 0);

	/* SetWindowProperty (OOL data), then Get returns it; Delete removes it */
	size_t size = P + 0x44;
	memset(m, 0, sizeof m); hdr(m, (uint32_t)size, SLS_MSG_SetWindowProperty, 1);
	w32(m, 0x18, 1); m[0x25] = 1; m[0x27] = 1; w32(m, 0x28, sizeof data); memcpy(m + 0x2c, &WS_NDR, 8);
	w32(m, 0x34, w.id); w32(m, 0x3c, kl); memcpy(m + 0x40, key, 15); w32(m, 0x40 + P, sizeof data); memcpy(m + size, data, sizeof data);
	CHECK(rc(fd, m, size + sizeof data) == 0);
	w32(m, 0x40 + P, 7);                                                              /* repeated size differs: type error */
	CHECK(rc(fd, m, size + sizeof data) == -300);
	w32(m, 0x40 + P, sizeof data); w32(m, 0x34, 99999);                              /* unknown window */
	CHECK(rc(fd, m, size + sizeof data) == 1000);

	uint8_t g[0x2c + 16]; memset(g, 0, sizeof g); hdr(g, 0x2c + 16, SLS_MSG_GetWindowProperty, 0); memcpy(g + 0x18, &WS_NDR, 8);
	w32(g, 0x20, w.id); w32(g, 0x28, kl); memcpy(g + 0x2c, key, 15);
	int n = call(fd, g, 0x2c + 16, rep, sizeof rep);
	CHECK(n == 0x38 + 8 && (r32(rep, 0) & 0x80000000u) && r32(rep, 4) == 0x38 && r32(rep, 0x28) == 8 && r32(rep, 0x34) == 8 && memcmp(rep + 0x38, data, 8) == 0);
	hdr(g, 0x2c + 16, SLS_MSG_DeleteWindowProperty, 0); memcpy(g + 0x18, &WS_NDR, 8); w32(g, 0x20, w.id); w32(g, 0x28, kl); memcpy(g + 0x2c, key, 15);
	CHECK(rc(fd, g, 0x2c + 16) == 0);
	hdr(g, 0x2c + 16, SLS_MSG_GetWindowProperty, 0);
	n = call(fd, g, 0x2c + 16, rep, sizeof rep);
	CHECK(n == 0x38 && r32(rep, 0x34) == 0);                                          /* gone: an empty descriptor */
	hdr(g, 0x2c + 12, SLS_MSG_GetWindowProperty, 0);
	CHECK(rc(fd, g, 0x2c + 12) == -304);                                              /* wrong size */

	/* SetWindowLayerContext: the owner may bind a context; a stranger's window gives 1002 */
	hdr(m, 0x28, SLS_MSG_SetWindowLayerContext, 0); memcpy(m + 0x18, &WS_NDR, 8); w32(m, 0x20, w.id); w32(m, 0x24, 12345);
	CHECK(rc(fd, m, 0x28) == 0);
	w32(m, 0x20, 99999);
	CHECK(rc(fd, m, 0x28) == 1002);

	/* connection properties: Set (OOL), Get returns it, an unknown name gives an empty descriptor */
	{
		uint8_t cm[0x80 + 8]; size_t csz = P + 0x44; memset(cm, 0, sizeof cm);
		hdr(cm, (uint32_t)csz, SLS_MSG_SetConnectionProperty, 1);
		w32(cm, 0x18, 1); cm[0x25] = 1; cm[0x27] = 1; w32(cm, 0x28, 8); memcpy(cm + 0x2c, &WS_NDR, 8);
		w32(cm, 0x34, (uint32_t)ws_conn_id(c)); w32(cm, 0x3c, kl); memcpy(cm + 0x40, key, 15); w32(cm, 0x40 + P, 8); memcpy(cm + csz, data, 8);
		CHECK(rc(fd, cm, csz + 8) == 0);
		uint8_t q[0x2c + 16]; memset(q, 0, sizeof q); hdr(q, 0x2c + 16, SLS_MSG_GetConnectionProperty, 0); memcpy(q + 0x18, &WS_NDR, 8);
		w32(q, 0x20, (uint32_t)ws_conn_id(c)); w32(q, 0x28, kl); memcpy(q + 0x2c, key, 15);
		int gn = call(fd, q, sizeof q, rep, sizeof rep);
		CHECK(gn == 0x38 + 8 && r32(rep, 0x34) == 8 && memcmp(rep + 0x38, data, 8) == 0);
		memcpy(q + 0x2c, "kCGSOtherKey000", 15);
		gn = call(fd, q, sizeof q, rep, sizeof rep);
		CHECK(gn == 0x38 && r32(rep, 0x34) == 0);
	}
	/* notification interests and the opaque shape: sizes checked as on the real server, then accepted */
	{
		uint8_t nm[0x24 + 8]; memset(nm, 0, sizeof nm); hdr(nm, 0x24 + 8, SLS_MSG_SetConnectionNotifyInterests, 0); memcpy(nm + 0x18, &WS_NDR, 8); w32(nm, 0x20, 2); w32(nm, 0x24, 0x4b5); w32(nm, 0x28, 0x5e0);
		CHECK(rc(fd, nm, 0x24 + 8) == 0);
		w32(nm, 0x20, 3);
		CHECK(rc(fd, nm, 0x24 + 8) == -304);                                              /* count and size disagree */
		uint8_t os[0x3c + 8]; memset(os, 0, sizeof os); hdr(os, 0x3c, SLS_MSG_SetWindowOpaqueShape, 1);
		w32(os, 0x18, 1); os[0x25] = 1; os[0x27] = 1; w32(os, 0x28, 8); memcpy(os + 0x2c, &WS_NDR, 8); w32(os, 0x34, w.id); w32(os, 0x38, 8);
		CHECK(rc(fd, os, 0x3c + 8) == 0);
		w32(os, 0x38, 4);
		CHECK(rc(fd, os, 0x3c + 8) == -300);
		uint8_t cs[0x3c + 16]; memset(cs, 0, sizeof cs); hdr(cs, 0x3c, SLS_MSG_CopySpacesForWindows, 1);
		w32(cs, 0x18, 1); cs[0x25] = 1; cs[0x27] = 1; w32(cs, 0x28, 8); memcpy(cs + 0x2c, &WS_NDR, 8); w32(cs, 0x34, 0); w32(cs, 0x38, 2); w32(cs, 0x3c, w.id); w32(cs, 0x40, w.id);
		int sn = call(fd, cs, 0x3c + 8, rep, sizeof rep);
		CHECK(sn == 0x38 + 16 && r32(rep, 0x34) == 2 && r32(rep, 0x28) == 16);          /* two windows, one space each (u64 ids) */
	}

	/* ShapeWindow resizes (two OOL regions); GetWindowShape reads the shape back */
	{
		uint8_t reg[64]; size_t rn = ws_region_serialize(&(ws_rect){ 0, 0, 150, 90 }, 1, reg, sizeof reg);
		uint8_t sw[0x58 + 80]; memset(sw, 0, sizeof sw); hdr(sw, 0x58, SLS_MSG_ShapeWindow, 1);
		w32(sw, 0x18, 2); sw[0x25] = 1; sw[0x27] = 1; w32(sw, 0x28, (uint32_t)rn); sw[0x35] = 1; sw[0x37] = 1; w32(sw, 0x38, 0);
		memcpy(sw + 0x3c, &WS_NDR, 8); w32(sw, 0x44, w.id); w32(sw, 0x50, (uint32_t)rn); w32(sw, 0x54, 0); memcpy(sw + 0x58, reg, rn);
		CHECK(rc(fd, sw, 0x58 + rn) == 0);
		ws_rect fr; CHECK(ws_win_get_bounds(c, &w, &fr) == 0 && fr.w == 150 && fr.h == 90 && fr.x == 10 && fr.y == 10);
		hdr(g, 0x24, SLS_MSG_GetWindowShape, 0); memcpy(g + 0x18, &WS_NDR, 8); w32(g, 0x20, w.id);
		int sn = call(fd, g, 0x24, rep, sizeof rep);
		CHECK(sn > 0x38 && r32(rep, 0x28) == (uint32_t)(sn - 0x38));
		ws_rect *rr = NULL; int nrr = 0; ws_rect bbx;
		CHECK(ws_region_parse(rep + 0x38, (uint32_t)(sn - 0x38), &rr, &nrr, &bbx) == 0 && bbx.w == 150 && bbx.h == 90); free(rr);
		w32(g, 0x20, 99999);
		CHECK(rc(fd, g, 0x24) == 1000);
	}
	ws_server_quit(c);
	printf(failures ? "%d failures\n" : "window extension routines: all checks passed\n", failures);
	return failures != 0;
}
