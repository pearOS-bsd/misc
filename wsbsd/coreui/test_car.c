/* the reader against what Apple's assetutil reports for the shipped Aqua.car: 10127 renditions, the menu material unpacks to a keyed archive */
#include "car.h"
#include "bvg.h"
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#define CHECK(c) do { if (!(c)) { fprintf(stderr, "FAIL %s:%d: %s\n", __FILE__, __LINE__, #c); return 1; } } while (0)
int main(void)
{
	CarFile *aqua = car_open("coreui/assets/Aqua.car"), *dark = car_open("coreui/assets/DarkAqua.car");
	CHECK(aqua && dark);
	CHECK(car_count(aqua) == 10127);
	CHECK(car_count(dark) == 10097);
	CarRendition r; CHECK(car_find(aqua, "Mica: Menu.caar", -1, -1, -1, &r) == 0);
	CHECK(r.layout == 1000 && r.attr[CAR_ELEMENT] == 168);
	size_t n; uint8_t *d = car_data(&r, &n); CHECK(d && n > 1000 && !memcmp(d, "bplist00", 8)); free(d);
	CHECK(car_find(aqua, "Menu_MenuItemSeparator@2x.psd", -1, -1, 2, &r) == 0 && r.width == 12 && r.height == 2);
	CHECK(car_find(aqua, "no such rendition", -1, -1, -1, &r) != 0);
	car_close(aqua); car_close(dark);
	{	/* the vector glyphs: three symbols of CoreGlyphs (regular weight) as the catalogue stores them */
		const char *files[3] = { "coreui/assets/test/clock.bvg", "coreui/assets/test/house.bvg", "coreui/assets/test/person.2.bvg" }; int layers[3] = { 2, 1, 2 };
		for (int k = 0; k < 3; k++) {
			FILE *f = fopen(files[k], "rb"); CHECK(f); uint8_t buf[4096]; size_t len = fread(buf, 1, sizeof buf, f); fclose(f);
			BvgGlyph g; CHECK(bvg_parse(buf, len, &g) == 0); CHECK(g.nlayer >= layers[k]);
			double x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;                          /* the glyph lies inside its 20 point box */
			for (int i = 0; i < g.nseg; i++) { int np = g.seg[i].op == 'C' ? 3 : g.seg[i].op == 'Z' ? 0 : 1; for (int j = 0; j < np; j++) { double x = g.seg[i].p[2 * j], y = g.seg[i].p[2 * j + 1]; if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y; } }
			CHECK(x0 > -1 && x1 < 22 && y0 > -1 && y1 < 22 && x1 - x0 > 8 && y1 - y0 > 8);
			bvg_free(&g);
		}
		FILE *f = fopen("coreui/assets/test/clock.bvg", "rb"); uint8_t buf[4096]; size_t len = fread(buf, 1, sizeof buf, f); fclose(f);
		BvgGlyph g; CHECK(bvg_parse(buf, len, &g) == 0);                                  /* clock: the ring is a circle of radius ~4.8 around (5.7, 4.6) in the box ... */
		CHECK(g.seg[0].op == 'M' && fabs(g.seg[0].p[0] - (902 * 0.00634765 - 0.888671)) < 1e-3);
		bvg_free(&g);
	}
	{	/* Deepmap 2 bitmaps (vImage's codec: predictive, palette and lossless tiles) from the catalogue of the Mac's document icons: the pixels hash to what the decoder gave when it was checked against the picture */
		struct { const char *f; int w; unsigned long long h; } t[2] = { { "coreui/assets/test/dm2_256.mlec", 256, 0x29b3c78068d05cb4ull }, { "coreui/assets/test/dm2_512.mlec", 512, 0xaeae5f9d7f9afd37ull } };
		for (int k = 0; k < 2; k++) {
			FILE *f = fopen(t[k].f, "rb"); CHECK(f); static uint8_t buf[16384]; size_t len = fread(buf, 1, sizeof buf, f); fclose(f);
			CarRendition r; memset(&r, 0, sizeof r); r.payload = buf; r.payload_len = len; r.width = r.height = t[k].w; r.pixel_format = 0x41524742;
			int w, h, bpp; uint8_t *px = car_bitmap(&r, &w, &h, &bpp); CHECK(px && w == t[k].w && h == t[k].w && bpp == 4);
			unsigned long long hash = 1469598103934665603ull; for (size_t i = 0; i < (size_t)w * h * 4; i++) { hash ^= px[i]; hash *= 1099511628211ull; }
			CHECK(hash == t[k].h); free(px);
		}
	}
	puts("coreui: ok"); return 0;
}
