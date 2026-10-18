/* The software rasterizer of the layer compositor: premultiplied BGRA surfaces, shapes with analytic coverage, textured quads under a 4x4 matrix, blurs. */
#ifndef WSBSD_CARASTER_H
#define WSBSD_CARASTER_H
#include <stdint.h>
#include <stddef.h>

typedef struct { int w, h, stride; uint8_t *px; int owns; } RSurf;             /* BGRA, premultiplied alpha */
typedef struct { double m[16]; } RMat;                                          /* row-vector convention as CATransform3D: p' = p * m */
typedef struct { float r, g, b, a; } RColor;                                    /* premultiplied */
typedef struct { double x, y, w, h; } RRect;

/* a clip: a rectangle in pixels and an optional 8-bit coverage mask of the whole surface */
typedef struct RClip { int x0, y0, x1, y1; const uint8_t *mask; int mstride; } RClip;

/* the shape drawn: a rounded rectangle in layer coordinates, radii per corner (minX-minY, maxX-minY, maxX-maxY, minX-maxY), continuous or circular corners */
typedef struct { RRect r; double rad[4]; int continuous; } RShape;

RSurf RSurfCreate(int w, int h);
void RSurfFree(RSurf *s);
void RSurfClear(RSurf *s);
void RSurfWrap(RSurf *s, uint8_t *px, int w, int h, int stride);

RMat RMatIdentity(void);
RMat RMatMul(RMat a, RMat b);                                                    /* a first, then b */
RMat RMatInvert(RMat a, int *ok);

/* fills the shape (layer coordinates) mapped by m onto dest with the premultiplied colour (a gradient/texture would use FillTexture) */
void RFillShape(RSurf *dest, const RClip *clip, RMat m, const RShape *shape, RColor c, int backface);
/* fills the ring between the shape and the shape inset by `width` */
void RStrokeShape(RSurf *dest, const RClip *clip, RMat m, const RShape *shape, double width, RColor c);
/* draws an image (premultiplied BGRA) onto the rectangle `dst` (layer coordinates) taking the part `src` (pixels of the image); `region` limits the coverage to a shape */
void RDrawImage(RSurf *dest, const RClip *clip, RMat m, const RSurf *img, RRect src, RRect dst, const RShape *region, float opacity, int nearest);
/* composites src over dest at (x, y) with an alpha factor and an optional mask surface of the same size as src (8 bit) */
void RComposite(RSurf *dest, const RSurf *src, int x, int y, float alpha, const RClip *clip);
/* the alpha channel of src, blurred (gaussian sigma in pixels), offset and tinted into a shadow surface; result is the same size as src */
void RShadowFromAlpha(RSurf *out, const RSurf *src, double sigma, RColor tint);
void RBlur(RSurf *s, double sigma);
void RBlurNormalized(RSurf *s, double sigma);

#endif
