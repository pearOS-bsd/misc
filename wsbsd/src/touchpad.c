/* The touchpad gestures of ws_touchpad.h. */
#include <math.h>
#include <string.h>
#include "ws_touchpad.h"

enum { ABS_X_ = 0, ABS_Y_ = 1, BTN_LEFT_ = 0x110, BTN_RIGHT_ = 0x111, BTN_TOUCH_ = 0x14a, BTN_TOOL_FINGER_ = 0x145, BTN_TOOL_QUINTTAP_ = 0x148, BTN_TOOL_DOUBLETAP_ = 0x14d, BTN_TOOL_TRIPLETAP_ = 0x14e, BTN_TOOL_QUADTAP_ = 0x14f };

void ws_tp_init(ws_tp *tp, int minx, int maxx, int miny, int maxy)
{
	memset(tp, 0, sizeof *tp); tp->minx = minx; tp->maxx = maxx > minx ? maxx : minx + 1; tp->miny = miny; tp->maxy = maxy > miny ? maxy : miny + 1; tp->natural = 1; tp->speed = 0.5;
}

static void click(ws_input *in, ws_server *srv, int button)
{
	ws_input_feed(in, srv, WSI_EV_KEY, button, 1); ws_input_feed(in, srv, WSI_EV_KEY, button, 0);
}

static void count_fingers(ws_tp *tp, int code, int value)
{
	int n = code == BTN_TOOL_FINGER_ ? 1 : code == BTN_TOOL_DOUBLETAP_ ? 2 : code == BTN_TOOL_TRIPLETAP_ ? 3 : code == BTN_TOOL_QUADTAP_ ? 4 : 5;
	if (value) tp->fingers = n; else if (tp->fingers == n) tp->fingers = 0;
	if (tp->fingers > tp->maxf) tp->maxf = tp->fingers;
	tp->have_last = 0;                                                     /* the reference point changes with the number of fingers */
}

void ws_tp_event(ws_tp *tp, ws_input *in, ws_server *srv, int type, int code, int value, double now_ms)
{
	if (type == WSI_EV_ABS) { if (code == ABS_X_) { tp->x = value; tp->dirty = 1; tp->have_pos |= 1; } else if (code == ABS_Y_) { tp->y = value; tp->dirty = 1; tp->have_pos |= 2; } return; }
	if (type == WSI_EV_KEY) {
		if (code == BTN_TOUCH_) {
			if (value && !tp->touching) { tp->touching = 1; tp->t_down = now_ms; tp->total = 0; tp->maxf = tp->fingers; tp->have_last = 0; tp->rx = tp->ry = tp->sx = tp->sy = 0; }
			else if (!value && tp->touching) {
				tp->touching = 0; tp->have_last = 0;
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
				if (tp->fingers >= 2) {                                                         /* scroll: a notch per 2.5 % of the pad */
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
