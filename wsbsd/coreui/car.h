/* A reader for the asset catalogues of macOS (.car files, as CoreUI reads them): a BOM store with a tree of renditions. This is the part of CoreUI that finds the pieces of the system's appearance (Aqua.car, DarkAqua.car) by name and state and hands their bytes out;
 * data renditions (Core Animation archives of the materials) are unpacked here, the images are decoded by caimg.c. */
#ifndef WSBSD_CAR_H
#define WSBSD_CAR_H
#include <stddef.h>
#include <stdint.h>

/* the attributes of a rendition's key (KEYFORMAT identifiers) */
enum { CAR_ELEMENT = 1, CAR_PART = 2, CAR_SIZE = 3, CAR_DIRECTION = 4, CAR_VALUE = 6, CAR_APPEARANCE = 7, CAR_DIM1 = 8, CAR_DIM2 = 9, CAR_STATE = 10, CAR_LAYER = 11, CAR_SCALE = 12,
	CAR_PRESENTATION = 14, CAR_IDIOM = 15, CAR_SUBTYPE = 16, CAR_IDENTIFIER = 17, CAR_PREVVALUE = 18, CAR_PREVSTATE = 19 };

typedef struct CarFile CarFile;
typedef struct {
	const char *name;             /* the rendition's name: "Menu_MenuBackground.psd", "Mica: Menu.caar" */
	int width, height;            /* in pixels (images) */
	int scale;                    /* 1, 2 or 3 */
	uint32_t pixel_format;        /* 'BGRA', 'GA8 ', ... as the four bytes of the file read little-endian */
	uint16_t layout;              /* the kind: 10 .. 12 images, 1000 + something for data, 1007 packed ... */
	int attr[32];                 /* the key's attributes by identifier, -1 when the key has none */
	const uint8_t *csi;           /* the rendition's whole CSI record */
	size_t csi_len;
	const uint8_t *tlv; size_t tlv_len;      /* the info list: (tag, length, bytes) triples */
	const uint8_t *payload; size_t payload_len;
} CarRendition;

CarFile *car_open(const char *path);
void car_close(CarFile *);
int car_count(const CarFile *);
int car_rendition(const CarFile *, int i, CarRendition *out);                                  /* 0 ok */
/* the first rendition called `name` whose key matches the given attributes (-1 = do not care) */
int car_find(const CarFile *, const char *name, int state, int value, int scale, CarRendition *out);
/* the TLV of the info list with this tag (1001 slices, 1003 metrics, 1010 internal link ...), or NULL */
const uint8_t *car_tlv(const CarRendition *, uint32_t tag, size_t *len);
/* the contents of a data rendition ("RAWD" blocks): malloc'ed, *len bytes; NULL when the rendition is no data rendition */
uint8_t *car_data(const CarRendition *, size_t *len);
/* the "BVG " containers (see bvg.h) of the symbols `names` (without ".svg") at the weight (1..9, 4 = regular): out[k] malloc'ed or NULL; returns how many were found. One pass over the catalogue for all of them */
int car_symbols(const CarFile *, const char *const *names, int n, int weight, uint8_t **out, size_t *outlen);
/* the pixels of a bitmap rendition (compression 4 LZFSE, 11 Deepmap 2): malloc'ed rows of *bpp bytes (4: the catalogue's BGRA / the codec's RGBA, 2: gray + alpha), or NULL */
uint8_t *car_bitmap(const CarRendition *, int *w, int *h, int *bpp);
#endif
