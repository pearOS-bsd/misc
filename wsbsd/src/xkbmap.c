#include <string.h>
#include <stdlib.h>
#include <xkbcommon/xkbcommon.h>
#include "ws_xkb.h"
#include "ws_input.h"

static struct xkb_context *ctx;
static struct xkb_keymap *map;
static struct xkb_state *st;

int ws_xkb_init(const char *layout, const char *variant, const char *options)
{
	ws_xkb_close();
	ctx = xkb_context_new(XKB_CONTEXT_NO_FLAGS);
	if (!ctx) return -1;
	struct xkb_rule_names rn = { 0 };
	rn.rules = "evdev"; rn.model = "pc105";
	rn.layout = layout ? layout : getenv("WSD_XKB_LAYOUT");
	rn.variant = variant ? variant : getenv("WSD_XKB_VARIANT");
	rn.options = options ? options : getenv("WSD_XKB_OPTIONS");
	map = xkb_keymap_new_from_names(ctx, &rn, XKB_KEYMAP_COMPILE_NO_FLAGS);
	if (map) st = xkb_state_new(map);
	if (!st) { ws_xkb_close(); return -1; }
	return 0;
}

void ws_xkb_close(void)
{
	if (st) xkb_state_unref(st);
	if (map) xkb_keymap_unref(map);
	if (ctx) xkb_context_unref(ctx);
	st = NULL; map = NULL; ctx = NULL;
}

static void press(int evdev, enum xkb_key_direction d) { xkb_state_update_key(st, evdev + 8, d); }

int ws_xkb_chars(int mac, unsigned flags, int ignoring, char *out, size_t cap)
{
	if (!st || cap < 2) return 0;
	int ev = ws_input_evdev_code(mac);
	if (ev < 0) return 0;
	int held[4] = { 0 }, n = 0;
	if (!ignoring) {
		if (flags & 0x20000) held[n++] = 42;      /* shift */
		if (flags & 0x80000) held[n++] = 100;     /* option acts as AltGr (level 3) */
		if (flags & 0x40000) held[n++] = 29;      /* control */
	}
	for (int i = 0; i < n; i++) press(held[i], XKB_KEY_DOWN);
	if (flags & 0x10000) { press(58, XKB_KEY_DOWN); press(58, XKB_KEY_UP); }
	int len = xkb_state_key_get_utf8(st, ev + 8, out, cap);
	if (flags & 0x10000) { press(58, XKB_KEY_DOWN); press(58, XKB_KEY_UP); }
	for (int i = n - 1; i >= 0; i--) press(held[i], XKB_KEY_UP);
	if (len < 0 || (size_t)len >= cap) { out[0] = 0; return 0; }
	/* control characters (Return, Tab, Escape, Delete) are real text on macOS too; drop only NUL */
	return len;
}
