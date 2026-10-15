/* test_input: evdev events through ws_input into a server with one window: pointer motion and acceleration, buttons, wheel, absolute pointers, key translation, modifiers, repeat */
#include <stdio.h>
#include <string.h>
#include "ws_input.h"

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

static int next_of(ws_server *s, ws_wid w, int type, ws_event *out)
{
	ws_event e;
	while (ws_next_event(s, w, &e)) { if (e.type == type) { *out = e; return 1; } }
	return 0;
}

int main(void)
{
	ws_server *s = ws_server_new(800, 600);
	ws_wid w = ws_create_window(s, (ws_rect){ 0, 0, 800, 600 });
	ws_order_window(s, w, WS_ABOVE, 0); ws_set_window_event_mask(s, w, -1);
	ws_input in; ws_input_init(&in, 800, 600); in.accel = 0;                   /* exact deltas */
	ws_event e;

	/* motion: relative, applied at SYN, clamped to the screen */
	ws_input_feed(&in, s, WSI_EV_REL, 0, 10); ws_input_feed(&in, s, WSI_EV_REL, 1, -5);
	int cx, cy; ws_cursor_pos(s, &cx, &cy); CHECK(cx == 400 && cy == 300);        /* nothing before SYN */
	ws_input_feed(&in, s, WSI_EV_SYN, 0, 0); ws_cursor_pos(s, &cx, &cy); CHECK(cx == 410 && cy == 295);
	ws_input_feed(&in, s, WSI_EV_REL, 0, -5000); ws_input_feed(&in, s, WSI_EV_SYN, 0, 0); ws_cursor_pos(s, &cx, &cy); CHECK(cx == 0);
	ws_input_feed(&in, s, WSI_EV_REL, 0, 300); ws_input_feed(&in, s, WSI_EV_SYN, 0, 0);

	/* acceleration: a fast report moves further than a slow one, never more than 3x */
	ws_input a2; ws_input_init(&a2, 800, 600); ws_input_feed(&a2, s, WSI_EV_REL, 0, 1); ws_input_feed(&a2, s, WSI_EV_SYN, 0, 0); double slow = a2.x - 400;
	ws_input_init(&a2, 800, 600); ws_input_feed(&a2, s, WSI_EV_REL, 0, 40); ws_input_feed(&a2, s, WSI_EV_SYN, 0, 0); double fast = a2.x - 400;
	CHECK(slow >= 1 && slow < 2 && fast > 40 && fast <= 120);

	/* buttons */
	ws_input_feed(&in, s, 1, 0x110, 1); CHECK(next_of(s, w, WS_EV_MOUSE_DOWN, &e) && (e.buttons & 1));
	ws_input_feed(&in, s, 1, 0x110, 0); CHECK(next_of(s, w, WS_EV_MOUSE_UP, &e));
	ws_input_feed(&in, s, 1, 0x111, 1); CHECK(next_of(s, w, WS_EV_MOUSE_DOWN, &e) && (e.buttons & 2)); ws_input_feed(&in, s, 1, 0x111, 0);
	ws_input_feed(&in, s, 1, 0x112, 1); CHECK(next_of(s, w, WS_EV_MOUSE_DOWN, &e) && (e.buttons & 4)); ws_input_feed(&in, s, 1, 0x112, 0);
	ws_input_feed(&in, s, 1, 0x113, 1); CHECK(next_of(s, w, WS_EV_MOUSE_DOWN, &e) && (e.buttons & 8)); ws_input_feed(&in, s, 1, 0x113, 0);

	/* wheel: notches up are positive dy, horizontal right is negative dx; hi-res reports 120 per notch */
	ws_input_feed(&in, s, WSI_EV_REL, 8, 2); CHECK(next_of(s, w, WS_EV_SCROLL, &e) && e.dy > 0);
	ws_input_feed(&in, s, WSI_EV_REL, 8, -1); CHECK(next_of(s, w, WS_EV_SCROLL, &e) && e.dy < 0);
	ws_input_feed(&in, s, WSI_EV_REL, 6, 1); CHECK(next_of(s, w, WS_EV_SCROLL, &e) && e.dx < 0);
	ws_input_feed(&in, s, WSI_EV_REL, 11, 240); CHECK(next_of(s, w, WS_EV_SCROLL, &e) && e.dy > 0);

	/* an absolute pointer maps its range onto the screen */
	ws_input ab; ws_input_init(&ab, 800, 600); ws_input_set_abs_range(&ab, 0, 0, 4095); ws_input_set_abs_range(&ab, 1, 0, 4095);
	ws_input_feed(&ab, s, WSI_EV_ABS, 0, 4095); ws_input_feed(&ab, s, WSI_EV_ABS, 1, 0); ws_input_feed(&ab, s, WSI_EV_SYN, 0, 0);
	ws_cursor_pos(s, &cx, &cy); CHECK(cx == 799 && cy == 0);
	ws_input_feed(&ab, s, WSI_EV_ABS, 0, 0); ws_input_feed(&ab, s, WSI_EV_ABS, 1, 4095); ws_input_feed(&ab, s, WSI_EV_SYN, 0, 0);
	ws_cursor_pos(s, &cx, &cy); CHECK(cx == 0 && cy == 599);

	/* keys: evdev codes become macOS virtual key codes (A = 0, S = 1, Return = 0x24, Escape = 0x35, arrows 0x7b..0x7e) */
	CHECK(ws_input_mac_keycode(30) == 0 && ws_input_mac_keycode(31) == 1 && ws_input_mac_keycode(28) == 0x24 && ws_input_mac_keycode(1) == 0x35 && ws_input_mac_keycode(105) == 0x7b && ws_input_mac_keycode(108) == 0x7d);
	CHECK(ws_input_mac_keycode(0) == -1 && ws_input_mac_keycode(200) == -1 && ws_input_mac_keycode(300) == -1);
	ws_input_feed(&in, s, 1, 30, 1); CHECK(next_of(s, w, WS_EV_KEY_DOWN, &e) && e.key == 0);
	ws_input_feed(&in, s, 1, 30, 2); CHECK(next_of(s, w, WS_EV_KEY_DOWN, &e) && e.key == 0);              /* the kernel's repeat */
	ws_input_feed(&in, s, 1, 30, 0); CHECK(next_of(s, w, WS_EV_KEY_UP, &e) && e.key == 0);
	ws_input_feed(&in, s, 1, 28, 1); CHECK(next_of(s, w, WS_EV_KEY_DOWN, &e) && e.key == 0x24); ws_input_feed(&in, s, 1, 28, 0);

	/* modifiers: shift then command change the flags (flagsChanged), no key event; releasing one of two shifts keeps the group */
	ws_input_feed(&in, s, 1, 42, 1); CHECK(next_of(s, w, WS_EV_FLAGS, &e) && (e.flags & 0x20000));
	ws_input_feed(&in, s, 1, 125, 1); CHECK(next_of(s, w, WS_EV_FLAGS, &e) && (e.flags & 0x20000) && (e.flags & 0x100000));
	ws_input_feed(&in, s, 1, 54, 1); ws_input_feed(&in, s, 1, 42, 0); CHECK(in.flags & 0x20000);
	ws_input_feed(&in, s, 1, 54, 0); CHECK(!(in.flags & 0x20000) && (in.flags & 0x100000));
	ws_input_feed(&in, s, 1, 125, 0); CHECK((in.flags & 0xffff0000u) == 0 || in.flags == 0);
	ws_input_feed(&in, s, 1, 58, 1); CHECK(in.flags & 0x10000); ws_input_feed(&in, s, 1, 58, 0); CHECK(in.flags & 0x10000);   /* caps lock stays on until the next press */
	ws_input_feed(&in, s, 1, 58, 1); CHECK(!(in.flags & 0x10000)); ws_input_feed(&in, s, 1, 58, 0);

	if (failures) { printf("%d failures\n", failures); return 1; }
	printf("input translation: all checks passed\n");
	return 0;
}
