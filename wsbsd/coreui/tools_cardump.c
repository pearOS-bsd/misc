/* cardump FILE [name]: lists the renditions of an asset catalogue (name, size, layout, state, value) or writes the data of one rendition to stdout */
#include "car.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
int main(int argc, char **argv)
{
	CarFile *c = argc > 1 ? car_open(argv[1]) : NULL; if (!c) { fprintf(stderr, "usage: cardump FILE [name [state]]\n"); return 1; }
	if (argc > 2) {
		CarRendition r; if (car_find(c, argv[2], argc > 3 ? atoi(argv[3]) : -1, -1, -1, &r)) { fprintf(stderr, "not found\n"); return 1; }
		size_t n; uint8_t *d = car_data(&r, &n); if (!d) { fprintf(stderr, "no data rendition (layout %d, payload %zu):", r.layout, r.payload_len); for (int i = 0; i < 28 && i < (int)r.payload_len; i++) fprintf(stderr, " %02x", r.payload[i]); fputc(10, stderr); return 1; }
		fwrite(d, 1, n, stdout); return 0;
	}
	for (int i = 0; i < car_count(c); i++) { CarRendition r; if (car_rendition(c, i, &r)) continue;
		printf("%-48s %4dx%-4d @%dx layout %d fmt %.4s state %d value %d appearance %d payload %zu\n", r.name, r.width, r.height, r.scale, r.layout, (const char *)&r.pixel_format, r.attr[CAR_STATE], r.attr[CAR_VALUE], r.attr[CAR_APPEARANCE], r.payload_len); if (getenv("CAR_ATTRS")) { printf("    attrs:"); for (int k = 1; k < 20; k++) if (r.attr[k] > 0) printf(" %d=%d", k, r.attr[k]); printf("\n"); } }
	return 0;
}
