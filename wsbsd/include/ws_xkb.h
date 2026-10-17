#ifndef WS_XKB_H
#define WS_XKB_H
/* Keyboard layouts through xkbcommon: macOS virtual key codes and CGEventFlags modifiers to the characters the key produces in the configured layout. */
#include <stddef.h>
int  ws_xkb_init(const char *layout, const char *variant, const char *options);   /* NULL = environment / system default; 0 on success */
void ws_xkb_close(void);
/* UTF-8 text of a key press; ignoring_mods gives the characters without Shift/Option (charactersIgnoringModifiers). Returns the length, 0 when the key produces no text. */
int  ws_xkb_chars(int mac_keycode, unsigned flags, int ignoring_mods, char *out, size_t cap);
#endif
