/* SkyLight region serialisation (y-banded rectangle list). Format: docs/SPEC-SLS-WIRE.md section 5. */
#ifndef WS_REGION_H
#define WS_REGION_H
#include "ws.h"
#define WS_REGION_MAX_RECTS 4096
/* 0 on success. rects (malloc'd, may be NULL when the region is empty) and bounds are filled in; negative on a malformed region. */
int ws_region_parse(const uint8_t *b, uint32_t len, ws_rect **rects, int *nrects, ws_rect *bounds);
/* Serialises the union of the rectangles. Returns the byte count, or 0 if the buffer is too small. */
size_t ws_region_serialize(const ws_rect *r, int n, uint8_t *out, size_t cap);
#endif
