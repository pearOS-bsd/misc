/* the smallest Opal-into-wsd drawing: one fill, one flush, count the non-zero pixels in the shared buffer. Built twice by the QuartzCore job (with and without libQuartzCore/GL) to see what the extra libraries change. */
#import <CoreGraphics/CoreGraphics.h>
#include "ws_client.h"
#include <stdio.h>
int main(int argc, char **argv)
{
	int variant = argc > 1 ? argv[1][0] - '0' : 0;
	ws_conn *c = ws_connect(NULL); if (!c) return 1;
	enum { W = 520, H = 360 };
	ws_win w; ws_cbuf cb; uint32_t sid;
	if (ws_win_create(c, (ws_rect){ 100, 100, W, H }, 0, &w) || ws_cbuf_create(c, W, H, &cb) || ws_surface_add(c, &w, &sid) || ws_surface_bind_buffer(c, &w, sid, &cb)) return 1;
	ws_surface *px = cb.buf.cpu;
	CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
	CGContextRef g = CGBitmapContextCreate(px->px, W, H, 8, px->stride, rgb, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
	if (variant == 0) { CGContextSetRGBFillColor(g, 0, 0.5, 1, 1); CGContextFillRect(g, CGRectMake(0, 0, 100, 100)); }                          /* one small rect */
	else if (variant == 1) { CGContextSetRGBFillColor(g, 0, 0.5, 1, 1); CGContextFillRect(g, CGRectMake(0, 0, W, H)); }                       /* the whole buffer */
	else if (variant == 2) { for (int y = 0; y < H; y++) { CGContextSetRGBFillColor(g, 0.1 + 0.25 * y / H, 0.16, 0.35, 1); CGContextFillRect(g, CGRectMake(0, y, W, 1)); } }   /* one-pixel bands, as opal_demo */
	else { CGContextSetRGBFillColor(g, 0, 0.5, 1, 1); CGContextBeginPath(g); CGContextAddRect(g, CGRectMake(0, 0, 200, 200)); CGContextFillPath(g); }   /* a path fill */
	CGContextFlush(g);
	long nz = 0; for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) if (((uint32_t *)(px->px + y * px->stride))[x]) nz++;
	printf("opal_min variant %d: %ld non-zero pixels\n", variant, nz);
	return 0;
}
