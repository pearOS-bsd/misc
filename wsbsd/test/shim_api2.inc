/* second shared program: counts, sublevels, ordered-in state, event mask, blur radius */
#include <stdio.h>
#include <string.h>
typedef struct { double x, y, w, h; } R2_;
typedef struct {
	int (*main_conn)(void);
	int (*new_rect)(const R2_ *, void **);
	int (*new_win)(int, int, float, float, void *, uint32_t *);
	int (*rel_win)(int, uint32_t);
	int (*order)(int, uint32_t, int, uint32_t);
	int (*is_ordered_in)(int, uint32_t, unsigned char *);
	int (*win_count)(int, int, int *);
	int (*onscreen_count)(int, int, int *);
	int (*set_sub)(int, uint32_t, int);
	int (*get_sub)(int, uint32_t, int *);
	int (*set_mask)(int, uint32_t, unsigned);
	int (*get_mask)(int, uint32_t, unsigned *);
	int (*set_blur)(int, uint32_t, int);
} api2_t;

static int run_api2(const api2_t *a)
{
	int cid = a->main_conn();
	R2_ shape = { 0, 0, 120, 80 }; void *rg = 0; a->new_rect(&shape, &rg);
	uint32_t w1 = 0, w2 = 0;
	a->new_win(cid, 2, 10.0f, 20.0f, rg, &w1); a->new_win(cid, 2, 30.0f, 40.0f, rg, &w2);
	int n = -1;
	printf("window count: %d %d\n", a->win_count(cid, cid, &n), n);
	printf("on screen count: %d %d\n", a->onscreen_count(cid, cid, &n), n);
	unsigned char io = 7;
	printf("ordered in: %d %d\n", a->is_ordered_in(cid, w1, &io), io);
	a->order(cid, w1, 1, 0);
	printf("ordered in after order: %d %d\n", a->is_ordered_in(cid, w1, &io), io);
	printf("on screen count: %d %d\n", a->onscreen_count(cid, cid, &n), n);
	a->order(cid, w2, 1, 0);
	printf("on screen count: %d %d\n", a->onscreen_count(cid, cid, &n), n);
	int sl = -9;
	printf("sublevel: %d %d\n", a->get_sub(cid, w1, &sl), sl);
	printf("set sublevel 3: %d\n", a->set_sub(cid, w1, 3));
	printf("sublevel: %d %d\n", a->get_sub(cid, w1, &sl), sl);
	unsigned m = 0xdead;
	printf("event mask: %d %#x\n", a->get_mask(cid, w1, &m), m);
	printf("set event mask: %d\n", a->set_mask(cid, w1, 0x12));
	printf("event mask: %d %#x\n", a->get_mask(cid, w1, &m), m);
	printf("set blur 12: %d\n", a->set_blur(cid, w1, 12));
	printf("set blur on a bad window: %d\n", a->set_blur(cid, 999999, 12));
	printf("ordered in, bad window: %d %d\n", a->is_ordered_in(cid, 999999, &io), io);
	a->rel_win(cid, w1);
	printf("window count: %d %d\n", a->win_count(cid, cid, &n), n);
	a->rel_win(cid, w2);
	printf("window count: %d %d\n", a->win_count(cid, cid, &n), n);
	return 0;
}
