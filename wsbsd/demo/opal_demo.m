/* CoreGraphics (Opal, GNUstep's implementation over Cairo) drawing into a window of wsd: the window's pixels are a shared buffer registered with the server,
 * a CGBitmapContext is created over that memory, vector shapes, text with anti-aliasing and an image are drawn, then the surface is flushed. */
#import <CoreGraphics/CoreGraphics.h>
#include "ws_client.h"
#include <stdio.h>
#include <math.h>

/* a push button drawn with CoreGraphics: rounded look made of two rectangles and a label; pressed state is green */
static void draw_button(CGContextRef g, CGRect r, int pressed)
{
	CGContextSetRGBFillColor(g, pressed ? 0.20 : 0.00, pressed ? 0.78 : 0.48, pressed ? 0.35 : 1.0, 1);
	CGContextFillRect(g, r);
	CGContextSetRGBFillColor(g, 1, 1, 1, 0.25);
	CGContextFillRect(g, CGRectMake(r.origin.x, r.origin.y + r.size.height - 3, r.size.width, 3));
	CGContextSetRGBFillColor(g, 1, 1, 1, 1);
	CGContextSelectFont(g, "DejaVu Sans", 15, kCGEncodingMacRoman);
	const char *label = pressed ? "Clicked!" : "Click me";
	CGContextShowTextAtPoint(g, r.origin.x + 16, r.origin.y + 11, label, strlen(label));
}

int main(int argc, char **argv)
{
	const char *out = argc > 1 ? argv[1] : "opal.ppm";
	ws_conn *c = ws_connect(NULL);
	if (!c) { fprintf(stderr, "opal_demo: cannot connect to wsd\n"); return 1; }
	enum { W = 560, H = 360 };
	ws_win w; ws_cbuf cb; uint32_t sid;
	if (ws_win_create(c, (ws_rect){ 120, 100, W, H }, 0, &w) || ws_cbuf_create(c, W, H, &cb) || ws_surface_add(c, &w, &sid) || ws_surface_bind_buffer(c, &w, sid, &cb)) { fprintf(stderr, "opal_demo: window setup failed\n"); return 1; }
	ws_surface *px = cb.buf.cpu;
	CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
	/* premultiplied BGRA in memory: what kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little means */
	CGContextRef g = CGBitmapContextCreate(px->px, W, H, 8, px->stride, rgb, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
	if (!g) { fprintf(stderr, "opal_demo: CGBitmapContextCreate failed\n"); return 1; }
	/* background: a vertical gradient drawn as bands */
	for (int y = 0; y < H; y++) { CGFloat t = (CGFloat)y / H; CGContextSetRGBFillColor(g, 0.10 + 0.25 * t, 0.16 + 0.20 * t, 0.35 + 0.30 * t, 1); CGContextFillRect(g, CGRectMake(0, y, W, 1)); }
	/* a filled circle (arc path) and a stroked star */
	CGContextSetRGBFillColor(g, 1.0, 0.62, 0.15, 1);
	CGContextBeginPath(g); CGContextAddArc(g, 120, 130, 70, 0, 2 * M_PI, 0); CGContextClosePath(g); CGContextFillPath(g);
	CGContextSetRGBStrokeColor(g, 1, 1, 1, 0.95); CGContextSetLineWidth(g, 4);
	CGContextBeginPath(g);
	for (int i = 0; i < 5; i++) { double a = -M_PI / 2 + i * 4 * M_PI / 5; double x = 330 + 80 * cos(a), y = 130 + 80 * sin(a); if (i == 0) CGContextMoveToPoint(g, x, y); else CGContextAddLineToPoint(g, x, y); }
	CGContextClosePath(g); CGContextStrokePath(g);
	/* a rounded translucent panel with a clip */
	CGContextSaveGState(g);
	CGContextSetRGBFillColor(g, 1, 1, 1, 0.22);
	CGContextBeginPath(g); CGContextAddRect(g, CGRectMake(30, 230, 500, 100)); CGContextFillPath(g);
	CGContextRestoreGState(g);
	/* text */
	CGContextSetRGBFillColor(g, 1, 1, 1, 1);
	CGContextSelectFont(g, "DejaVu Sans", 28, kCGEncodingMacRoman);
	CGContextSetTextDrawingMode(g, kCGTextFill);
	const char *line1 = "wsbsd: Quartz 2D on FreeBSD";
	CGContextShowTextAtPoint(g, 48, 90 + 200, line1, strlen(line1));
	CGContextSelectFont(g, "DejaVu Sans", 16, kCGEncodingMacRoman);
	const char *line2 = "CoreGraphics (Opal/Cairo) into a wsd window";
	CGContextShowTextAtPoint(g, 48, 66 + 200, line2, strlen(line2));
	/* an image made from a bitmap, drawn scaled */
	{
		uint32_t tile[16 * 16];
		for (int y = 0; y < 16; y++) for (int x = 0; x < 16; x++) tile[y * 16 + x] = ((x ^ y) & 4) ? 0xff2b8cff : 0xffffffff;      /* BGRA premultiplied, opaque */
		CGContextRef tc = CGBitmapContextCreate(tile, 16, 16, 8, 64, rgb, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
		CGImageRef img = tc ? CGBitmapContextCreateImage(tc) : NULL;
		if (img) { CGContextDrawImage(g, CGRectMake(430, 40, 96, 96), img); CGImageRelease(img); }
		if (tc) CGContextRelease(tc);
	}
	draw_button(g, CGRectMake(30, 20, 120, 34), 0);
	CGContextFlush(g);
	fprintf(stderr, "opal_demo: ctx data %p (ours %p), pixel(10,10)=%08x pixel(120,130)=%08x\n", CGBitmapContextGetData(g), px->px, ((uint32_t *)px->px)[10 * (px->stride / 4) + 10], ((uint32_t *)px->px)[130 * (px->stride / 4) + 120]);
	ws_rect all = { 0, 0, W, H };
	if (ws_surface_flush(c, &w, sid, &all)) { fprintf(stderr, "opal_demo: flush failed\n"); return 1; }
	ws_win_shadow(c, &w, 12, 1);
	ws_win_order(c, &w, WS_ABOVE, 0);
	if (ws_screenshot(c, out)) { fprintf(stderr, "opal_demo: screenshot failed\n"); return 1; }
	printf("wrote %s\n", out);
	/* interaction: a click (PostEventRecord) on the button reaches the window, the app redraws only the button with CoreGraphics and flushes only its rectangle */
	{
		ws_win_set_event_mask(c, &w, -1);
		ws_post_mouse_event(c, 5, 120 + 90, 100 + 323, 0, 0, 0);
		ws_post_mouse_event(c, 1, 120 + 90, 100 + 323, 0, 1, 0);
		ws_event e; int got = 0;
		for (int i = 0; i < 20 && ws_conn_next_pushed_event(c, 300, &e); i++) if (e.type == WS_EV_MOUSE_DOWN) { got = 1; break; }
		ws_post_mouse_event(c, 2, 120 + 90, 100 + 323, 0, 1, 0);
		if (got && e.x >= 30 && e.x < 150 && e.y >= H - 54 && e.y < H - 20) {
			draw_button(g, CGRectMake(30, 20, 120, 34), 1);
			CGContextSetRGBFillColor(g, 1, 0, 0, 1); CGContextFillRect(g, CGRectMake(200, 20, 40, 40));           /* experiment: does any new drawing land? */
			fprintf(stderr, "opal_demo: before flush pixel(60,323)=%08x pixel(220,320)=%08x\n", ((uint32_t *)px->px)[323 * (px->stride / 4) + 60], ((uint32_t *)px->px)[320 * (px->stride / 4) + 220]);
			CGContextFlush(g);
			fprintf(stderr, "opal_demo: after flush pixel(220,320)=%08x\n", ((uint32_t *)px->px)[320 * (px->stride / 4) + 220]);
			ws_rect btn = { 30, H - 54, 120, 34 };
			int frc = ws_surface_flush(c, &w, sid, &btn);
			fprintf(stderr, "opal_demo: pressed pixel(60,323)=%08x flush rc=%d\n", ((uint32_t *)px->px)[323 * (px->stride / 4) + 60], frc);
		}
		char out2[256]; snprintf(out2, sizeof out2, "%s-click.ppm", out);
		ws_screenshot_scene(c, out2);
		printf("click %s at local (%d,%d), wrote %s\n", got ? "delivered" : "MISSING", got ? e.x : -1, got ? e.y : -1, out2);
	}
	CGContextRelease(g); CGColorSpaceRelease(rgb);
	ws_server_quit(c);
	return 0;
}
