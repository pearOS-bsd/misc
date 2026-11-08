/* The touchpad gestures of ws_touchpad.h. */
#include <math.h>
#include <string.h>
#include "ws_touchpad.h"

enum { ABS_X_ = 0, ABS_Y_ = 1, BTN_LEFT_ = 0x110, BTN_RIGHT_ = 0x111, BTN_TOUCH_ = 0x14a, BTN_TOOL_FINGER_ = 0x145, BTN_TOOL_QUINTTAP_ = 0x148, BTN_TOOL_DOUBLETAP_ = 0x14d, BTN_TOOL_TRIPLETAP_ = 0x14e, BTN_TOOL_QUADTAP_ = 0x14f, ABS_MT_SLOT_ = 0x2f, ABS_MT_X_ = 0x35, ABS_MT_Y_ = 0x36, ABS_MT_ID_ = 0x39,
       KEY_LEFTCTRL_ = 29, KEY_F4_ = 62, KEY_F11_ = 87, KEY_UP_ = 103, KEY_LEFT_ = 105, KEY_RIGHT_ = 106, KEY_DOWN_ = 108 };

void ws_tp_init(ws_tp *tp, int minx, int maxx, int miny, int maxy)
{
	memset(tp, 0, sizeof *tp); tp->minx = minx; tp->maxx = maxx > minx ? maxx : minx + 1; tp->miny = miny; tp->maxy = maxy > miny ? maxy : miny + 1; tp->natural = 1; tp->speed = 0.5;
}

static void click(ws_input *in, ws_server *srv, int button)
{
	ws_input_feed(in, srv, WSI_EV_KEY, button, 1); ws_input_feed(in, srv, WSI_EV_KEY, button, 0);
}

/* a key chord, as if typed: modifier down, key down, key up, modifier up (mod 0 = the key alone) */
static void chord(ws_input *in, ws_server *srv, int mod, int key)
{
	if (mod) ws_input_feed(in, srv, WSI_EV_KEY, mod, 1);
	ws_input_feed(in, srv, WSI_EV_KEY, key, 1); ws_input_feed(in, srv, WSI_EV_KEY, key, 0);
	if (mod) ws_input_feed(in, srv, WSI_EV_KEY, mod, 0);
}

/* the centre of the fingers and their mean distance from it (0 when the pad reports only the first finger) */
static int centre(ws_tp *tp, double *cx, double *cy, double *spread)
{
	int n = 0; double sx = 0, sy = 0; for (int i = 0; i < 5; i++) if (tp->mt[i].active) { sx += tp->mt[i].x; sy += tp->mt[i].y; n++; }
	if (n >= 2) { *cx = sx / n; *cy = sy / n; double d = 0; for (int i = 0; i < 5; i++) if (tp->mt[i].active) d += hypot(tp->mt[i].x - *cx, tp->mt[i].y - *cy); *spread = d / n; return n; }
	*cx = tp->x; *cy = tp->y; *spread = 0; return 0;
}

static void gesture(ws_tp *tp, ws_input *in, ws_server *srv)
{
	double cx, cy, sp; int n = centre(tp, &cx, &cy, &sp);
	if (!tp->g_ref) { tp->g_ref = 1; tp->g_cx = cx; tp->g_cy = cy; tp->g_spread = sp; return; }
	if (tp->g_done) return;
	double rx = (double)(tp->maxx - tp->minx), ry = (double)(tp->maxy - tp->miny), dx = (cx - tp->g_cx) / rx, dy = (cy - tp->g_cy) / ry;
	if (tp->fingers >= 4 && n >= 4 && tp->g_spread > 0) {
		if (sp < 0.7 * tp->g_spread) { chord(in, srv, 0, KEY_F4_); tp->g_done = 1; return; }                        /* pinch: Launchpad */
		if (sp > 1.4 * tp->g_spread) { chord(in, srv, 0, KEY_F11_); tp->g_done = 1; return; }                       /* spread: Show Desktop */
	}
	if (fabs(dx) < 0.12 && fabs(dy) < 0.12) return;
	if (fabs(dx) >= fabs(dy)) chord(in, srv, KEY_LEFTCTRL_, dx < 0 ? KEY_RIGHT_ : KEY_LEFT_);                         /* fingers to the left: the next Space */
	else chord(in, srv, KEY_LEFTCTRL_, dy < 0 ? KEY_UP_ : KEY_DOWN_);                                              /* up: Mission Control, down: App Expose */
	tp->g_done = 1;
}

static void count_fingers(ws_tp *tp, int code, int value)
{
	int n = code == BTN_TOOL_FINGER_ ? 1 : code == BTN_TOOL_DOUBLETAP_ ? 2 : code == BTN_TOOL_TRIPLETAP_ ? 3 : code == BTN_TOOL_QUADTAP_ ? 4 : 5;
	if (value) tp->fingers = n; else if (tp->fingers == n) tp->fingers = 0;
	if (tp->fingers > tp->maxf) tp->maxf = tp->fingers;
	tp->have_last = 0; tp->g_ref = 0;                                       /* the reference point changes with the number of fingers */
}

void ws_tp_event(ws_tp *tp, ws_input *in, ws_server *srv, int type, int code, int value, double now_ms)
{
	if (type == WSI_EV_ABS && code >= ABS_MT_SLOT_ && code <= ABS_MT_ID_) {                    /* multi-touch slots: positions of up to five fingers */
		if (code == ABS_MT_SLOT_) tp->mt_slot = value >= 0 && value < 5 ? value : 4;
		else if (code == ABS_MT_X_) { tp->mt[tp->mt_slot].x = value; tp->mt[tp->mt_slot].active = 1; }
		else if (code == ABS_MT_Y_) { tp->mt[tp->mt_slot].y = value; tp->mt[tp->mt_slot].active = 1; }
		else if (code == ABS_MT_ID_ && value < 0) tp->mt[tp->mt_slot].active = 0;
		tp->dirty = 1; return;
	}
	if (type == WSI_EV_ABS) { if (code == ABS_X_) { tp->x = value; tp->dirty = 1; tp->have_pos |= 1; } else if (code == ABS_Y_) { tp->y = value; tp->dirty = 1; tp->have_pos |= 2; } return; }
	if (type == WSI_EV_KEY) {
		if (code == BTN_TOUCH_) {
			if (value && !tp->touching) { tp->touching = 1; tp->t_down = now_ms; tp->total = 0; tp->maxf = tp->fingers; tp->have_last = 0; tp->rx = tp->ry = tp->sx = tp->sy = 0; }
			else if (!value && tp->touching) {
				tp->touching = 0; tp->have_last = 0; tp->g_ref = tp->g_done = 0; for (int i = 0; i < 5; i++) tp->mt[i].active = 0;
				double rx = (double)(tp->maxx - tp->minx), ry = (double)(tp->maxy - tp->miny);
				if (now_ms - tp->t_down < 220 && tp->total < 0.025 * (rx + ry) / 2) click(in, srv, tp->maxf >= 2 ? BTN_RIGHT_ : BTN_LEFT_);       /* a tap */
				tp->fingers = 0; tp->maxf = 0;
			}
		} else if (code == BTN_TOOL_FINGER_ || code == BTN_TOOL_QUINTTAP_ || (code >= BTN_TOOL_DOUBLETAP_ && code <= BTN_TOOL_QUADTAP_)) count_fingers(tp, code, value);
		else if (code == BTN_LEFT_) {                                                             /* the pad's button */
			if (value) { tp->left_as_right = tp->fingers >= 2; ws_input_feed(in, srv, WSI_EV_KEY, tp->left_as_right ? BTN_RIGHT_ : BTN_LEFT_, 1); }
			else { ws_input_feed(in, srv, WSI_EV_KEY, tp->left_as_right ? BTN_RIGHT_ : BTN_LEFT_, 0); tp->left_as_right = 0; }
		} else ws_input_feed(in, srv, type, code, value);                                         /* the other buttons as they are */
		return;
	}
	if (type != WSI_EV_SYN) return;
	if (tp->dirty && tp->touching && tp->have_pos == 3) {
		if (tp->have_last) {
			double rx = (double)(tp->maxx - tp->minx), ry = (double)(tp->maxy - tp->miny), dx = tp->x - tp->lx, dy = tp->y - tp->ly;
			if (fabs(dx) < 0.3 * rx && fabs(dy) < 0.3 * ry) {                                 /* a jump (a finger lifted and another put down) is not motion */
				tp->total += (fabs(dx) + fabs(dy)) / 2;
				if (tp->fingers >= 3) gesture(tp, in, srv);
				else if (tp->fingers == 2) {                                                    /* scroll: a notch per 2.5 % of the pad */
					tp->sx += (tp->natural ? -dx : dx) / (0.025 * rx); tp->sy += (tp->natural ? dy : -dy) / (0.025 * ry);       /* natural: the content follows the fingers */
					int nx = (int)tp->sx, ny = (int)tp->sy; if (nx) { tp->sx -= nx; ws_input_feed(in, srv, WSI_EV_REL, 6, nx); } if (ny) { tp->sy -= ny; ws_input_feed(in, srv, WSI_EV_REL, 8, ny); }
				} else if (tp->fingers == 1) {                                                  /* pointer: the pad's width is `speed` screen widths */
					double kx = tp->speed * in->sw / rx;
					tp->rx += dx * kx; tp->ry += dy * kx; int mx = (int)tp->rx, my = (int)tp->ry; tp->rx -= mx; tp->ry -= my;
					if (mx) ws_input_feed(in, srv, WSI_EV_REL, 0, mx); if (my) ws_input_feed(in, srv, WSI_EV_REL, 1, my);
				}
			}
		}
		tp->lx = tp->x; tp->ly = tp->y; tp->have_last = 1; tp->dirty = 0;
	}
	ws_input_feed(in, srv, WSI_EV_SYN, 0, 0);
}
