#include <stdio.h>
#include <string.h>
#include "ws_xkb.h"
static int fails;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); fails++; } } while (0)
static int eq(int kc, unsigned fl, int ign, const char *want) { char b[16] = ""; ws_xkb_chars(kc, fl, ign, b, sizeof b); if (strcmp(b, want)) printf("  key %d: got '%s' want '%s'\n", kc, b, want); return !strcmp(b, want); }
int main(void)
{
	CHECK(ws_xkb_init("us", "", "") == 0);
	CHECK(eq(0, 0, 0, "a"));
	CHECK(eq(0, 0x20000, 0, "A"));
	CHECK(eq(0, 0x10000, 0, "A"));
	CHECK(eq(18, 0x20000, 0, "!"));
	CHECK(eq(18, 0x20000, 1, "1"));
	if (ws_xkb_init("ro", "", "") == 0) {
		CHECK(eq(0, 0, 0, "a"));
		CHECK(eq(0, 0x80000, 0, "ă"));      /* AltGr+A */
		CHECK(eq(1, 0x80000, 0, "ș"));      /* AltGr+S */
		CHECK(eq(17, 0x80000, 0, "ț"));     /* AltGr+T */
	} else printf("ro layout unavailable, skipped\n");
	if (ws_xkb_init("de", "", "") == 0) { CHECK(eq(6, 0, 0, "y")); CHECK(eq(16, 0, 0, "z")); }
	ws_xkb_close();
	printf(fails ? "xkb: %d failures\n" : "xkb: ok\n", fails);
	return fails != 0;
}
