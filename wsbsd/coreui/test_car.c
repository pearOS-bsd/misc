/* the reader against what Apple's assetutil reports for the shipped Aqua.car: 10127 renditions, the menu material unpacks to a keyed archive */
#include "car.h"
#include <stdio.h>
#include <stdlib.h>
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
	puts("coreui: ok"); return 0;
}
