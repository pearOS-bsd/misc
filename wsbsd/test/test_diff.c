/* Differential tests: the expected results were produced by the real macOS 27.0 WindowServer for the same operation sequences
 * (SLSOrderWindow / SLSSetWindowLevel / SLSSetWindowSubLevel on four invisible windows, order read with SLSGetOnScreenWindowList). */
#include "ws.h"
#include <stdio.h>
#include <string.h>

static int fails;
static ws_server *srv;
static ws_wid W[4];
static const char NAMES[] = "ABCD";

typedef struct { ws_wid ids[16]; int n; } order_log;
static void on_visit(void *ctx, const ws_visit *v) { order_log *l = ctx; if (l->n < 16) l->ids[l->n++] = v->id; }

/* front-to-back list of the four windows, e.g. "C A D B" */
static void got_order(char *out)
{
	order_log l = { .n = 0 };
	ws_server_walk(srv, on_visit, &l);
	int k = 0;
	for (int i = l.n; i-- > 0;)
		for (int j = 0; j < 4; j++) if (l.ids[i] == W[j]) { if (k) out[k++] = ' '; out[k++] = NAMES[j]; }
	out[k] = 0;
}

static void expect(const char *step, const char *want)
{
	char got[32];
	got_order(got);
	if (strcmp(got, want)) { printf("MISMATCH at \"%s\": got [%s] want [%s]\n", step, got, want); fails++; }
}

static void fresh(void)
{
	if (srv) ws_server_free(srv);
	srv = ws_server_new(800, 600);
	for (int i = 0; i < 4; i++) W[i] = ws_create_window(srv, (ws_rect){ 10, 10, 40, 40 });
}
#define A W[0]
#define B W[1]
#define C W[2]
#define D W[3]

int main(void)
{
	/* sequence 1: relative ordering, order out, levels and sublevels */
	fresh();
	ws_order_window(srv, A, WS_ABOVE, 0); ws_order_window(srv, B, WS_ABOVE, 0); ws_order_window(srv, C, WS_ABOVE, 0);
	expect("A,B,C each above(0)", "C B A");
	ws_order_window(srv, A, WS_ABOVE, 0);              expect("A above(0) again", "A C B");
	ws_order_window(srv, C, WS_BELOW, B);              expect("C below B", "A B C");
	ws_order_window(srv, C, WS_ABOVE, A);              expect("C above A", "C A B");
	ws_order_window(srv, D, WS_ABOVE, B);              expect("D above B (D was out)", "C A D B");
	ws_order_window(srv, B, WS_OUT, 0);                expect("B out", "C A D");
	ws_order_window(srv, B, WS_BELOW, 0);              expect("B below(0)", "C A D B");
	ws_set_window_level(srv, C, 5);                    expect("C level 5", "C A D B");
	ws_set_window_level(srv, A, 5);                    expect("A level 5 too", "A C D B");
	ws_set_window_sublevel(srv, C, 3);                 expect("C sublevel 3", "C A D B");
	ws_set_window_sublevel(srv, A, 7);                 expect("A sublevel 7", "A C D B");
	ws_set_window_level(srv, C, 0); ws_set_window_level(srv, A, 0); ws_set_window_sublevel(srv, C, 0); ws_set_window_sublevel(srv, A, 0);
	expect("levels back to 0", "A C D B");

	/* sequence 2: level change semantics, relative windows at other levels, out or bogus relatives */
	fresh();
	ws_order_window(srv, A, WS_ABOVE, 0); ws_order_window(srv, B, WS_ABOVE, 0); ws_order_window(srv, C, WS_ABOVE, 0); ws_order_window(srv, D, WS_ABOVE, 0);
	expect("A,B,C,D above(0)", "D C B A");
	ws_set_window_level(srv, A, 0);                    expect("A level 0 (unchanged)", "D C B A");
	ws_set_window_level(srv, D, 2);                    expect("D level 2", "D C B A");
	ws_set_window_level(srv, A, 2);                    expect("A level 2", "A D C B");
	ws_set_window_level(srv, B, 2);                    expect("B level 2", "B A D C");
	ws_order_window(srv, C, WS_ABOVE, D);              expect("C above D (other level)", "B A D C");
	{ int lv = -1; ws_window_level(srv, C, &lv); if (lv != 0) { printf("MISMATCH: C adopted level %d (the real server keeps 0)\n", lv); fails++; } }
	ws_order_window(srv, C, WS_BELOW, B);              expect("C below B (other level)", "B A D C");
	ws_order_window(srv, C, WS_OUT, 0);
	ws_order_window(srv, A, WS_ABOVE, C);              expect("A above C (C is out)", "A B D");
	ws_order_window(srv, A, WS_ABOVE, 999999);         expect("A above a bogus id", "A B D");
	if (ws_order_window(srv, 999999, WS_ABOVE, 0) == 0) { printf("MISMATCH: ordering an unknown window must fail\n"); fails++; }
	ws_order_window(srv, C, WS_ABOVE, 0);              expect("C above(0) (back in)", "A B D C");
	ws_order_window(srv, C, WS_ABOVE, C);              expect("C above itself", "A B D C");

	ws_server_free(srv);
	printf(fails ? "%d differences from the real WindowServer\n" : "differential tests passed (ordering and levels match the real WindowServer)\n", fails);
	return fails != 0;
}
