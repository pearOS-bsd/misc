#ifndef WS_TOUCHPAD_H
#define WS_TOUCHPAD_H
/* A touchpad (an evdev device with absolute axes AND BTN_TOOL_FINGER) is a pointing device, not a tablet: the finger moves the pointer relatively (the position the pad reports is only used as the distance moved), a short touch is a click (a tap), a tap with two fingers
 * a right click, two fingers moving scroll (natural direction, as the Mac's default), the pad's own button (clickpad) is the left button (the right one with two fingers on the pad). A tablet or a touch screen (no BTN_TOOL_FINGER) keeps its absolute behaviour. */
#include "ws_input.h"

typedef struct {
	int minx, maxx, miny, maxy;            /* the ranges of ABS_X / ABS_Y */
	int touching, fingers, maxf;           /* BTN_TOUCH, the number of fingers (BTN_TOOL_FINGER..QUINTTAP), the most in this touch */
	int x, y, have_pos, lx, ly, have_last; /* the position, the position of the previous report */
	int dirty;                             /* a position arrived since the last SYN */
	double t_down; double total;           /* when the touch began (ms), the distance moved in it (in units of the range) */
	double rx, ry, sx, sy;                 /* sub-pixel remainders of the motion and of the scroll */
	int natural;                           /* scroll direction: 1 natural (default), 0 the wheel's */
	double speed;                          /* the pointer moves this many screen widths for the pad's full width (default .5) */
	int left_as_right;                     /* BTN_LEFT pressed with two fingers on the pad: reported as the right button until it is released */
} ws_tp;

void ws_tp_init(ws_tp *tp, int minx, int maxx, int miny, int maxy);
void ws_tp_event(ws_tp *tp, ws_input *in, ws_server *srv, int type, int code, int value, double now_ms);
#endif
