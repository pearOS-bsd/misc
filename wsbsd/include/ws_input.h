#ifndef WS_INPUT_H
#define WS_INPUT_H
/* Raw input (evdev events: type, code, value) to window-server events: pointer motion with acceleration, buttons, wheel scrolling, absolute pointers (tablets, touch screens),
 * keys translated from evdev codes to macOS virtual key codes, modifier state as CGEventFlags with flagsChanged, key repeat as repeated key-down events. Platform independent. */
#include <stdint.h>
#include "ws.h"

enum { WSI_EV_SYN = 0, WSI_EV_KEY = 1, WSI_EV_REL = 2, WSI_EV_ABS = 3 };

typedef struct {
	int sw, sh;                       /* screen size */
	double x, y;                      /* pointer position */
	int buttons;                      /* bit 0 left, 1 right, 2 middle, 3 side, 4 extra */
	uint32_t flags;                   /* modifier state (CGEventFlags + device bits) */
	uint32_t moddown;                 /* which modifier keys are held, one bit each */
	int motion, abs_dirty;
	int abs_min[2], abs_max[2], abs_set[2], abs_val[2];
	double accel;                     /* pointer acceleration gain per pixel of speed, 0 = none */
	int init;
} ws_input;

void ws_input_init(ws_input *in, int sw, int sh);
void ws_input_set_abs_range(ws_input *in, int axis, int min, int max);       /* ABS_X / ABS_Y ranges of a device that reports absolute positions */
void ws_input_feed(ws_input *in, ws_server *srv, int type, int code, int value);   /* one input_event; motion and absolute positions are applied at EV_SYN */
int ws_input_mac_keycode(int evdev_code);                                     /* macOS virtual key code, -1 when there is none */
int ws_input_evdev_code(int mac_keycode);                                    /* evdev code for a macOS virtual key code, -1 when there is none */
#endif
