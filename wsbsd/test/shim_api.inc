/* The same client program runs against the real SkyLight (macOS, lab/shim_basic.c) and against wsbsd's shim (test/test_shim.c); the printed lines must be identical. */
#include <stdio.h>
#include <string.h>

typedef struct { double x, y, w, h; } R_;
typedef struct { double x, y; } P_;
typedef struct {
	int (*main_conn)(void);
	int (*new_rect)(const R_ *, void **);
	int (*new_win)(int, int, float, float, void *, uint32_t *);
	int (*rel_win)(int, uint32_t);
	int (*order)(int, uint32_t, int, uint32_t);
	int (*move)(int, uint32_t, const P_ *);
	int (*set_level)(int, uint32_t, int);
	int (*get_level)(int, uint32_t, int *);
	int (*set_alpha)(int, uint32_t, float);
	int (*get_alpha)(int, uint32_t, float *);
	int (*get_bounds)(int, uint32_t, R_ *);
	int (*get_owner)(int, uint32_t, int *);
} api_t;

static int run_api(const api_t *a)
{
	int cid = a->main_conn();
	printf("connection id positive: %d\n", cid > 0);
	R_ shape = { 0, 0, 300, 150 }; void *rg = 0;
	printf("new region: %d\n", a->new_rect(&shape, &rg));
	uint32_t w = 0;
	printf("new window: %d wid nonzero %d\n", a->new_win(cid, 2, 100.0f, 200.0f, rg, &w), w != 0);
	R_ b = { -1, -1, -1, -1 };
	printf("bounds: %d %g %g %g %g\n", a->get_bounds(cid, w, &b), b.x, b.y, b.w, b.h);
	int lv = -99; float al = -9;
	printf("level: %d %d\n", a->get_level(cid, w, &lv), lv);
	printf("alpha: %d %g\n", a->get_alpha(cid, w, &al), al);
	printf("set level 5: %d\n", a->set_level(cid, w, 5));
	printf("level: %d %d\n", a->get_level(cid, w, &lv), lv);
	printf("set alpha 0.5: %d\n", a->set_alpha(cid, w, 0.5f));
	printf("alpha: %d %g\n", a->get_alpha(cid, w, &al), al);
	P_ o = { 400, 500 };
	printf("move: %d\n", a->move(cid, w, &o));
	printf("bounds: %d %g %g %g %g\n", a->get_bounds(cid, w, &b), b.x, b.y, b.w, b.h);
	int own = -1;
	printf("owner is us: %d %d\n", a->get_owner(cid, w, &own), own == cid);
	printf("order above: %d\n", a->order(cid, w, 1, 0));
	printf("order out: %d\n", a->order(cid, w, 0, 0));
	printf("release: %d\n", a->rel_win(cid, w));
	printf("bounds after release: %d\n", a->get_bounds(cid, w, &b));
	printf("release again: %d\n", a->rel_win(cid, w));
	return 0;
}
