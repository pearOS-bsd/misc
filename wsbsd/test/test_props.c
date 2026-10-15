/* Window properties, layer context binding and the ordered-in query, with the sizes, codes and layouts observed on the real server (lab/prop1.scen, win1.scen). */
#include "ws_client.h"
#include "ws_ipc.h"
#include "sls_wire.h"
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
	ws_server_quit(c);
	printf(failures ? "%d failures\n" : "window extension routines: all checks passed\n", failures);
	return failures != 0;
}
