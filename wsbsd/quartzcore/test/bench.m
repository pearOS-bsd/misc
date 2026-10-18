/* Benchmarks of the Core Animation implementation: animation evaluation, presentation trees, and the software compositor on typical desktop scenes. */
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <QuartzCore/CAWsbsd.h>
#include <stdio.h>
#include <string.h>

static double now(void) { return CACurrentMediaTime(); }
static CGColorRef col(double r, double g, double b, double a) { CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB(); CGFloat v[4] = { r, g, b, a }; CGColorRef c = CGColorCreate(cs, v); CGColorSpaceRelease(cs); return c; }
static CALayer *box(CGRect f, CGColorRef c) { CALayer *l = [CALayer layer]; l.frame = f; l.backgroundColor = c; return l; }

/* a desktop: a wallpaper, a menu bar, windows with shadows, rounded corners, a translucent dock */
static CALayer *desktop(int W, int H, int windows)
{
	CALayer *root = box(CGRectMake(0, 0, W, H), col(0.15, 0.2, 0.35, 1));
	for (int i = 0; i < windows; i++) {
		CALayer *w = box(CGRectMake(60 + i * 70, 80 + i * 40, 520, 340), col(0.95, 0.95, 0.96, 1));
		w.cornerRadius = 12; w.shadowOpacity = 0.4; w.shadowRadius = 20; w.shadowOffset = CGSizeMake(0, -10);
		CALayer *title = box(CGRectMake(0, 310, 520, 30), col(0.85, 0.85, 0.87, 1)); [w addSublayer:title];
		for (int k = 0; k < 6; k++) [w addSublayer:box(CGRectMake(20 + (k % 3) * 160, 30 + (k / 3) * 120, 140, 100), col(0.3 + 0.1 * k, 0.5, 0.8 - 0.1 * k, 1))];
		[root addSublayer:w];
	}
	CALayer *dock = box(CGRectMake(W / 2 - 250, 10, 500, 70), col(1, 1, 1, 0.3)); dock.cornerRadius = 20; [root addSublayer:dock];
	return root;
}

int main(void)
{
	@autoreleasepool {
		printf("== Core Animation benchmarks ==\n");
		/* 1. animation evaluation */
		{
			CABasicAnimation *a = [CABasicAnimation animationWithKeyPath:@"opacity"]; a.fromValue = @0; a.toValue = @1; a.duration = 1; a.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
			CASpringAnimation *s = [CASpringAnimation animationWithKeyPath:@"opacity"]; s.fromValue = @0; s.toValue = @1; s.duration = 1.5;
			int N = 200000; double t0 = now();
			for (int i = 0; i < N; i++) (void)CABasicAnimationValueAtTime(a, (i % 1000) / 1000.0);
			double d1 = now() - t0; t0 = now();
			for (int i = 0; i < N; i++) (void)CABasicAnimationValueAtTime(s, (i % 1000) / 700.0);
			double d2 = now() - t0;
			printf("basic animation (ease in/out) applied:  %8.0f /s  (%.2f us each)\n", N / d1, d1 / N * 1e6);
			printf("spring animation applied:               %8.0f /s  (%.2f us each)\n", N / d2, d2 / N * 1e6);
		}
		/* 2. layers and presentation trees */
		{
			int N = 2000; CALayer *root = [CALayer layer]; root.frame = CGRectMake(0, 0, 1000, 1000);
			double t0 = now();
			for (int i = 0; i < N; i++) { CALayer *l = [CALayer layer]; l.frame = CGRectMake(i % 50 * 20, i / 50 * 20, 18, 18); [root addSublayer:l]; }
			double d = now() - t0;
			printf("layers created and added:               %8.0f /s\n", N / d);
			CABasicAnimation *a = [CABasicAnimation animationWithKeyPath:@"opacity"]; a.fromValue = @0; a.toValue = @1; a.duration = 1;
			for (CALayer *l in root.sublayers) [l addAnimation:a forKey:@"o"];
			CARenderer *r = [CARenderer rendererWithBitmap:calloc(16, 4) width:2 height:2 bytesPerRow:8 options:nil]; r.layer = root; [CATransaction flush];
			t0 = now(); for (int i = 0; i < 20; i++) { CALayer *t = [root presentationLayer]; (void)t; [CATransaction flush]; }
			printf("presentation of %d animated layers:   %8.2f ms per frame\n", N, (now() - t0) / 20 * 1000);
		}
		/* 3. the compositor */
		struct { const char *name; int W, H, windows; } sc[] = { { "1280x800, 3 windows", 1280, 800, 3 }, { "1920x1080, 3 windows", 1920, 1080, 3 }, { "1920x1080, 6 windows", 1920, 1080, 6 } };
		for (size_t i = 0; i < sizeof sc / sizeof sc[0]; i++) {
			int W = sc[i].W, H = sc[i].H; uint8_t *buf = calloc(W * H, 4);
			CARenderer *r = [CARenderer rendererWithBitmap:buf width:W height:H bytesPerRow:W * 4 options:nil];
			CALayer *root = desktop(W, H, sc[i].windows); r.layer = root; r.bounds = CGRectMake(0, 0, W, H); [CATransaction flush];
			[r beginFrameAtTime:CACurrentMediaTime() timeStamp:NULL]; [r render];
			int N = getenv("BENCH_FRAMES") ? atoi(getenv("BENCH_FRAMES")) : 8; double t0 = now();
			for (int k = 0; k < N; k++) { [r beginFrameAtTime:CACurrentMediaTime() timeStamp:NULL]; memset(buf, 0, (size_t)W * H * 4); [r render]; }
			double d = (now() - t0) / N;
			printf("compositor %-24s %8.1f ms per frame  (%5.1f fps)\n", sc[i].name, d * 1000, 1.0 / d);
			free(buf);
		}
	}
	return 0;
}
