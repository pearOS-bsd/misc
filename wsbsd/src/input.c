#include "ws_input.h"
#include <math.h>
#include <string.h>

/* evdev key code -> macOS virtual key code (ANSI US layout, keys the Mac keyboard has) */
static const int16_t keymap[256] = {
	[1] = 0x36, [2] = 0x13, [3] = 0x14, [4] = 0x15, [5] = 0x16, [6] = 0x18, [7] = 0x17, [8] = 0x1b, [9] = 0x1d, [10] = 0x1a, [11] = 0x1e, [12] = 0x1c, [13] = 0x19, [14] = 0x34, [15] = 0x31,
	[16] = 0xd, [17] = 0xe, [18] = 0xf, [19] = 0x10, [20] = 0x12, [21] = 0x11, [22] = 0x21, [23] = 0x23, [24] = 0x20, [25] = 0x24, [26] = 0x22, [27] = 0x1f, [28] = 0x25, [29] = 0x3c,
	[30] = 0x1, [31] = 0x2, [32] = 0x3, [33] = 0x4, [34] = 0x6, [35] = 0x5, [36] = 0x27, [37] = 0x29, [38] = 0x26, [39] = 0x2a, [40] = 0x28, [41] = 0x33, [42] = 0x39, [43] = 0x2b,
	[44] = 0x7, [45] = 0x8, [46] = 0x9, [47] = 0xa, [48] = 0xc, [49] = 0x2e, [50] = 0x2f, [51] = 0x2c, [52] = 0x30, [53] = 0x2d, [54] = 0x3d, [55] = 0x44, [56] = 0x3b, [57] = 0x32,
	[58] = 0x3a, [59] = 0x7b, [60] = 0x79, [61] = 0x64, [62] = 0x77, [63] = 0x61, [64] = 0x62, [65] = 0x63, [66] = 0x65, [67] = 0x66, [68] = 0x6e, [69] = 0x48, [70] = 0x6c,
	[71] = 0x5a, [72] = 0x5c, [73] = 0x5d, [74] = 0x4f, [75] = 0x57, [76] = 0x58, [77] = 0x59, [78] = 0x46, [79] = 0x54, [80] = 0x55, [81] = 0x56, [82] = 0x53, [83] = 0x42,
	[86] = 0xb, [87] = 0x68, [88] = 0x70, [96] = 0x4d, [97] = 0x3f, [98] = 0x4c, [99] = 0x6a, [100] = 0x3e, [102] = 0x74, [103] = 0x7f, [104] = 0x75, [105] = 0x7c, [106] = 0x7d,
	[107] = 0x78, [108] = 0x7e, [109] = 0x7a, [110] = 0x73, [111] = 0x76, [113] = 0x4b, [114] = 0x4a, [115] = 0x49, [125] = 0x38, [126] = 0x37,
};

/* entries hold the macOS code + 1 so that 0 means "no such key" (the A key is code 0) */
int ws_input_mac_keycode(int c) { if (c < 0 || c > 255 || !keymap[c]) return -1; return keymap[c] - 1; }

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
