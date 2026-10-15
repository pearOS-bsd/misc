#include "ws.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>

ws_surface *ws_surface_new(int w, int h)
{
	ws_surface *s = calloc(1, sizeof *s);
	if (!s || w <= 0 || h <= 0) { free(s); return NULL; }
	s->w = w; s->h = h; s->stride = (size_t)w * 4;
	s->px = calloc((size_t)h, s->stride);
	if (!s->px) { free(s); return NULL; }
	return s;
}

ws_surface *ws_surface_shm(const char *name, int w, int h, int create)
{
	if (w <= 0 || h <= 0) return NULL;
	size_t len = (size_t)w * 4 * (size_t)h;
	int fd = shm_open(name, create ? (O_RDWR | O_CREAT | O_EXCL) : O_RDWR, 0600);
	if (fd < 0) return NULL;
	if (create && ftruncate(fd, (off_t)len) < 0) { close(fd); shm_unlink(name); return NULL; }
	void *m = mmap(NULL, len, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
	close(fd);
	if (m == MAP_FAILED) { if (create) shm_unlink(name); return NULL; }
	ws_surface *s = calloc(1, sizeof *s);
	if (!s) { munmap(m, len); return NULL; }
	s->w = w; s->h = h; s->stride = (size_t)w * 4; s->px = m; s->map = m; s->maplen = len;
	return s;
}

void ws_shm_unlink(const char *name) { shm_unlink(name); }

ws_surface *ws_surface_shm_anon(int w, int h, int *fd_out)
{
	static unsigned counter;
	char name[32];
	if (w <= 0 || h <= 0) return NULL;
	size_t len = (size_t)w * 4 * (size_t)h;
	snprintf(name, sizeof name, "/wsa.%d.%u", (int)getpid(), ++counter);
	int fd = shm_open(name, O_RDWR | O_CREAT | O_EXCL, 0600);
	if (fd < 0) return NULL;
	shm_unlink(name);                                       /* the descriptor is the only handle from now on */
	if (ftruncate(fd, (off_t)len) < 0) { close(fd); return NULL; }
	void *m = mmap(NULL, len, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
	ws_surface *s = m == MAP_FAILED ? NULL : calloc(1, sizeof *s);
	if (!s) { if (m != MAP_FAILED) munmap(m, len); close(fd); return NULL; }
	s->w = w; s->h = h; s->stride = (size_t)w * 4; s->px = m; s->map = m; s->maplen = len;
	*fd_out = fd;
	return s;
}

ws_surface *ws_surface_from_fd(int fd, int w, int h)
{
	if (w <= 0 || h <= 0) return NULL;
	size_t len = (size_t)w * 4 * (size_t)h;
	void *m = mmap(NULL, len, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
	if (m == MAP_FAILED) return NULL;
	ws_surface *s = calloc(1, sizeof *s);
	if (!s) { munmap(m, len); return NULL; }
	s->w = w; s->h = h; s->stride = (size_t)w * 4; s->px = m; s->map = m; s->maplen = len;
	return s;
}

void ws_surface_free(ws_surface *s)
{
	if (!s) return;
	if (s->map) munmap(s->map, s->maplen); else free(s->px);
	free(s);
}

static ws_rect clip_to(ws_rect r, int w, int h)
{
	int x0 = r.x < 0 ? 0 : r.x, y0 = r.y < 0 ? 0 : r.y;
	int x1 = r.x + r.w > w ? w : r.x + r.w, y1 = r.y + r.h > h ? h : r.y + r.h;
	ws_rect o = { x0, y0, x1 > x0 ? x1 - x0 : 0, y1 > y0 ? y1 - y0 : 0 };
	return o;
}

static uint8_t q8(float v)
{
	if (v <= 0) return 0;
	if (v >= 1) return 255;
	return (uint8_t)(v * 255.0f + 0.5f);
}

/* Fill with a straight-alpha colour; stored premultiplied. */
static void sw_fill(ws_compositor *c, ws_surface *s, ws_rect r, float red, float green, float blue, float alpha)
{
	(void)c;
	if (!s) return;
	r = clip_to(r, s->w, s->h);
	uint8_t a = q8(alpha);
	uint32_t px = (uint32_t)q8(blue * alpha) | (uint32_t)q8(green * alpha) << 8 |
	              (uint32_t)q8(red * alpha) << 16 | (uint32_t)a << 24;
	for (int y = r.y; y < r.y + r.h; y++) {
		uint32_t *row = (uint32_t *)(s->px + (size_t)y * s->stride);
		for (int x = r.x; x < r.x + r.w; x++) row[x] = px;
	}
}

/* Arithmetic as observed in SkyLight's _layer_blit_byte_ARGB8_RGB8 (decompiled): source is premultiplied,
 * the destination term is dst*(255-src_alpha) divided by 255 with the exact-floor idiom (t+1+(t>>8))>>8,
 * and the two are combined with a saturating add. Layer opacity is quantised to 8.8 fixed point
 * (o = floor(op*256 + 0.5)) and applied to all four source channels as (x*o)>>8.
 * Inferred, not read from code: that the multiplier is (255 - src_alpha). */
#define DIV255(t) (((t) + 1 + ((t) >> 8)) >> 8)

static void sw_over(ws_compositor *c, ws_surface *dst, int dx, int dy, const ws_surface *src, float opacity, ws_rect clip)
{
	(void)c;
	if (!dst || !src || !src->px) return;                       /* GPU-only buffers have no CPU pixels */
	int o = (int)(opacity * 256.0f + 0.5f);
	if (o <= 0) return;
	if (o > 256) o = 256;
	ws_rect area = { dx, dy, src->w, src->h };
	ws_rect cl = clip_to(clip, dst->w, dst->h);
	int x0 = area.x > cl.x ? area.x : cl.x, y0 = area.y > cl.y ? area.y : cl.y;
	int x1 = area.x + area.w < cl.x + cl.w ? area.x + area.w : cl.x + cl.w;
	int y1 = area.y + area.h < cl.y + cl.h ? area.y + area.h : cl.y + cl.h;
	for (int y = y0; y < y1; y++) {
		const uint8_t *sp = src->px + (size_t)(y - dy) * src->stride + (size_t)(x0 - dx) * 4;
		uint8_t *dp = dst->px + (size_t)y * dst->stride + (size_t)x0 * 4;
		if (o == 256) {                                           /* full opacity: opaque pixels are copied whole, transparent ones skipped, only the translucent ones are blended */
			for (int x = x0; x < x1; x++, sp += 4, dp += 4) {
				uint8_t a = sp[3];
				if (a == 255) { memcpy(dp, sp, 4); continue; }
				if (a == 0) continue;
				uint32_t inv = 255 - a;
				for (int k = 0; k < 4; k++) { uint32_t t = (uint32_t)dp[k] * inv, v = sp[k] + DIV255(t); dp[k] = (uint8_t)(v > 255 ? 255 : v); }
			}
			continue;
		}
		for (int x = x0; x < x1; x++, sp += 4, dp += 4) {
			uint32_t s4[4];
			for (int k = 0; k < 4; k++) s4[k] = o < 256 ? ((uint32_t)sp[k] * (uint32_t)o) >> 8 : sp[k];
			if (s4[3] == 0) continue;
			if (s4[3] == 255) { for (int k = 0; k < 4; k++) dp[k] = (uint8_t)s4[k]; continue; }
			uint32_t inv = 255 - s4[3];
			for (int k = 0; k < 4; k++) {
				uint32_t t = (uint32_t)dp[k] * inv, v = s4[k] + DIV255(t);
				dp[k] = (uint8_t)(v > 255 ? 255 : v);
			}
		}
	}
}

static void sw_flush(ws_compositor *c) { (void)c; }

ws_compositor ws_compositor_sw = { "sw", sw_fill, sw_over, sw_flush, NULL };

ws_compositor *ws_compositor_get(const char *name)
{
	if (name && strcmp(name, "sw") == 0) return &ws_compositor_sw;
	return NULL;   /* "gl" arrives with the KMS/EGL backend */
}

void ws_fill(ws_surface *s, ws_rect r, float red, float green, float blue, float alpha)
{
	sw_fill(&ws_compositor_sw, s, r, red, green, blue, alpha);
}

void ws_copy(ws_surface *dst, int dx, int dy, const ws_surface *src, ws_rect sr)
{
	if (!dst || !src) return;
	sr = clip_to(sr, src->w, src->h);
	for (int y = 0; y < sr.h; y++) {
		int ty = dy + y;
		if (ty < 0 || ty >= dst->h) continue;
		int sx = sr.x, tx = dx, n = sr.w;
		if (tx < 0) { sx -= tx; n += tx; tx = 0; }
		if (tx + n > dst->w) n = dst->w - tx;
		if (n <= 0) continue;
		memcpy(dst->px + (size_t)ty * dst->stride + (size_t)tx * 4,
		       src->px + (size_t)(sr.y + y) * src->stride + (size_t)sx * 4, (size_t)n * 4);
	}
}

void ws_over(ws_surface *dst, int dx, int dy, const ws_surface *src, float opacity, ws_rect clip)
{
	sw_over(&ws_compositor_sw, dst, dx, dy, src, opacity, clip);
}

int ws_write_ppm(const ws_surface *s, const char *path)
{
	FILE *f = fopen(path, "wb");
	if (!f) return -1;
	fprintf(f, "P6\n%d %d\n255\n", s->w, s->h);
	for (int y = 0; y < s->h; y++) {
		const uint8_t *p = s->px + (size_t)y * s->stride;
		for (int x = 0; x < s->w; x++, p += 4) { fputc(p[2], f); fputc(p[1], f); fputc(p[0], f); }
	}
	return fclose(f);
}
