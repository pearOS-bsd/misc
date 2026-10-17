/* Carbon umbrella header: the parts applications commonly take from it without calling the (long deprecated) Carbon API itself. The virtual key codes of HIToolbox/Events.h
 * (ANSI layout, the values AppKit reports in -[NSEvent keyCode]) and the basic types. */
#ifndef WSBSD_CARBON_H
#define WSBSD_CARBON_H
#include <CoreServices/CoreServices.h>
enum {
	kVK_ANSI_A = 0x00, kVK_ANSI_S = 0x01, kVK_ANSI_D = 0x02, kVK_ANSI_F = 0x03, kVK_ANSI_H = 0x04, kVK_ANSI_G = 0x05, kVK_ANSI_Z = 0x06, kVK_ANSI_X = 0x07, kVK_ANSI_C = 0x08, kVK_ANSI_V = 0x09,
	kVK_ANSI_B = 0x0B, kVK_ANSI_Q = 0x0C, kVK_ANSI_W = 0x0D, kVK_ANSI_E = 0x0E, kVK_ANSI_R = 0x0F, kVK_ANSI_Y = 0x10, kVK_ANSI_T = 0x11, kVK_ANSI_O = 0x1F, kVK_ANSI_U = 0x20, kVK_ANSI_I = 0x22,
	kVK_ANSI_P = 0x23, kVK_ANSI_L = 0x25, kVK_ANSI_J = 0x26, kVK_ANSI_K = 0x28, kVK_ANSI_N = 0x2D, kVK_ANSI_M = 0x2E,
	kVK_Return = 0x24, kVK_Tab = 0x30, kVK_Space = 0x31, kVK_Delete = 0x33, kVK_Escape = 0x35, kVK_Command = 0x37, kVK_Shift = 0x38, kVK_CapsLock = 0x39, kVK_Option = 0x3A, kVK_Control = 0x3B,
	kVK_RightShift = 0x3C, kVK_RightOption = 0x3D, kVK_RightControl = 0x3E, kVK_Function = 0x3F, kVK_ForwardDelete = 0x75, kVK_Home = 0x73, kVK_End = 0x77, kVK_PageUp = 0x74, kVK_PageDown = 0x79,
	kVK_LeftArrow = 0x7B, kVK_RightArrow = 0x7C, kVK_DownArrow = 0x7D, kVK_UpArrow = 0x7E, kVK_ANSI_KeypadEnter = 0x4C,
	kVK_F1 = 0x7A, kVK_F2 = 0x78, kVK_F3 = 0x63, kVK_F4 = 0x76, kVK_F5 = 0x60, kVK_F6 = 0x61, kVK_F7 = 0x62, kVK_F8 = 0x64, kVK_F9 = 0x65, kVK_F10 = 0x6D, kVK_F11 = 0x67, kVK_F12 = 0x6F,
};
#endif
