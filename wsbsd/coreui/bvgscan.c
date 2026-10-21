#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "car.h"
#include "bvg.h"
int main(int argc, char **argv)
{
	CarFile *c = car_open(argv[1]); int n = car_count(c); int tally[256][2]; memset(tally, 0, sizeof tally); int shown = 0;
	for (int i = 0; i < n; i++) {
		CarRendition r; if (car_rendition(c, i, &r)) continue;
		size_t len; uint8_t *d = car_data(&r, &len); if (!d) continue;
		if (len >= 16 && !memcmp(d, "BVG ", 4)) {
			BvgGlyph g; int rc = bvg_parse(d, len, &g); tally[d[5]][rc ? 1 : 0]++; if (!rc) bvg_free(&g);
			if (rc && shown < 12) { shown++; printf("fail %s ver %02x/%02x\n", r.name, d[4], d[5]); }
		}
		free(d);
	}
	for (int v = 0; v < 256; v++) if (tally[v][0] + tally[v][1]) printf("ver %02x: ok %d fail %d\n", v, tally[v][0], tally[v][1]);
	return 0;
}
