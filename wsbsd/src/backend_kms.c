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
#include <poll.h>
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
	struct { uint32_t handle, fb; size_t size; ws_surface *s; } buf[2];
	int front, flip_pending;
	drmModeCrtc *saved;
	struct { uint32_t handle; uint8_t *map; size_t size; uint32_t w, h; int on; } cur;   /* hardware cursor buffer */
};

/* the mode to use: the one the connector marks as preferred; the first in the list is not always it (FreeBSD's EDID mode order), then the largest */
static int pick_mode(const drmModeConnector *c)
{
	int best = 0;
	for (int i = 0; i < c->count_modes; i++) if (c->modes[i].type & DRM_MODE_TYPE_PREFERRED) return i;
	for (int i = 1; i < c->count_modes; i++)
		if ((long)c->modes[i].hdisplay * c->modes[i].vdisplay > (long)c->modes[best].hdisplay * c->modes[best].vdisplay) best = i;
	return best;
}

static int make_buf(ws_kms *k, int i)
{
	k->buf[i].s = NULL;
	struct drm_mode_create_dumb c = { .width = k->mode.hdisplay, .height = k->mode.vdisplay, .bpp = 32 };
	if (drmIoctl(k->fd, DRM_IOCTL_MODE_CREATE_DUMB, &c)) return -1;
	k->buf[i].handle = c.handle; k->buf[i].size = c.size;
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
	k->mode = conn->modes[pick_mode(conn)];
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
int ws_kms_present(ws_kms *k);
int ws_kms_present_rect(ws_kms *k, int x, int y, int w, int h) { (void)x; (void)y; (void)w; (void)h; return ws_kms_present(k); }

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

/* ---- display hotplug / resize: the preferred mode of the connector changed (a virtual display resized by the host, a monitor swapped) ---- */
int ws_kms_poll_mode(ws_kms *k, int *w, int *h)
{
	drmModeConnector *c = drmModeGetConnector(k->fd, k->conn);
	int changed = 0;
	if (!c) return 0;
	if (c->connection == DRM_MODE_CONNECTED && c->count_modes > 0 && (c->modes[pick_mode(c)].hdisplay != k->mode.hdisplay || c->modes[pick_mode(c)].vdisplay != k->mode.vdisplay)) {
		*w = c->modes[pick_mode(c)].hdisplay; *h = c->modes[pick_mode(c)].vdisplay; changed = 1;
	}
	drmModeFreeConnector(c);
	return changed;
}

static void free_buf(ws_kms *k, int i)
{
	if (!k->buf[i].s) return;
	drmModeRmFB(k->fd, k->buf[i].fb);
	ws_surface_free(k->buf[i].s);                               /* unmaps the dumb buffer */
	struct drm_mode_destroy_dumb d = { .handle = k->buf[i].handle };
	drmIoctl(k->fd, DRM_IOCTL_MODE_DESTROY_DUMB, &d);
	k->buf[i].s = NULL;
}

/* Switches to the connector's preferred mode: new dumb buffers, a new mode set, the old ones released. 0 on success (w, h: the new size), -1 on failure (the old mode stays). */
int ws_kms_set_mode(ws_kms *k, int *w, int *h)
{
	drmModeConnector *c = drmModeGetConnector(k->fd, k->conn);
	if (!c || c->connection != DRM_MODE_CONNECTED || c->count_modes <= 0) { if (c) drmModeFreeConnector(c); return -1; }
	while (k->flip_pending) { struct pollfd p = { .fd = k->fd, .events = POLLIN }; if (poll(&p, 1, 200) <= 0) break; ws_kms_handle_events(k); }
	k->flip_pending = 0;
	drmModeModeInfo old_mode = k->mode, nm = c->modes[pick_mode(c)];
	drmModeFreeConnector(c);
	struct { uint32_t handle, fb; size_t size; ws_surface *s; } old[2] = { { k->buf[0].handle, k->buf[0].fb, k->buf[0].size, k->buf[0].s }, { k->buf[1].handle, k->buf[1].fb, k->buf[1].size, k->buf[1].s } };
	k->mode = nm;
	if (make_buf(k, 0) || make_buf(k, 1) || drmModeSetCrtc(k->fd, k->crtc, k->buf[0].fb, 0, 0, &k->conn, 1, &k->mode)) {
		free_buf(k, 0); free_buf(k, 1);                         /* whatever was made of the new ones */
		k->mode = old_mode;
		for (int i = 0; i < 2; i++) { k->buf[i].handle = old[i].handle; k->buf[i].fb = old[i].fb; k->buf[i].size = old[i].size; k->buf[i].s = old[i].s; }
		return -1;
	}
	for (int i = 0; i < 2; i++) {                               /* release the old buffers (the mode set no longer scans them out) */
		drmModeRmFB(k->fd, old[i].fb); ws_surface_free(old[i].s);
		struct drm_mode_destroy_dumb d = { .handle = old[i].handle }; drmIoctl(k->fd, DRM_IOCTL_MODE_DESTROY_DUMB, &d);
	}
	k->front = 0;
	if (k->cur.on) drmModeSetCursor2(k->fd, k->crtc, k->cur.handle, k->cur.w, k->cur.h, 0, 0);
	*w = k->mode.hdisplay; *h = k->mode.vdisplay;
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

#endif
