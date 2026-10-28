/* test_fxcache: the glass and blur results are cached per backdrop: the same result as without the cache, found again when the backdrop is the same, recomputed when one pixel of it changed */
#include <stdio.h>
#include <string.h>
#include <time.h>
#include "ws.h"

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)
static double now_ms(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec * 1e3 + t.tv_nsec / 1e6; }
static void patch(ws_surface *s) { for (int y = 380; y < 420; y++) for (int x = 1080; x < 1120; x++) s->px[(size_t)y * s->stride + (size_t)x * 4] ^= 0x55; }
static void fill(ws_surface *s, int seed) { for (int y = 0; y < s->h; y++) for (int x = 0; x < s->w; x++) { uint8_t *p = s->px + (size_t)y * s->stride + (size_t)x * 4; p[0] = (uint8_t)(x * 7 + seed); p[1] = (uint8_t)(y * 5); p[2] = (uint8_t)((x ^ y) * 3); p[3] = 255; } }

int main(void)
{
	ws_surface *a = ws_surface_new(1280, 800), *b = ws_surface_new(1280, 800), *c = ws_surface_new(1280, 800);
	ws_glass g = { { 40, 30, 360, 660 }, 18, 4 };
	fill(a, 0); fill(b, 0); fill(c, 0);
	double t0 = now_ms(); ws_glass_regions(a, &g, 1, 900, 40); double first = now_ms() - t0;             /* computed */
	fill(b, 0); t0 = now_ms(); ws_glass_regions(b, &g, 1, 900, 40); double second = now_ms() - t0;      /* from the cache */
	CHECK(!memcmp(a->px, b->px, (size_t)a->stride * a->h));
	printf("glass: first %.2f ms, cached %.2f ms\n", first, second);
	CHECK(second < first / 3);
	fill(c, 0); patch(c);                                        /* a patch of the backdrop inside the region differs */
	ws_glass_regions(c, &g, 1, 900, 40);
	fill(a, 0); patch(a); ws_glass_regions(a, &g, 1, 900, 40);   /* the cache now holds the c result: the same input gives the same output */
	CHECK(!memcmp(a->px, c->px, (size_t)a->stride * a->h));
	fill(b, 0); ws_glass_regions(b, &g, 1, 900, 40);
	CHECK(memcmp(b->px, c->px, (size_t)b->stride * b->h) != 0);
	fill(a, 0); fill(b, 0);
	t0 = now_ms(); ws_blur_region(a, (ws_rect){ 100, 100, 400, 300 }, (ws_rect){ 130, 130, 340, 240 }, 15.0f); first = now_ms() - t0;
	t0 = now_ms(); ws_blur_region(b, (ws_rect){ 100, 100, 400, 300 }, (ws_rect){ 130, 130, 340, 240 }, 15.0f); second = now_ms() - t0;
	CHECK(!memcmp(a->px, b->px, (size_t)a->stride * a->h)); printf("blur: first %.2f ms, cached %.2f ms\n", first, second); CHECK(second < first / 3);
	if (failures) { printf("%d failure(s)\n", failures); return 1; } printf("test_fxcache: ok\n"); return 0;
}
