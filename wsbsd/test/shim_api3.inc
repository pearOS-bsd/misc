/* third shared program: cursor visibility calls, window tags, the on-screen window list */
#include <stdio.h>
#include <string.h>
typedef struct { double x, y, w, h; } R3_;
typedef struct {
	int (*main_conn)(void);
	int (*new_rect)(const R3_ *, void **);
	int (*new_win)(int, int, float, float, void *, uint32_t *);
	int (*rel_win)(int, uint32_t);
	int (*order)(int, uint32_t, int, uint32_t);
	int (*hide)(int);
	int (*show)(int);
	int (*obscure)(int);
	int (*reveal)(int);
	int (*scale)(int, float *);
	int (*onscreen_list)(int, int, int, uint32_t *, int *);
} api3_t;

static int run_api3(const api3_t *a)
{
	int cid = a->main_conn();
	printf("hide: %d\n", a->hide(cid));
	printf("show: %d\n", a->show(cid));
	printf("obscure: %d\n", a->obscure(cid));
	printf("reveal: %d\n", a->reveal(cid));
	printf("hide, bad connection: %d\n", a->hide(999999));
	float sc = -1;
	printf("cursor scale: %d %g\n", a->scale(cid, &sc), sc);
	R3_ shape = { 0, 0, 100, 60 }; void *rg = 0; a->new_rect(&shape, &rg);
	uint32_t w1 = 0, w2 = 0, w3 = 0;
	a->new_win(cid, 2, 10.0f, 20.0f, rg, &w1); a->new_win(cid, 2, 30.0f, 40.0f, rg, &w2); a->new_win(cid, 2, 50.0f, 60.0f, rg, &w3);
	a->order(cid, w1, 1, 0); a->order(cid, w2, 1, 0); a->order(cid, w3, 1, 0);
	uint32_t list[16]; int n = -1;
	int rc = a->onscreen_list(cid, cid, 16, list, &n);
	printf("on screen list: %d count %d order:", rc, n);
	for (int i = 0; i < n; i++) printf(" %c", list[i] == w1 ? 'A' : list[i] == w2 ? 'B' : list[i] == w3 ? 'C' : '?');
	printf("\n");
	a->order(cid, w1, 1, 0);
	rc = a->onscreen_list(cid, cid, 16, list, &n);
	printf("on screen list: %d count %d order:", rc, n);
	for (int i = 0; i < n; i++) printf(" %c", list[i] == w1 ? 'A' : list[i] == w2 ? 'B' : list[i] == w3 ? 'C' : '?');
	printf("\n");
	a->rel_win(cid, w1); a->rel_win(cid, w2); a->rel_win(cid, w3);
	return 0;
}
