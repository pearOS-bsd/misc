/* FreeBSD display (DRM/KMS via drm-kmod + libdrm) and input (evdev) backends. UNTESTED, see ws_backend.h.
 * Display: two dumb buffers, mode set once on the first connected connector's preferred mode, page flips afterwards.
 * Input: raw evdev; relative pointer motion is accumulated into an absolute position, key codes are passed through
 * as evdev codes. The compositor stays the CPU one; a GL compositor would render to GBM buffers instead. */
#ifdef WS_KMS
#include "ws_backend.h"
#include "ws_input.h"
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <xf86drm.h>
#include <xf86drmMode.h>
#include <dev/evdev/input.h>

struct ws_kms {
	int fd;
	uint32_t crtc, conn;
	drmModeModeInfo mode;
	struct { uint32_t handle, fb; ws_surface *s; } buf[2];
	int front, flip_pending;
	drmModeCrtc *saved;
	struct { uint32_t handle; uint8_t *map; size_t size; uint32_t w, h; int on; } cur;   /* hardware cursor buffer */
};

static int make_buf(ws_kms *k, int i)
{
	struct drm_mode_create_dumb c = { .width = k->mode.hdisplay, .height = k->mode.vdisplay, .bpp = 32 };
	if (drmIoctl(k->fd, DRM_IOCTL_MODE_CREATE_DUMB, &c)) return -1;
	k->buf[i].handle = c.handle;
	if (drmModeAddFB(k->fd, c.width, c.height, 24, 32, c.pitch, c.handle, &k->buf[i].fb)) return -1;
	struct drm_mode_map_dumb m = { .handle = c.handle };
	if (drmIoctl(k->fd, DRM_IOCTL_MODE_MAP_DUMB, &m)) return -1;
	void *p = mmap(NULL, c.size, PROT_READ | PROT_WRITE, MAP_SHARED, k->fd, (off_t)m.offset);
	if (p == MAP_FAILED) return -1;
	ws_surface *s = calloc(1, sizeof *s);
	if (!s) return -1;
	s->w = (int)c.width; s->h = (int)c.height; s->stride = c.pitch; s->px = p; s->map = p; s->maplen = c.size;
	k->buf[i].s = s;
	return 0;
}

ws_kms *ws_kms_open(const char *card, int *w, int *h)
{
	ws_kms *k = calloc(1, sizeof *k);
	if (!k) return NULL;
	k->fd = open(card, O_RDWR | O_CLOEXEC);
	if (k->fd < 0) { free(k); return NULL; }
	drmModeRes *res = drmModeGetResources(k->fd);
	if (!res) goto fail;
	drmModeConnector *conn = NULL;
	for (int i = 0; i < res->count_connectors && !conn; i++) {
		drmModeConnector *c = drmModeGetConnector(k->fd, res->connectors[i]);
		if (c && c->connection == DRM_MODE_CONNECTED && c->count_modes > 0) conn = c; else if (c) drmModeFreeConnector(c);
	}
	if (!conn) { drmModeFreeResources(res); goto fail; }
	k->conn = conn->connector_id;
	k->mode = conn->modes[0];                                   /* the first mode is the preferred one */
	drmModeEncoder *enc = conn->encoder_id ? drmModeGetEncoder(k->fd, conn->encoder_id) : NULL;
	k->crtc = enc ? enc->crtc_id : (uint32_t)res->crtcs[0];
	if (enc) drmModeFreeEncoder(enc);
	drmModeFreeConnector(conn);
	drmModeFreeResources(res);
	k->saved = drmModeGetCrtc(k->fd, k->crtc);
	if (make_buf(k, 0) || make_buf(k, 1)) goto fail;
	if (drmModeSetCrtc(k->fd, k->crtc, k->buf[0].fb, 0, 0, &k->conn, 1, &k->mode)) goto fail;
	k->front = 0;
	*w = k->mode.hdisplay; *h = k->mode.vdisplay;
	return k;
fail:
	if (k->fd >= 0) close(k->fd);
	free(k);
	return NULL;
}

int ws_kms_fd(ws_kms *k) { return k->fd; }
ws_surface *ws_kms_back(ws_kms *k) { return k->buf[1 - k->front].s; }

int ws_kms_present_ready(ws_kms *k) { return !k->flip_pending; }

int ws_kms_present(ws_kms *k)
{
	if (k->flip_pending) return 1;                              /* previous flip not finished: the caller keeps the frame pending */
	if (drmModePageFlip(k->fd, k->crtc, k->buf[1 - k->front].fb, DRM_MODE_PAGE_FLIP_EVENT, k)) return -1;
	k->flip_pending = 1;
	return 0;
}

/* ---- hardware cursor (legacy cursor ioctls; an atomic cursor plane is the next step) ---- */
int ws_kms_cursor_supported(ws_kms *k)
{
	uint64_t w = 0, h = 0;
	if (k->cur.handle) return 1;
	if (drmGetCap(k->fd, DRM_CAP_CURSOR_WIDTH, &w) || drmGetCap(k->fd, DRM_CAP_CURSOR_HEIGHT, &h) || !w || !h) { w = 64; h = 64; }   /* the usual size */
	struct drm_mode_create_dumb c = { .width = (uint32_t)w, .height = (uint32_t)h, .bpp = 32 };
	if (drmIoctl(k->fd, DRM_IOCTL_MODE_CREATE_DUMB, &c)) return 0;
	struct drm_mode_map_dumb m = { .handle = c.handle };
	void *p = MAP_FAILED;
	if (!drmIoctl(k->fd, DRM_IOCTL_MODE_MAP_DUMB, &m)) p = mmap(NULL, c.size, PROT_READ | PROT_WRITE, MAP_SHARED, k->fd, (off_t)m.offset);
	if (p == MAP_FAILED) { struct drm_mode_destroy_dumb d = { .handle = c.handle }; drmIoctl(k->fd, DRM_IOCTL_MODE_DESTROY_DUMB, &d); return 0; }
	k->cur.handle = c.handle; k->cur.map = p; k->cur.size = c.size; k->cur.w = c.width; k->cur.h = c.height;
	return 1;
}

int ws_kms_cursor_set(ws_kms *k, const ws_surface *img, int hot_x, int hot_y)
{
	if (!ws_kms_cursor_supported(k)) return -1;
	if (!img) { k->cur.on = 0; return drmModeSetCursor(k->fd, k->crtc, 0, 0, 0); }        /* hidden: the plane shows nothing */
	if (!img->px || (uint32_t)img->w > k->cur.w || (uint32_t)img->h > k->cur.h) return -1;
	memset(k->cur.map, 0, k->cur.size);
	for (int y = 0; y < img->h; y++) memcpy(k->cur.map + (size_t)y * k->cur.w * 4, img->px + (size_t)y * img->stride, (size_t)img->w * 4);
	if (drmModeSetCursor2(k->fd, k->crtc, k->cur.handle, k->cur.w, k->cur.h, hot_x, hot_y) &&
	    drmModeSetCursor(k->fd, k->crtc, k->cur.handle, k->cur.w, k->cur.h)) return -1;
	k->cur.on = 1;
	return 0;
}

int ws_kms_cursor_move(ws_kms *k, int x, int y) { return k->cur.on ? drmModeMoveCursor(k->fd, k->crtc, x, y) : -1; }

static void on_flip(int fd, unsigned seq, unsigned sec, unsigned usec, void *data)
{
	(void)fd; (void)seq; (void)sec; (void)usec;
	ws_kms *k = data;
	k->front = 1 - k->front; k->flip_pending = 0;
}

/* the VT went to another console: give up DRM master (the new owner needs it); coming back, take it again and show the front buffer */
void ws_kms_pause(ws_kms *k) { drmDropMaster(k->fd); k->flip_pending = 0; }
int ws_kms_resume(ws_kms *k)
{
	if (drmSetMaster(k->fd)) return -1;
	k->flip_pending = 0;
	if (drmModeSetCrtc(k->fd, k->crtc, k->buf[k->front].fb, 0, 0, &k->conn, 1, &k->mode)) return -1;
	if (k->cur.on) drmModeSetCursor2(k->fd, k->crtc, k->cur.handle, k->cur.w, k->cur.h, 0, 0);
	return 0;
}

int ws_kms_handle_events(ws_kms *k)
{
	drmEventContext ctx = { .version = 2, .page_flip_handler = on_flip };
	return drmHandleEvent(k->fd, &ctx);
}

void ws_kms_close(ws_kms *k)
{
	if (!k) return;
	if (k->saved) { drmModeSetCrtc(k->fd, k->saved->crtc_id, k->saved->buffer_id, k->saved->x, k->saved->y, &k->conn, 1, &k->saved->mode); drmModeFreeCrtc(k->saved); }
	if (k->cur.on) drmModeSetCursor(k->fd, k->crtc, 0, 0, 0);
	if (k->cur.map) { munmap(k->cur.map, k->cur.size); struct drm_mode_destroy_dumb d = { .handle = k->cur.handle }; drmIoctl(k->fd, DRM_IOCTL_MODE_DESTROY_DUMB, &d); }
	for (int i = 0; i < 2; i++) if (k->buf[i].s) { drmModeRmFB(k->fd, k->buf[i].fb); ws_surface_free(k->buf[i].s); }
	close(k->fd);
	free(k);
}

/* ---- evdev ---- */
#define MAXDEV 16
struct ws_evdev { int n, fd[MAXDEV]; ws_input in; int in_init; int abs[MAXDEV][2][2]; int has_abs[MAXDEV]; };

ws_evdev *ws_evdev_open(const char *dir)
{
	ws_evdev *e = calloc(1, sizeof *e);
	DIR *d = e ? opendir(dir) : NULL;
	if (!d) { free(e); return NULL; }
	struct dirent *de;
	while ((de = readdir(d)) && e->n < MAXDEV) {
		if (strncmp(de->d_name, "event", 5)) continue;
		char path[512];
		snprintf(path, sizeof path, "%s/%s", dir, de->d_name);
		int fd = open(path, O_RDONLY | O_NONBLOCK | O_CLOEXEC);
		if (fd >= 0) {
			struct input_absinfo ax, ay;                          /* a device with absolute axes (tablet, touch screen) reports positions in its own range */
			if (ioctl(fd, EVIOCGABS(ABS_X), &ax) == 0 && ioctl(fd, EVIOCGABS(ABS_Y), &ay) == 0 && ax.maximum > ax.minimum && ay.maximum > ay.minimum) {
				e->has_abs[e->n] = 1; e->abs[e->n][0][0] = ax.minimum; e->abs[e->n][0][1] = ax.maximum; e->abs[e->n][1][0] = ay.minimum; e->abs[e->n][1][1] = ay.maximum;
			}
			e->fd[e->n++] = fd;
		}
	}
	closedir(d);
	return e;
}

int ws_evdev_count(ws_evdev *e) { return e->n; }
int ws_evdev_fd(ws_evdev *e, int i) { return e->fd[i]; }

/* reads and drops everything pending on an input device (used while another VT is active) */
int ws_evdev_drain(ws_evdev *e, int i)
{
	struct input_event ev[64];
	for (;;) { ssize_t n = read(e->fd[i], ev, sizeof ev); if (n < 0) return errno == EAGAIN ? 0 : -1; if (n == 0) return -1; }
}


int ws_evdev_dispatch(ws_evdev *e, int i, ws_server *srv, int sw, int sh)
{
	struct input_event ev[64];
	if (!e->in_init) { ws_input_init(&e->in, sw, sh); e->in_init = 1; }
	for (;;) {
		ssize_t n = read(e->fd[i], ev, sizeof ev);
		if (n < 0) return errno == EAGAIN ? 0 : -1;
		if (n == 0) return -1;
		for (size_t j = 0; j < (size_t)n / sizeof ev[0]; j++) {
			if (ev[j].type == EV_ABS && e->has_abs[i]) { ws_input_set_abs_range(&e->in, 0, e->abs[i][0][0], e->abs[i][0][1]); ws_input_set_abs_range(&e->in, 1, e->abs[i][1][0], e->abs[i][1][1]); }
			ws_input_feed(&e->in, srv, ev[j].type, ev[j].code, ev[j].value);       /* EV_SYN / EV_KEY / EV_REL / EV_ABS share the numbers of ws_input.h */
		}
	}
}

void ws_evdev_close(ws_evdev *e)
{
	if (!e) return;
	for (int i = 0; i < e->n; i++) close(e->fd[i]);
	free(e);
}
#endif
