/* FreeBSD display through the vt(4) framebuffer, the way the machine's console already draws (EFI GOP on arm64 and amd64 UEFI, simplefb, vesa): no DRM driver needed, so it works in a
 * QEMU window (ramfb / virtio-gpu GOP) and on a UEFI machine without a KMS driver. It offers the interface of the KMS backend (ws_backend.h) so that wsd drives it the same way:
 *   - ioctl FBIOGTYPE / FBIO_GETLINEWIDTH on the console device give the geometry, mmap of the same device maps the framebuffer (vt_fb);
 *   - the compositor draws into an ordinary surface and a present copies it to the framebuffer (premultiplied BGRA, the order of the EFI GOP BGR format and of simplefb a8r8g8b8);
 *   - no hardware cursor plane: the cursor is composed in software, a present is made when it moves. */
#if defined(WS_KMS) && defined(WS_FB)
#include "ws_backend.h"
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#ifdef __FreeBSD__
#include <sys/fbio.h>
#endif

struct ws_kms {
	int fd, pipe_r, pipe_w;
	uint8_t *map; size_t map_size; int stride;      /* the framebuffer and its row length in bytes */
	int w, h;
	ws_surface *back;
	uint32_t *last;                                 /* what the framebuffer holds now: only the pixels that changed are written (writing the whole screen for every frame shows as flicker where the display reads the memory while it is written) */
};

ws_kms *ws_kms_open(const char *dev, int *w, int *h)
{
#ifdef __FreeBSD__
	ws_kms *k = calloc(1, sizeof *k);
	if (!k) return NULL;
	if (!dev || !strncmp(dev, "/dev/dri", 8)) dev = "/dev/ttyv0";         /* the default card name belongs to the DRM backend */
	k->fd = open(dev, O_RDWR | O_CLOEXEC);
	if (k->fd < 0) { perror("wsd: framebuffer open"); free(k); return NULL; }
	struct fbtype ft; int line = 0;
	if (ioctl(k->fd, FBIOGTYPE, &ft) < 0 || ft.fb_width <= 0 || ft.fb_height <= 0) { perror("wsd: FBIOGTYPE"); close(k->fd); free(k); return NULL; }
	if (ioctl(k->fd, FBIO_GETLINEWIDTH, &line) < 0 || line <= 0) line = ft.fb_width * (ft.fb_depth / 8);
	if (ft.fb_depth != 32 && ft.fb_depth != 24) { fprintf(stderr, "wsd: framebuffer depth %d is not supported (32 bits per pixel only)\n", ft.fb_depth); close(k->fd); free(k); return NULL; }
	k->w = ft.fb_width; k->h = ft.fb_height; k->stride = line; k->map_size = (size_t)line * (size_t)ft.fb_height;
	k->map = mmap(NULL, k->map_size, PROT_READ | PROT_WRITE, MAP_SHARED, k->fd, 0);
	if (k->map == MAP_FAILED) { perror("wsd: framebuffer mmap"); close(k->fd); free(k); return NULL; }
	k->back = ws_surface_new(k->w, k->h);
	int p[2];
	if (!k->back || pipe(p) < 0) { munmap(k->map, k->map_size); close(k->fd); free(k); return NULL; }
	k->pipe_r = p[0]; k->pipe_w = p[1];
	if (w) *w = k->w;
	if (h) *h = k->h;
	fprintf(stderr, "wsd: framebuffer %s %dx%d, %d bits, %d bytes per row\n", dev, k->w, k->h, ft.fb_depth, line);
	return k;
#else
	(void)dev; (void)w; (void)h;
	return NULL;
#endif
}

int ws_kms_fd(ws_kms *k) { return k->pipe_r; }                                  /* nothing to wait for: a pipe that is never written */
ws_surface *ws_kms_back(ws_kms *k) { return k->back; }
int ws_kms_present_ready(ws_kms *k) { (void)k; return 1; }

int ws_kms_present(ws_kms *k)
{
	if (!k->last) { k->last = calloc((size_t)k->w * (size_t)k->h, 4); if (!k->last) { size_t row = (size_t)k->w * 4; for (int y = 0; y < k->h; y++) memcpy(k->map + (size_t)y * (size_t)k->stride, k->back->px + (size_t)y * k->back->stride, row); return 0; } memset(k->last, 0xA5, (size_t)k->w * (size_t)k->h * 4); }
	for (int y = 0; y < k->h; y++) {
		const uint32_t *src = (const uint32_t *)(k->back->px + (size_t)y * k->back->stride); uint32_t *old = k->last + (size_t)y * k->w; uint32_t *dst = (uint32_t *)(k->map + (size_t)y * (size_t)k->stride);
		int x = 0; while (x < k->w) { while (x < k->w && src[x] == old[x]) x++; if (x >= k->w) break; int a = x; while (x < k->w && (src[x] != old[x] || (x + 1 < k->w && src[x + 1] != old[x + 1]))) x++; memcpy(dst + a, src + a, (size_t)(x - a) * 4); memcpy(old + a, src + a, (size_t)(x - a) * 4); }
	}
	return 0;
}

int ws_kms_cursor_supported(ws_kms *k) { (void)k; return 0; }
int ws_kms_cursor_set(ws_kms *k, const ws_surface *img, int hot_x, int hot_y) { (void)k; (void)img; (void)hot_x; (void)hot_y; return -1; }
int ws_kms_cursor_move(ws_kms *k, int x, int y) { (void)k; (void)x; (void)y; return -1; }
void ws_kms_pause(ws_kms *k) { (void)k; }
int ws_kms_resume(ws_kms *k) { (void)k; return 0; }
int ws_kms_handle_events(ws_kms *k) { char b[16]; return (int)read(k->pipe_r, b, sizeof b); }

void ws_kms_close(ws_kms *k)
{
	if (!k) return;
	memset(k->map, 0, k->map_size);                                        /* the console draws over what the window server leaves: black, not the last frame */
	munmap(k->map, k->map_size);
	ws_surface_free(k->back);
	close(k->pipe_r); close(k->pipe_w); close(k->fd);
	free(k);
}
#endif
