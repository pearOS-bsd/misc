/* the smallest Opal-into-wsd drawing: one fill, one flush, count the non-zero pixels in the shared buffer. Built twice by the QuartzCore job (with and without libQuartzCore/GL) to see what the extra libraries change. */
#import <CoreGraphics/CoreGraphics.h>
#include "ws_client.h"
#include <stdio.h>
int main(int argc, char **argv)
{
	int variant = argc > 1 ? argv[1][0] - '0' : 0;
	ws_conn *c = ws_connect(NULL); if (!c) return 1;
	enum { W = 560, H = 360 };
	ws_win w; ws_cbuf cb; uint32_t sid;
	if (ws_win_create(c, (ws_rect){ 100, 100, W, H }, 0, &w) || ws_cbuf_create(c, W, H, &cb) || ws_surface_add(c, &w, &sid) || ws_surface_bind_buffer(c, &w, sid, &cb)) return 1;
	ws_surface *px = cb.buf.cpu;
	CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
	CGContextRef g = CGBitmapContextCreate(px->px, W, H, 8, px->stride, rgb, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
	fprintf(stderr, "opal_min: context %p, buffer stride %zu (width*4 = %d)\n", (void *)g, (size_t)px->stride, W * 4);
	if (!g) return 2;
	if (variant == 0) { CGContextSetRGBFillColor(g, 0, 0.5, 1, 1); CGContextFillRect(g, CGRectMake(0, 0, 100, 100)); }                          /* one small rect */
	else if (variant == 1) { CGContextSetRGBFillColor(g, 0, 0.5, 1, 1); CGContextFillRect(g, CGRectMake(0, 0, W, H)); }                       /* the whole buffer */
	else if (variant == 2) { for (int y = 0; y < H; y++) { CGContextSetRGBFillColor(g, 0.1 + 0.25 * y / H, 0.16, 0.35, 1); CGContextFillRect(g, CGRectMake(0, y, W, 1)); } }   /* one-pixel bands, as opal_demo */
	else if (variant == 3) { CGContextSetRGBFillColor(g, 0, 0.5, 1, 1); CGContextBeginPath(g); CGContextAddRect(g, CGRectMake(0, 0, 200, 200)); CGContextFillPath(g); }   /* a path fill */
	else if (variant == 4) { CGContextSelectFont(g, "DejaVu Sans", 15, kCGEncodingMacRoman); CGContextSetRGBFillColor(g, 0, 0.5, 1, 1); CGContextFillRect(g, CGRectMake(0, 0, W, H)); }   /* a font selected first */
	else if (variant == 5) { CGContextSetRGBFillColor(g, 0, 0.5, 1, 1); CGContextFillRect(g, CGRectMake(0, 0, W, H)); CGContextSelectFont(g, "DejaVu Sans", 15, kCGEncodingMacRoman); CGContextSetRGBFillColor(g, 1, 1, 1, 1); CGContextShowTextAtPoint(g, 10, 10, "hi", 2); }
	else { CGContextSetRGBFillColor(g, 0, 0.5, 1, 1); CGContextBeginPath(g); CGContextAddArc(g, 120, 130, 70, 0, 6.28318, 0); CGContextClosePath(g); CGContextFillPath(g); }   /* an arc path as the demo draws */
	long nz0 = 0, nz1 = 0, nz2 = 0;
	#define COUNT(v) do { v = 0; for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) if (((uint32_t *)(px->px + y * px->stride))[x]) v++; } while (0)
	COUNT(nz0);                                  /* after drawing, before any flush */
	CGContextFlush(g); COUNT(nz1);               /* after CGContextFlush */
	CGContextRelease(g); COUNT(nz2);             /* after the context is released (a bitmap context may copy its pixels out then) */
	printf("opal_min variant %d: %ld non-zero pixels (before flush %ld, after flush %ld, after release %ld)\n", variant, nz2, nz0, nz1, nz2);
	return 0;
}
