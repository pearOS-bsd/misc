/* The CoreAnimation render server of wsd: the commits of the clients arrive from carender-stub (the Mach side, one per system) on a stream socket, are decoded and composed by
 * ca_scene.c into the backing store of a window of wsd, and that window goes through the compositor of wsd like any other.
 *
 * Wire (SOCK_STREAM): records  u32 type, u32 length, payload.
 *   type 1: a commit message (the bytes of the Mach message of the render server protocol, from the header on)
 *   type 2: out-of-line data of a message that follows: u32 message number, u32 descriptor, the bytes (sent before the message that names them)
 * The window: one for the whole scene for now (the screen's size).  WSD_CA_LEVEL sets its level (default 5). */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/stat.h>
#include "ws.h"
#include "ca_scene.h"
#include "wsd_priv.h"

#define CA_MAXC 4
#define CA_OOLN 128
static struct { int fd; uint8_t *buf; size_t n, cap; } cl[CA_MAXC];
static struct { int used, msg, desc; uint8_t *data; size_t size; } ool[CA_OOLN];
static ws_wid ca_win;

static uint8_t *ool_take(void *ctx, int msg, int desc, size_t *sz)
{
	(void)ctx;
	for (int i = 0; i < CA_OOLN; i++)
		if (ool[i].used && ool[i].msg == msg && ool[i].desc == desc) { uint8_t *d = ool[i].data; *sz = ool[i].size; ool[i].used = 0; return d; }
	return NULL;
}
static void ool_put(int msg, int desc, const uint8_t *d, size_t n)
{
	int slot = -1;
	for (int i = 0; i < CA_OOLN; i++) if (!ool[i].used) { slot = i; break; }
	if (slot < 0) { slot = 0; for (int i = 1; i < CA_OOLN; i++) if (ool[i].msg < ool[slot].msg) slot = i; free(ool[slot].data); }	/* full: the oldest goes */
	uint8_t *c = malloc(n ? n : 1);
	if (!c) { ool[slot].used = 0; return; }
	memcpy(c, d, n);
	ool[slot].used = 1; ool[slot].msg = msg; ool[slot].desc = desc; ool[slot].data = c; ool[slot].size = n;
}

int wsd_ca_listen(const char *path)
{
	struct sockaddr_un sa;
	int s;

	memset(&sa, 0, sizeof sa);
	sa.sun_family = AF_UNIX; strlcpy(sa.sun_path, path, sizeof sa.sun_path);
	if ((s = socket(AF_UNIX, SOCK_STREAM, 0)) < 0) return -1;
	unlink(path);
	mode_t old = umask(0177);
	int b = bind(s, (struct sockaddr *)&sa, sizeof sa);
	umask(old);
	if (b < 0 || listen(s, 4) < 0) { close(s); return -1; }
	ca_set_ool_loader(ool_take, NULL);
	for (int i = 0; i < CA_MAXC; i++) cl[i].fd = -1;
	return s;
}

int wsd_ca_accept(int ls)
{
	int fd = accept(ls, NULL, NULL);
	if (fd < 0) return -1;
	fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK);
	for (int i = 0; i < CA_MAXC; i++)
		if (cl[i].fd < 0) { cl[i].fd = fd; cl[i].n = 0; return fd; }
	close(fd);
	return -1;
}

int wsd_ca_client(int fd) { for (int i = 0; i < CA_MAXC; i++) if (cl[i].fd == fd && fd >= 0) return 1; return 0; }

static void repaint(ws_server *srv, int sw, int sh)
{
	ws_surface *b;
	if (!ca_win) {
		const char *lv = getenv("WSD_CA_LEVEL");
		ca_win = ws_create_window(srv, (ws_rect){ 0, 0, sw, sh });
		if (!ca_win) return;
		ws_set_window_level(srv, ca_win, lv ? atoi(lv) : 5);
		ws_order_window(srv, ca_win, WS_ABOVE, 0);
	}
	if ((b = ws_window_backing(srv, ca_win)) == NULL) return;
	ca_paint(b->px, b->w, b->h, (int)b->stride);
	ws_server_invalidate(srv);
}

/* data is readable on the client's descriptor: returns -1 when it closed (the caller drops it from its queue) */
int wsd_ca_read(int fd, ws_server *srv, int sw, int sh)
{
	int ci = -1, fed = 0;
	for (int i = 0; i < CA_MAXC; i++) if (cl[i].fd == fd) ci = i;
	if (ci < 0) return -1;
	for (;;) {
		if (cl[ci].cap - cl[ci].n < 65536) { size_t nc = cl[ci].cap ? cl[ci].cap * 2 : 262144; uint8_t *nb = realloc(cl[ci].buf, nc); if (!nb) return -1; cl[ci].buf = nb; cl[ci].cap = nc; }
		ssize_t r = read(fd, cl[ci].buf + cl[ci].n, cl[ci].cap - cl[ci].n);
		if (r <= 0) {
			if (r < 0 && (errno == EAGAIN || errno == EINTR)) break;
			close(fd); cl[ci].fd = -1; free(cl[ci].buf); cl[ci].buf = NULL; cl[ci].cap = cl[ci].n = 0;
			return -1;
		}
		cl[ci].n += (size_t)r;
		size_t p = 0;
		while (cl[ci].n - p >= 8) {
			uint32_t type, len;
			memcpy(&type, cl[ci].buf + p, 4); memcpy(&len, cl[ci].buf + p + 4, 4);
			if (len > (64u << 20)) { close(fd); cl[ci].fd = -1; return -1; }
			if (cl[ci].n - p - 8 < len) break;
			const uint8_t *pl = cl[ci].buf + p + 8;
			if (type == 1) { ca_feed(pl, len); fed = 1; }
			else if (type == 2 && len >= 8) { uint32_t m, d; memcpy(&m, pl, 4); memcpy(&d, pl + 4, 4); ool_put((int)m, (int)d, pl + 8, len - 8); }
			p += 8 + len;
		}
		if (p) { memmove(cl[ci].buf, cl[ci].buf + p, cl[ci].n - p); cl[ci].n -= p; }
		if (r < (ssize_t)(cl[ci].cap - 65536)) break;		/* a short read: nothing more now */
	}
	if (fed) repaint(srv, sw, sh);
	return 0;
}
