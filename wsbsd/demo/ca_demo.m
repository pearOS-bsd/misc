/* Core Animation (GNUstep QuartzCore: CALayer tree, implicit and explicit animations) over wsd.
 * GNUstep's CARenderer needs OpenGL; this demo uses a small software renderer instead: every frame it refreshes the presentation layers the way CARenderer does
 * (discard, then applyAnimationsAtTime:), walks them, and draws with CoreGraphics (Opal) into the window's shared buffer, which is then flushed to wsd. */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <QuartzCore/QuartzCore.h>
#include "ws_client.h"
#include <stdio.h>
#include <math.h>
#include <unistd.h>

/* the framework-private calls CARenderer itself makes */
@interface CALayer (WsdPrivate)
+ (void) setCurrentFrameBeginTime: (CFTimeInterval)t;
- (void) discardPresentationLayer;
- (CFTimeInterval) applyAnimationsAtTime: (CFTimeInterval)t;
@end

static void update_layer(CALayer *layer, CFTimeInterval t)
{
	[CALayer setCurrentFrameBeginTime: t];
	[layer discardPresentationLayer];
	[[layer presentationLayer] applyAnimationsAtTime: t];
	for (CALayer *s in [layer sublayers]) update_layer(s, t);
}

static void draw_layer(CALayer *l, CGContextRef g, float parent_alpha)
{
	if ([l isHidden]) return;
	CGContextSaveGState(g);
	CGPoint pos = [l position], ap = [l anchorPoint]; CGRect b = [l bounds];
	CATransform3D t = [l transform];
	CGContextTranslateCTM(g, pos.x, pos.y);
	CGContextConcatCTM(g, CGAffineTransformMake(t.m11, t.m12, t.m21, t.m22, t.m41, t.m42));
	CGContextTranslateCTM(g, -ap.x * b.size.width, -ap.y * b.size.height);
	float alpha = parent_alpha * [l opacity];
	CGContextSetAlpha(g, alpha);
	CGRect local = CGRectMake(0, 0, b.size.width, b.size.height);
	if ([l shadowOpacity] > 0) {                                  /* a hard offset shadow (the real renderer blurs it) */
		CGContextSaveGState(g);
		CGContextSetRGBFillColor(g, 0, 0, 0, 0.35 * alpha * [l shadowOpacity]);
		CGSize so = [l shadowOffset];
		CGContextFillRect(g, CGRectOffset(local, so.width, so.height));
		CGContextRestoreGState(g);
	}
	if ([l backgroundColor]) { CGContextSetFillColorWithColor(g, [l backgroundColor]); CGContextFillRect(g, local); }
	if ([l borderWidth] > 0 && [l borderColor]) { CGContextSetStrokeColorWithColor(g, [l borderColor]); CGContextSetLineWidth(g, [l borderWidth]); CGContextStrokeRect(g, local); }
	if ([l masksToBounds]) CGContextClipToRect(g, local);
	CATransform3D st = [l sublayerTransform];
	CGContextTranslateCTM(g, -b.origin.x, -b.origin.y);
	CGContextConcatCTM(g, CGAffineTransformMake(st.m11, st.m12, st.m21, st.m22, st.m41, st.m42));
	for (CALayer *s in [l sublayers]) draw_layer(s, g, alpha);
	CGContextRestoreGState(g);
}

static CGColorRef rgba(CGColorSpaceRef cs, CGFloat r, CGFloat g, CGFloat b, CGFloat a) { CGFloat c[4] = { r, g, b, a }; return CGColorCreate(cs, c); }

int main(int argc, char **argv)
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	const char *out = argc > 1 ? argv[1] : "ca";
	ws_conn *c = ws_connect(NULL);
	if (!c) { fprintf(stderr, "ca_demo: cannot connect to wsd\n"); return 1; }
	enum { W = 520, H = 360 };
	ws_win w; ws_cbuf cb; uint32_t sid;
	if (ws_win_create(c, (ws_rect){ 100, 100, W, H }, 0, &w) || ws_cbuf_create(c, W, H, &cb) || ws_surface_add(c, &w, &sid) || ws_surface_bind_buffer(c, &w, sid, &cb)) { fprintf(stderr, "ca_demo: window setup failed\n"); return 1; }
	ws_win_order(c, &w, 1, 0);
	ws_surface *px = cb.buf.cpu;
	CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
	CGContextRef g = CGBitmapContextCreate(px->px, W, H, 8, px->stride, rgb, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
	if (!g) { fprintf(stderr, "ca_demo: CGBitmapContextCreate failed\n"); return 1; }

	/* the layer tree */
	CALayer *root = [CALayer layer];
	[root setBounds: CGRectMake(0, 0, W, H)]; [root setPosition: CGPointMake(W / 2, H / 2)];
	[root setBackgroundColor: rgba(rgb, 0.12, 0.16, 0.30, 1)];
	CALayer *panel = [CALayer layer];
	[panel setBounds: CGRectMake(0, 0, 440, 140)]; [panel setPosition: CGPointMake(W / 2, 90)];
	[panel setBackgroundColor: rgba(rgb, 1, 1, 1, 0.20)]; [panel setBorderWidth: 2]; [panel setBorderColor: rgba(rgb, 1, 1, 1, 0.8)];
	[root addSublayer: panel];
	CALayer *box = [CALayer layer];
	[box setBounds: CGRectMake(0, 0, 80, 80)]; [box setPosition: CGPointMake(70, 250)];
	[box setBackgroundColor: rgba(rgb, 1.0, 0.55, 0.12, 1)]; [box setShadowOpacity: 1]; [box setShadowOffset: CGSizeMake(6, -6)];
	[root addSublayer: box];
	CALayer *spin = [CALayer layer];
	[spin setBounds: CGRectMake(0, 0, 70, 70)]; [spin setPosition: CGPointMake(W / 2, 250)];
	[spin setBackgroundColor: rgba(rgb, 0.25, 0.85, 0.45, 1)];
	[spin setTransform: CATransform3DMakeRotation(M_PI / 4, 0, 0, 1)];
	[root addSublayer: spin];
	for (int i = 0; i < 3; i++) {
		CALayer *dot = [CALayer layer]; [dot setBounds: CGRectMake(0, 0, 40, 40)]; [dot setPosition: CGPointMake(120 + 140 * i, 90)];
		[dot setBackgroundColor: rgba(rgb, i == 0 ? 1 : 0.3, i == 1 ? 1 : 0.4, i == 2 ? 1 : 0.5, 1)]; [panel addSublayer: dot];
	}
	/* an explicit animation: the box moves across the window and fades */
	CFTimeInterval start = CACurrentMediaTime();
	CABasicAnimation *move = [CABasicAnimation animationWithKeyPath: @"position"];
	[move setFromValue: [NSValue valueWithPoint: NSMakePoint(70, 250)]]; [move setToValue: [NSValue valueWithPoint: NSMakePoint(450, 250)]]; [move setDuration: 1.0];
	[box setPosition: CGPointMake(450, 250)];
	[box addAnimation: move forKey: @"move"];
	CABasicAnimation *fade = [CABasicAnimation animationWithKeyPath: @"opacity"];
	[fade setFromValue: [NSNumber numberWithFloat: 1.0]]; [fade setToValue: [NSNumber numberWithFloat: 0.35]]; [fade setDuration: 1.0];
	[box setOpacity: 0.35];
	[box addAnimation: fade forKey: @"fade"];
	[CATransaction flush];

	int shots = 0;
	for (int frame = 0; frame < 40; frame++) {
		CFTimeInterval now = CACurrentMediaTime();
		update_layer(root, now);
		CGContextClearRect(g, CGRectMake(0, 0, W, H));
		draw_layer([root presentationLayer], g, 1.0f);
		ws_surface_flush(c, &w, sid, NULL);
		double el = now - start;
		if (shots == 0 && el > 0.25) { char p[256]; snprintf(p, sizeof p, "%s-a.ppm", out); ws_screenshot_scene(c, p); shots = 1; printf("frame at %.2fs\n", el); }
		if (shots == 1 && el > 1.2) { char p[256]; snprintf(p, sizeof p, "%s-b.ppm", out); ws_screenshot_scene(c, p); shots = 2; printf("frame at %.2fs\n", el); break; }
		usleep(40000);
	}
	printf("ca_demo: %d screenshots\n", shots);
	ws_disconnect(c);
	[pool release];
	return shots == 2 ? 0 : 1;
}
