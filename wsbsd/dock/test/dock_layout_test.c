/* The layout of the Dock against what was measured on the real one (3440 px wide screen, tile 58, large 99, 16 apps, a separator, a document and the Trash): at rest the first tile is centred at x = 1178.5
 * with a pitch of 62 and the bar spans 1140 ... 2299; with the pointer at 1488 the icons next to the pointer are about 1.48, 1.67 and 1.31 times their rest width. */
#include <stdio.h>
#include <math.h>
#include <stdlib.h>
#include "../dock_layout.h"
static int failures;
#define CHECK(c, ...) do { if (!(c)) { failures++; printf("FAIL: " __VA_ARGS__); printf("\n"); } } while (0)
int main(void)
{
	DockMetrics m = { 58, 99, 1, 3440 }; DockItem items[20]; DockSlot s[20]; DockBar bar;
	for (int i = 0; i < 16; i++) items[i].kind = DOCK_APP;
	items[16].kind = DOCK_SEPARATOR; items[17].kind = DOCK_OTHER; items[18].kind = DOCK_TRASH;
	dock_layout(&m, items, 19, -1, s, &bar);
	printf("rest: bar %.1f .. %.1f, first centre %.2f pitch %.2f art %.0f\n", bar.bar_x, bar.bar_x + bar.bar_w, s[0].cx, s[1].cx - s[0].cx, s[0].art);
	CHECK(fabs(bar.bar_x - 1140) < 1.5 && fabs(bar.bar_x + bar.bar_w - 2299.5) < 1.5, "the bar spans 1140 .. 2300");
	CHECK(fabs(s[0].cx - 1178.5) < 1.0 && fabs((s[1].cx - s[0].cx) - 62) < 0.01, "first tile centre and pitch");
	/* the second measurement was made with one more application in the Dock (a 17th): the pointer at 1488 then sits between tiles 5 and 6 */
	for (int i = 0; i < 17; i++) items[i].kind = DOCK_APP;
	items[17].kind = DOCK_SEPARATOR; items[18].kind = DOCK_OTHER; items[19].kind = DOCK_TRASH;
	dock_layout(&m, items, 20, 1488, s, &bar);
	for (int i = 2; i < 9; i++) printf("  tile %d: art %.0f (x %.0f .. %.0f) scale %.2f\n", i, s[i].art, s[i].cx - s[i].art / 2, s[i].cx + s[i].art / 2, s[i].scale);
	CHECK(fabs(s[5].scale - 1.67) < 0.06 && fabs(s[6].scale - 1.68) < 0.06, "the two tiles at the pointer are about 1.67");
	CHECK(fabs(s[4].scale - 1.48) < 0.1 && fabs(s[7].scale - 1.48) < 0.1, "their neighbours about 1.48");
	CHECK(fabs(s[3].scale - 1.24) < 0.12 && fabs(s[8].scale - 1.24) < 0.12, "then 1.31 and 1.17");
	printf("  first art left %.1f (measured 1045)\n", s[0].cx - s[0].art / 2);
	CHECK(fabs((s[0].cx - s[0].art / 2) - 1045) < 10, "the first icon starts near 1045");
	printf(failures ? "%d failure(s)\n" : "dock layout: ok\n", failures);
	return failures != 0;
}
