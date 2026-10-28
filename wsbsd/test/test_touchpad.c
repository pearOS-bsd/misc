/* test_touchpad: a pad with absolute axes and BTN_TOOL_FINGER is a relative pointer with taps and scrolling, not a tablet */
#include <stdio.h>
#include "ws_touchpad.h"

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

static ws_server *s; static ws_wid w; static ws_input in; static ws_tp tp; static double t;
static void ev(int type, int code, int value) { ws_tp_event(&tp, &in, s, type, code, value, t); }
static void abs_xy(int x, int y) { ev(WSI_EV_ABS, 0, x); ev(WSI_EV_ABS, 1, y); ev(WSI_EV_SYN, 0, 0); }
static int count(int type) { ws_event e; int n = 0; while (ws_next_event(s, w, &e)) if (e.type == type) n++; return n; }

int main(void)
{
	s = ws_server_new(800, 600); w = ws_create_window(s, (ws_rect){ 0, 0, 800, 600 }); ws_order_window(s, w, WS_ABOVE, 0); ws_set_window_event_mask(s, w, -1);
	ws_input_init(&in, 800, 600); in.accel = 0; ws_tp_init(&tp, 0, 1000, 0, 600);
	int cx, cy;

	/* a finger at the top-left corner does not teleport the pointer, and touching is not a button press */
	t = 0; ev(WSI_EV_KEY, 0x145, 1); ev(WSI_EV_KEY, 0x14a, 1); abs_xy(10, 10);
	ws_cursor_pos(s, &cx, &cy); CHECK(cx == 400 && cy == 300);
	t = 400; abs_xy(110, 10); ws_cursor_pos(s, &cx, &cy); CHECK(cx > 400 && cy == 300);             /* moving right moves right, relatively */
	CHECK(count(WS_EV_MOUSE_DOWN) == 0);
	ev(WSI_EV_KEY, 0x14a, 0); ev(WSI_EV_KEY, 0x145, 0); CHECK(count(WS_EV_MOUSE_DOWN) == 0);       /* a long touch that moved is no tap */

	/* tap = left click */
	t = 1000; ev(WSI_EV_KEY, 0x145, 1); ev(WSI_EV_KEY, 0x14a, 1); abs_xy(500, 300); t = 1100; ev(WSI_EV_KEY, 0x14a, 0); ev(WSI_EV_KEY, 0x145, 0);
	CHECK(count(WS_EV_MOUSE_DOWN) == 1);

	/* two-finger tap = right click */
	t = 2000; ev(WSI_EV_KEY, 0x145, 1); ev(WSI_EV_KEY, 0x14d, 1); ev(WSI_EV_KEY, 0x14a, 1); abs_xy(500, 300); t = 2100; ev(WSI_EV_KEY, 0x14a, 0); ev(WSI_EV_KEY, 0x14d, 0); ev(WSI_EV_KEY, 0x145, 0);
	{ ws_event e; int right = 0; while (ws_next_event(s, w, &e)) if (e.type == WS_EV_MOUSE_DOWN && (e.buttons & 2)) right = 1; CHECK(right); }

	/* two fingers moving scroll, the pointer stays */
	ws_cursor_pos(s, &cx, &cy); int px = cx, py = cy;
	t = 3000; ev(WSI_EV_KEY, 0x14d, 1); ev(WSI_EV_KEY, 0x14a, 1); abs_xy(500, 300); abs_xy(500, 360); abs_xy(500, 420);
	ws_cursor_pos(s, &cx, &cy); CHECK(cx == px && cy == py);
	CHECK(count(WS_EV_SCROLL) > 0);
	if (failures) { printf("%d failure(s)\n", failures); return 1; } printf("test_touchpad: ok\n"); return 0;
}
