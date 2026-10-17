#include "ws_input.h"
#include <math.h>
#include <string.h>


static int modifier_index(int c) { switch (c) { case 42: return 0; case 54: return 1; case 29: return 2; case 97: return 3; case 56: return 4; case 100: return 5; case 125: return 6; default: return 7; } }
static uint32_t modifier_flags(uint32_t down)    /* the held modifiers as flags: the group's mask while either side is down, plus the device bits */
{
	static const int codes[8] = { 42, 54, 29, 97, 56, 100, 125, 126 };
	uint32_t f = 0;
	for (int i = 0; i < 8; i++) if (down & (1u << i)) { uint32_t m = 0; switch (codes[i]) { case 42: m = 0x20000 | 0x2; break; case 54: m = 0x20000 | 0x4; break; case 29: m = 0x40000 | 0x1; break; case 97: m = 0x40000 | 0x2000; break; case 56: m = 0x80000 | 0x20; break; case 100: m = 0x80000 | 0x40; break; case 125: m = 0x100000 | 0x8; break; default: m = 0x100000 | 0x10; } f |= m; }
	return f;
}

/* modifier keys: evdev code -> CGEventFlags bits (device-independent mask | device-dependent bit) */
static uint32_t modifier_bits(int c)
{
	switch (c) {
	case 42: return 0x20000 | 0x2;       case 54: return 0x20000 | 0x4;        /* shift */
	case 29: return 0x40000 | 0x1;       case 97: return 0x40000 | 0x2000;     /* control */
	case 56: return 0x80000 | 0x20;      case 100: return 0x80000 | 0x40;      /* option */
	case 125: return 0x100000 | 0x8;     case 126: return 0x100000 | 0x10;     /* command */
	}
	return 0;
}

void ws_input_init(ws_input *in, int sw, int sh)
{
	memset(in, 0, sizeof *in);
	in->sw = sw; in->sh = sh; in->x = sw / 2.0; in->y = sh / 2.0; in->accel = 0.03; in->init = 1;
}
void ws_input_set_abs_range(ws_input *in, int axis, int min, int max) { if (axis == 0 || axis == 1) { in->abs_min[axis] = min; in->abs_max[axis] = max; in->abs_set[axis] = 1; } }

static void clampxy(ws_input *in) { if (in->x < 0) in->x = 0; if (in->y < 0) in->y = 0; if (in->x > in->sw - 1) in->x = in->sw - 1; if (in->y > in->sh - 1) in->y = in->sh - 1; }

void ws_input_feed(ws_input *in, ws_server *srv, int type, int code, int value)
{
	static const int btn_bit[5] = { 1, 2, 4, 8, 16 };
	switch (type) {
	case WSI_EV_REL:
		if (code == 0 || code == 1) {                                     /* REL_X, REL_Y: acceleration grows with the speed of one report */
			double d = value, gain = 1.0 + in->accel * fabs(d); if (gain > 3.0) gain = 3.0;
			if (code == 0) in->x += d * gain; else in->y += d * gain;
			in->motion = 1;
		} else if (code == 8) ws_server_scroll(srv, (int)in->x, (int)in->y, 0, value, 0);                        /* REL_WHEEL: notches (up positive) */
		else if (code == 6) ws_server_scroll(srv, (int)in->x, (int)in->y, -value, 0, 0);                         /* REL_HWHEEL: right positive, the system's dx is left positive */
		else if (code == 11) ws_server_scroll(srv, (int)in->x, (int)in->y, 0, value / 120, 0);                   /* REL_WHEEL_HI_RES: 120 per notch */
		else if (code == 12) ws_server_scroll(srv, (int)in->x, (int)in->y, -(value / 120), 0, 0);
		break;
	case WSI_EV_ABS:
		if (code == 0 || code == 1) { in->abs_val[code] = value; in->abs_dirty = 1; }                          /* ABS_X, ABS_Y */
		break;
	case WSI_EV_KEY:
		if (code >= 0x110 && code <= 0x114) {                              /* BTN_LEFT .. BTN_EXTRA */
			int bit = btn_bit[code - 0x110];
			in->buttons = value ? (in->buttons | bit) : (in->buttons & ~bit);
			ws_server_mouse(srv, (int)in->x, (int)in->y, in->buttons);
		} else if (code == 0x14a || code == 0x14b) {                       /* BTN_TOUCH / BTN_STYLUS-like: a touch is a left click */
			in->buttons = value ? (in->buttons | 1) : (in->buttons & ~1);
			ws_server_mouse(srv, (int)in->x, (int)in->y, in->buttons);
		} else {
			uint32_t m = modifier_bits(code);
			if (m) {                                                       /* a modifier changes the flags, no key event */
				if (value) in->moddown |= 1u << modifier_index(code); else in->moddown &= ~(1u << modifier_index(code));
				in->flags = (in->flags & 0x10000u) | modifier_flags(in->moddown);
				ws_server_flags(srv, in->flags);
			} else if (code == 58 && value == 1) { in->flags ^= 0x10000; ws_server_flags(srv, in->flags); }      /* caps lock toggles on press */
			else {
				int kc = ws_input_mac_keycode(code);
				if (kc >= 0 && value >= 0 && value <= 2) ws_server_key(srv, kc, value != 0);                              /* press, release and the kernel's repeats (value 2) */
			}
		}
		break;
	case WSI_EV_SYN:
		if (in->abs_dirty) {
			for (int a = 0; a < 2; a++) if (in->abs_set[a] && in->abs_max[a] > in->abs_min[a]) {
				double f = (double)(in->abs_val[a] - in->abs_min[a]) / (double)(in->abs_max[a] - in->abs_min[a]);
				if (a == 0) in->x = f * (in->sw - 1); else in->y = f * (in->sh - 1);
			}
			in->abs_dirty = 0; in->motion = 1;
		}
		if (in->motion) { clampxy(in); in->motion = 0; ws_server_mouse(srv, (int)in->x, (int)in->y, in->buttons); }
		break;
	}
}
