/* Reader for Apple icon files (.icns): picks the entry that fits a pixel size best and returns it as an image (PNG data or decoded legacy RGBA). */
#ifndef WSBSD_ICNS_H
#define WSBSD_ICNS_H
#include <stddef.h>
#include <stdint.h>

typedef struct {
	int px;                       /* pixel width of the entry */
	const uint8_t *png; size_t png_len;      /* PNG (or JPEG 2000 when jp2 != 0) data, NULL for a legacy entry */
	int jp2;
	uint8_t *rgba;                /* legacy entry decoded to px*px*4 (straight alpha), caller frees; NULL for PNG */
} IcnsPick;

/* the entry with the smallest size >= want_px (else the largest one); returns 0 when the file has no usable image */
int icns_pick(const uint8_t *file, size_t len, int want_px, IcnsPick *out);
/* PackBits-like run-length decoding of the "is32/il32/ih32/it32" channels: n bytes of out per channel plane */
int icns_unpack(const uint8_t *src, size_t srclen, uint8_t *dst, size_t n);
#endif
