/* The vector glyphs of the system (the SF Symbols of CoreGlyphs.bundle, stored in "BVG " containers inside data renditions of an Assets.car), decoded the way CoreUI's CSIBVGPathDecoder does:
 * a nibble stream of commands (SVG commands, one byte each) and numbers (small integers, packed integer pairs or decimal floats). The result is a list of absolute segments (move, line, cubic, close)
 * already transformed by the glyph's matrix: 1 unit = 1 point at the symbol's design size (the glyph is about 20 units tall, y down). */
#ifndef WSBSD_BVG_H
#define WSBSD_BVG_H
#include <stddef.h>
#include <stdint.h>

typedef struct { char op; double p[6]; } BvgSeg;               /* 'M' p[0..1]; 'L' p[0..1]; 'C' p[0..5]; 'Z' */
typedef struct { int first, count; double opacity; } BvgLayer;  /* a run of segments painted with one opacity (1 for plain glyphs, 0.68 / 0.34 for the arcs of wifi ...) */
typedef struct { double m[6]; BvgSeg *seg; int nseg; BvgLayer *layer; int nlayer; } BvgGlyph;

int bvg_parse(const uint8_t *bvg, size_t len, BvgGlyph *g);     /* 0 ok */
void bvg_free(BvgGlyph *g);
#endif
