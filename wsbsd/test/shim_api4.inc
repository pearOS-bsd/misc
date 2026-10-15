/* fourth shared program: window shape (resize), resolution, list operations */
#include <stdio.h>
#include <string.h>
typedef struct { double x, y, w, h; } R4_;
typedef struct { double x, y; } P4_;
typedef struct {
	int (*main_conn)(void);
	int (*new_rect)(const R4_ *, void **);
	int (*new_win)(int, int, float, float, void *, uint32_t *);
	int (*rel_win)(int, uint32_t);
	int (*order)(int, uint32_t, int, uint32_t);
	int (*get_bounds)(int, uint32_t, R4_ *);
	int (*set_shape)(int, uint32_t, float, float, void *);
	int (*get_res)(int, uint32_t, double *);
	int (*set_res)(int, uint32_t, double);
	int (*move_list)(int, const uint32_t *, int, P4_);
	int (*set_list_alpha)(int, const uint32_t *, int, float);
} api4_t;

static int run_api4(const api4_t *a)
{
	int cid = a->main_conn();
	R4_ s1 = { 0, 0, 100, 60 }, s2 = { 0, 0, 220, 140 }; void *r1 = 0, *r2 = 0; a->new_rect(&s1, &r1); a->new_rect(&s2, &r2);
	uint32_t w1 = 0, w2 = 0;
	a->new_win(cid, 2, 10.0f, 20.0f, r1, &w1); a->new_win(cid, 2, 50.0f, 60.0f, r1, &w2);
	R4_ b = { -1, -1, -1, -1 };
	printf("bounds: %d %g %g %g %g\n", a->get_bounds(cid, w1, &b), b.x, b.y, b.w, b.h);
	printf("set shape: %d\n", a->set_shape(cid, w1, 0.0f, 0.0f, r2));
	printf("bounds: %d %g %g %g %g\n", a->get_bounds(cid, w1, &b), b.x, b.y, b.w, b.h);
	double res = -1;
	printf("resolution: %d %g\n", a->get_res(cid, w1, &res), res);
	printf("set resolution 2: %d\n", a->set_res(cid, w1, 2.0));
	res = -1; printf("resolution: %d %g\n", a->get_res(cid, w1, &res), res);
	uint32_t list[2] = { w1, w2 };
	P4_ d = { 5, 7 };
	printf("move list: %d\n", a->move_list(cid, list, 2, d));
	printf("bounds w1: %d %g %g\n", a->get_bounds(cid, w1, &b), b.x, b.y);
	printf("bounds w2: %d %g %g\n", a->get_bounds(cid, w2, &b), b.x, b.y);
	printf("set list alpha: %d\n", a->set_list_alpha(cid, list, 2, 0.5f));
	a->rel_win(cid, w1); a->rel_win(cid, w2);
	return 0;
}
