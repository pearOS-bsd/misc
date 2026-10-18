/* Scenes rendered by the real QuartzCore (CARenderer into a Metal texture) and by this implementation; the images are compared. */
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#ifdef REAL_CA
#import <Metal/Metal.h>
#endif
#ifdef __APPLE__
#import <AppKit/AppKit.h>
#endif
#ifdef REAL_CA
@interface CAFilter : NSObject
+ (instancetype)filterWithType:(NSString *)type;
@end
#endif
static id FILTER(NSString *type, NSString *key, id value) { CAFilter *f = [CAFilter filterWithType:type]; if (key) [f setValue:value forKey:key]; return f; }
#define W 400
#define H 300
static CGColorRef RGB(double r, double g, double b, double a) { return CGColorCreateGenericRGB(r, g, b, a); }
static CALayer *box(CGRect f, CGColorRef c) { CALayer *l = [CALayer layer]; l.frame = f; l.backgroundColor = c; return l; }
static CALayer *rootLayer(void) { return box(CGRectMake(0, 0, W, H), RGB(0.3, 0.35, 0.45, 1)); }

typedef CALayer *(*SceneFn)(void);
static CALayer *s_solid(void) { CALayer *r = rootLayer(); [r addSublayer:box(CGRectMake(40, 40, 120, 80), RGB(1, 0, 0, 1))]; [r addSublayer:box(CGRectMake(100.5, 90.25, 100, 60), RGB(0, 1, 0, 0.5))]; return r; }
static CALayer *s_rounded(void) { CALayer *r = rootLayer(); CALayer *a = box(CGRectMake(50, 50, 120, 80), RGB(1, 0, 0, 1)); a.cornerRadius = 20; a.borderWidth = 4; a.borderColor = RGB(1, 1, 1, 1); [r addSublayer:a];
	CALayer *b = box(CGRectMake(220, 50, 120, 120), RGB(0, 0.6, 1, 1)); b.cornerRadius = 60; [r addSublayer:b];
	CALayer *c = box(CGRectMake(50, 180, 120, 80), RGB(1, 0.8, 0, 1)); c.cornerRadius = 25; c.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMaxYCorner; [r addSublayer:c];
	CALayer *d = box(CGRectMake(220, 190, 120, 80), RGB(0.6, 0.2, 1, 1)); d.cornerRadius = 25; d.cornerCurve = kCACornerCurveContinuous; [r addSublayer:d]; return r; }
static CALayer *s_opacity(void) { CALayer *r = rootLayer(); CALayer *g = box(CGRectMake(40, 40, 200, 150), RGB(1, 1, 1, 1)); g.opacity = 0.5; [g addSublayer:box(CGRectMake(20, 20, 100, 100), RGB(1, 0, 0, 1))]; [g addSublayer:box(CGRectMake(70, 50, 100, 90), RGB(0, 0, 1, 1))]; [r addSublayer:g]; return r; }
static CALayer *s_shadow(void) { CALayer *r = rootLayer(); CALayer *a = box(CGRectMake(50, 50, 120, 80), RGB(1, 0.2, 0.2, 1)); a.shadowOpacity = 0.6; a.shadowRadius = 10; a.shadowOffset = CGSizeMake(0, -8); [r addSublayer:a];
	CALayer *b = box(CGRectMake(220, 60, 120, 80), RGB(0.2, 1, 0.2, 1)); b.cornerRadius = 16; b.shadowOpacity = 1; b.shadowRadius = 4; b.shadowOffset = CGSizeMake(6, 6); b.shadowColor = RGB(0, 0, 0, 1); [r addSublayer:b];
	CALayer *c = [CALayer layer]; c.frame = CGRectMake(50, 190, 120, 80); c.shadowOpacity = 0.8; c.shadowRadius = 8; CGMutablePathRef p = CGPathCreateMutable(); CGPathAddEllipseInRect(p, NULL, CGRectMake(0, 0, 120, 80)); c.shadowPath = p; [r addSublayer:c]; return r; }
static CALayer *s_transform(void) { CALayer *r = rootLayer(); CALayer *a = box(CGRectMake(60, 60, 120, 80), RGB(1, 0.5, 0, 1)); a.transform = CATransform3DMakeRotation(0.5, 0, 0, 1); [r addSublayer:a];
	CALayer *b = box(CGRectMake(240, 60, 100, 100), RGB(0, 0.7, 0.4, 1)); b.anchorPoint = CGPointMake(0, 0); b.transform = CATransform3DScale(CATransform3DMakeRotation(-0.3, 0, 0, 1), 1.2, 0.7, 1); [r addSublayer:b]; return r; }
static CALayer *s_perspective(void) { CALayer *r = rootLayer(); CATransform3D t = CATransform3DIdentity; t.m34 = -1.0 / 500; t = CATransform3DRotate(t, 0.7, 0, 1, 0); CALayer *a = box(CGRectMake(120, 60, 160, 160), RGB(0.9, 0.3, 0.6, 1)); a.cornerRadius = 12; a.transform = t; [r addSublayer:a];
	CALayer *c = box(CGRectMake(150, 90, 50, 50), RGB(1, 1, 1, 1)); [a addSublayer:c]; return r; }
static CALayer *s_clip(void) { CALayer *r = rootLayer(); CALayer *a = box(CGRectMake(60, 60, 160, 120), RGB(1, 1, 1, 1)); a.cornerRadius = 30; a.masksToBounds = YES; [a addSublayer:box(CGRectMake(-20, 30, 120, 40), RGB(1, 0, 0, 1))]; [a addSublayer:box(CGRectMake(100, 80, 100, 100), RGB(0, 0, 1, 1))]; [r addSublayer:a]; return r; }
static CALayer *s_border_order(void) { CALayer *r = rootLayer(); CALayer *a = box(CGRectMake(60, 60, 160, 120), RGB(1, 1, 1, 0.3)); a.borderWidth = 10; a.borderColor = RGB(0, 0, 0, 1); [a addSublayer:box(CGRectMake(0, 0, 80, 60), RGB(1, 0, 0, 1))]; [r addSublayer:a]; return r; }
static CALayer *s_gradient_img(void)
{
	CALayer *r = rootLayer();
	int iw = 32, ih = 32; uint8_t *px = malloc(iw * ih * 4);
	for (int y = 0; y < ih; y++) for (int x = 0; x < iw; x++) { uint8_t *p = px + (y * iw + x) * 4; p[0] = x * 8; p[1] = y * 8; p[2] = ((x / 8 + y / 8) & 1) ? 255 : 40; p[3] = 255; }
	CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB(); CGContextRef c = CGBitmapContextCreate(px, iw, ih, 8, iw * 4, cs, kCGImageAlphaPremultipliedLast); CGImageRef img = CGBitmapContextCreateImage(c);
	NSString *g[] = { kCAGravityResize, kCAGravityCenter, kCAGravityResizeAspect, kCAGravityResizeAspectFill, kCAGravityTopLeft, kCAGravityBottomRight };
	for (int i = 0; i < 6; i++) { CALayer *l = [CALayer layer]; l.frame = CGRectMake(20 + (i % 3) * 125, 20 + (i / 3) * 140, 110, 90); l.contents = (__bridge id)img; l.contentsGravity = g[i]; l.backgroundColor = RGB(0, 0, 0, 0.3); l.masksToBounds = YES; [r addSublayer:l]; }
	return r;
}
static CALayer *s_mask(void) { CALayer *r = rootLayer(); CALayer *a = box(CGRectMake(60, 60, 200, 160), RGB(1, 0.7, 0, 1)); CALayer *m = box(CGRectMake(20, 20, 100, 100), RGB(0, 0, 0, 1)); m.cornerRadius = 50; a.mask = m; [r addSublayer:a]; return r; }
static CALayer *s_sublayer_transform(void) { CALayer *r = rootLayer(); CALayer *a = box(CGRectMake(50, 50, 200, 160), RGB(1, 1, 1, 0.2)); a.sublayerTransform = CATransform3DMakeScale(0.5, 0.5, 1); [a addSublayer:box(CGRectMake(40, 40, 100, 80), RGB(1, 0, 0, 1))]; [r addSublayer:a]; return r; }
static CALayer *s_nested_opacity(void) { CALayer *r = rootLayer(); CALayer *a = box(CGRectMake(40, 40, 160, 160), RGB(1, 0, 0, 1)); a.opacity = 0.7; CALayer *b = box(CGRectMake(40, 40, 100, 100), RGB(0, 1, 0, 1)); b.opacity = 0.5; [a addSublayer:b]; [r addSublayer:a]; return r; }


static CALayer *stripes(void)
{
	CALayer *r = rootLayer();
	for (int i = 0; i < 10; i++) [r addSublayer:box(CGRectMake(i * 40, 0, 20, H), i % 2 ? RGB(1, 0.2, 0.1, 1) : RGB(0.1, 0.8, 0.3, 1))];
	return r;
}
static CALayer *s_blur_filter(void)
{
	CALayer *r = rootLayer(); CALayer *g = box(CGRectMake(60, 60, 280, 180), RGB(0, 0, 0, 0)); [g addSublayer:box(CGRectMake(20, 20, 100, 60), RGB(1, 1, 0, 1))]; CALayer *c = box(CGRectMake(150, 80, 100, 100), RGB(0, 0.5, 1, 1)); c.cornerRadius = 50; [g addSublayer:c];
	g.filters = @[FILTER(@"gaussianBlur", @"inputRadius", @6)]; [r addSublayer:g];
	CALayer *h = box(CGRectMake(20, 20, 60, 30), RGB(1, 1, 1, 1)); h.filters = @[FILTER(@"gaussianBlur", @"inputRadius", @1.5)]; [r addSublayer:h]; return r;
}
static CALayer *s_backdrop_blur(void)
{
	CALayer *r = stripes(); CALayer *g = box(CGRectMake(60, 60, 280, 180), RGB(1, 1, 1, 0.15)); g.cornerRadius = 24; g.backgroundFilters = @[FILTER(@"gaussianBlur", @"inputRadius", @8)]; [r addSublayer:g]; return r;
}
static CALayer *s_color_filters(void)
{
	CALayer *r = stripes();
	NSArray *fs = @[FILTER(@"colorSaturate", @"inputAmount", @0), FILTER(@"colorSaturate", @"inputAmount", @2.5), FILTER(@"colorBrightness", @"inputAmount", @0.3), FILTER(@"colorContrast", @"inputAmount", @2)];
	for (int i = 0; i < 4; i++) { CALayer *g = box(CGRectMake(20 + (i % 2) * 190, 20 + (i / 2) * 140, 170, 120), RGB(1, 1, 1, 0.0)); g.backgroundFilters = @[fs[i]]; [r addSublayer:g]; }
	return r;
}
static CALayer *s_filters_color(void)
{
	CALayer *r = rootLayer(); NSArray *fs = @[FILTER(@"colorSaturate", @"inputAmount", @0), FILTER(@"colorSaturate", @"inputAmount", @2.5), FILTER(@"colorBrightness", @"inputAmount", @0.3), FILTER(@"colorContrast", @"inputAmount", @2)];
	for (int i = 0; i < 4; i++) { CALayer *g = box(CGRectMake(20 + (i % 2) * 190, 20 + (i / 2) * 140, 170, 120), RGB(0.8, 0.3, 0.2, 0.9)); [g addSublayer:box(CGRectMake(10, 10, 60, 60), RGB(0.2, 0.7, 0.3, 1))]; g.filters = @[fs[i]]; [r addSublayer:g]; }
	return r;
}

static CALayer *s_contents_unclipped(void)
{
	CALayer *r = rootLayer();
	int iw = 32, ih = 32; uint8_t *px = malloc(iw * ih * 4);
	for (int y = 0; y < ih; y++) for (int x = 0; x < iw; x++) { uint8_t *p = px + (y * iw + x) * 4; p[0] = x * 8; p[1] = y * 8; p[2] = 120; p[3] = 255; }
	CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB(); CGContextRef c = CGBitmapContextCreate(px, iw, ih, 8, iw * 4, cs, kCGImageAlphaPremultipliedLast); CGImageRef img = CGBitmapContextCreateImage(c);
	NSString *g[] = { kCAGravityResizeAspectFill, kCAGravityCenter, kCAGravityBottomRight, kCAGravityTopLeft };
	CGRect fr[] = { { { 40, 40 }, { 90, 50 } }, { { 200, 40 }, { 20, 20 } }, { { 40, 180 }, { 20, 20 } }, { { 200, 180 }, { 20, 20 } } };
	for (int i = 0; i < 4; i++) { CALayer *l = [CALayer layer]; l.frame = fr[i]; l.contents = (__bridge id)img; l.contentsGravity = g[i]; l.contentsScale = 1; l.backgroundColor = RGB(0, 0, 0, 0.4); [r addSublayer:l]; }
	/* contentsRect and contentsCenter */
	CALayer *a = [CALayer layer]; a.frame = CGRectMake(280, 40, 100, 100); a.contents = (__bridge id)img; a.contentsRect = CGRectMake(0.25, 0.25, 0.5, 0.5); [r addSublayer:a];
	CALayer *b = [CALayer layer]; b.frame = CGRectMake(280, 170, 100, 100); b.contents = (__bridge id)img; b.contentsCenter = CGRectMake(0.3, 0.3, 0.4, 0.4); [r addSublayer:b];
	CALayer *c2 = [CALayer layer]; c2.frame = CGRectMake(120, 120, 60, 60); c2.contents = (__bridge id)img; c2.contentsGravity = kCAGravityResize; c2.magnificationFilter = kCAFilterNearest; [r addSublayer:c2];
	return r;
}
static CGPathRef starPath(double cx, double cy, double R, double r)
{
	CGMutablePathRef p = CGPathCreateMutable();
	for (int i = 0; i < 10; i++) { double a = -M_PI / 2 + i * M_PI / 5, rr = i % 2 ? r : R; double x = cx + cos(a) * rr, y = cy + sin(a) * rr; if (i == 0) CGPathMoveToPoint(p, NULL, x, y); else CGPathAddLineToPoint(p, NULL, x, y); }
	CGPathCloseSubpath(p); return p;
}
static CALayer *s_shape(void)
{
	CALayer *r = rootLayer();
	CAShapeLayer *a = [CAShapeLayer layer]; a.frame = CGRectMake(20, 20, 120, 120); a.path = starPath(60, 60, 55, 24); a.fillColor = RGB(1, 0.8, 0, 1); a.strokeColor = RGB(0.5, 0, 0, 1); a.lineWidth = 6; a.lineJoin = kCALineJoinRound; [r addSublayer:a];
	CAShapeLayer *b = [CAShapeLayer layer]; b.frame = CGRectMake(160, 20, 120, 120); b.path = starPath(60, 60, 55, 24); b.fillColor = RGB(0, 0.6, 1, 1); b.fillRule = kCAFillRuleEvenOdd; b.strokeColor = RGB(1, 1, 1, 1); b.lineWidth = 3; b.lineDashPattern = @[@8, @4]; [r addSublayer:b];
	CAShapeLayer *c = [CAShapeLayer layer]; c.frame = CGRectMake(20, 160, 200, 100); CGMutablePathRef p = CGPathCreateMutable(); CGPathMoveToPoint(p, NULL, 10, 80); CGPathAddCurveToPoint(p, NULL, 50, -20, 120, 120, 190, 20); c.path = p; c.fillColor = NULL; c.strokeColor = RGB(1, 1, 1, 1); c.lineWidth = 8; c.lineCap = kCALineCapRound; c.strokeStart = 0.15; c.strokeEnd = 0.8; [r addSublayer:c];
	CAShapeLayer *d = [CAShapeLayer layer]; d.frame = CGRectMake(250, 170, 130, 100); d.path = CGPathCreateWithRoundedRect(CGRectMake(10, 10, 110, 80), 20, 20, NULL); d.fillColor = RGB(0.8, 0.2, 0.8, 0.8); d.strokeColor = RGB(0, 0, 0, 1); d.lineWidth = 5; d.miterLimit = 4; [r addSublayer:d];
	return r;
}
static CALayer *s_gradient(void)
{
	CALayer *r = rootLayer();
	CAGradientLayer *a = [CAGradientLayer layer]; a.frame = CGRectMake(20, 20, 160, 110); a.colors = @[(__bridge id)RGB(1, 0, 0, 1), (__bridge id)RGB(1, 1, 0, 1), (__bridge id)RGB(0, 0.5, 1, 1)]; a.locations = @[@0, @0.4, @1]; a.startPoint = CGPointMake(0, 0); a.endPoint = CGPointMake(1, 1); [r addSublayer:a];
	CAGradientLayer *b = [CAGradientLayer layer]; b.frame = CGRectMake(210, 20, 160, 110); b.colors = @[(__bridge id)RGB(1, 1, 1, 1), (__bridge id)RGB(0, 0, 0, 0.2)]; b.type = kCAGradientLayerRadial; b.startPoint = CGPointMake(0.5, 0.5); b.endPoint = CGPointMake(1, 1); b.cornerRadius = 16; [r addSublayer:b];
	CAGradientLayer *c = [CAGradientLayer layer]; c.frame = CGRectMake(20, 160, 130, 110); c.colors = @[(__bridge id)RGB(1, 0, 0, 1), (__bridge id)RGB(0, 1, 0, 1), (__bridge id)RGB(0, 0, 1, 1), (__bridge id)RGB(1, 0, 0, 1)]; c.type = kCAGradientLayerConic; c.startPoint = CGPointMake(0.5, 0.5); c.endPoint = CGPointMake(0.5, 0); [r addSublayer:c];
	CAGradientLayer *d = [CAGradientLayer layer]; d.frame = CGRectMake(180, 160, 190, 110); d.colors = @[(__bridge id)RGB(0, 0, 0, 0), (__bridge id)RGB(0, 0, 0, 1)]; d.startPoint = CGPointMake(0, 0.5); d.endPoint = CGPointMake(1, 0.5); d.backgroundColor = RGB(1, 1, 1, 1); [r addSublayer:d];
	return r;
}
static CALayer *s_text(void)
{
	CALayer *r = rootLayer();
	CATextLayer *a = [CATextLayer layer]; a.frame = CGRectMake(20, 20, 360, 40); a.string = @"Hello Core Animation"; a.fontSize = 28; a.foregroundColor = RGB(1, 1, 1, 1); a.contentsScale = 1; [r addSublayer:a];
	CATextLayer *b = [CATextLayer layer]; b.frame = CGRectMake(20, 80, 200, 80); b.string = @"This text wraps over several lines because it is long."; b.fontSize = 16; b.wrapped = YES; b.alignmentMode = kCAAlignmentCenter; b.foregroundColor = RGB(1, 0.9, 0.4, 1); b.contentsScale = 1; [r addSublayer:b];
	CATextLayer *c = [CATextLayer layer]; c.frame = CGRectMake(240, 80, 140, 40); c.string = [[NSAttributedString alloc] initWithString:@"Attributed" attributes:@{ NSForegroundColorAttributeName: [NSColor cyanColor], NSFontAttributeName: [NSFont boldSystemFontOfSize:20] }]; c.contentsScale = 1; [r addSublayer:c];
	CATextLayer *d = [CATextLayer layer]; d.frame = CGRectMake(20, 200, 150, 30); d.string = @"truncation of a long string"; d.fontSize = 18; d.truncationMode = kCATruncationEnd; d.foregroundColor = RGB(1, 1, 1, 1); d.contentsScale = 1; [r addSublayer:d];
	return r;
}
static CALayer *s_replicator(void)
{
	CALayer *r = rootLayer();
	CAReplicatorLayer *a = [CAReplicatorLayer layer]; a.frame = CGRectMake(20, 20, 360, 100); a.instanceCount = 6; a.instanceTransform = CATransform3DMakeTranslation(55, 0, 0); a.instanceColor = RGB(1, 1, 1, 1); a.instanceGreenOffset = -0.15; a.instanceBlueOffset = -0.15; a.instanceAlphaOffset = -0.1;
	CALayer *s = box(CGRectMake(10, 10, 40, 40), RGB(1, 0.5, 0.5, 1)); s.cornerRadius = 8; [a addSublayer:s]; [r addSublayer:a];
	CAReplicatorLayer *b = [CAReplicatorLayer layer]; b.frame = CGRectMake(200, 150, 100, 100); b.instanceCount = 12; b.instanceTransform = CATransform3DMakeRotation(2 * M_PI / 12, 0, 0, 1);
	CALayer *t = box(CGRectMake(48, 5, 4, 20), RGB(1, 1, 0, 1)); [b addSublayer:t]; [r addSublayer:b]; return r;
}
static CALayer *s_zorder(void)
{
	CALayer *r = rootLayer();
	CALayer *a = box(CGRectMake(40, 40, 120, 120), RGB(1, 0, 0, 1)); a.zPosition = 10; CALayer *b = box(CGRectMake(80, 80, 120, 120), RGB(0, 1, 0, 1)); b.zPosition = 0; CALayer *c = box(CGRectMake(120, 120, 120, 120), RGB(0, 0, 1, 1)); c.zPosition = 5;
	[r addSublayer:a]; [r addSublayer:b]; [r addSublayer:c];
	CALayer *p = [CALayer layer]; p.frame = CGRectMake(260, 40, 120, 220); CATransform3D t = CATransform3DIdentity; t.m34 = -1.0 / 400; p.sublayerTransform = t;
	CALayer *x = box(CGRectMake(10, 10, 100, 100), RGB(1, 0.5, 0, 1)); x.zPosition = 80; CALayer *y = box(CGRectMake(30, 40, 80, 100), RGB(0, 0.8, 0.8, 1)); y.zPosition = -80; [p addSublayer:x]; [p addSublayer:y]; [r addSublayer:p];
	return r;
}
static CALayer *s_transformlayer(void)
{
	CALayer *r = rootLayer(); CATransformLayer *tl = [CATransformLayer layer]; tl.frame = CGRectMake(120, 60, 160, 160);
	CATransform3D p = CATransform3DIdentity; p.m34 = -1.0 / 500; tl.transform = CATransform3DRotate(p, 0.6, 0, 1, 0);
	CALayer *a = box(CGRectMake(0, 0, 160, 160), RGB(1, 0.2, 0.2, 0.9)); a.zPosition = 40; CALayer *b = box(CGRectMake(0, 0, 160, 160), RGB(0.2, 0.2, 1, 0.9)); b.zPosition = -40; [tl addSublayer:b]; [tl addSublayer:a]; [r addSublayer:tl]; return r;
}
static CALayer *s_rasterize(void)
{
	CALayer *r = rootLayer(); CALayer *a = box(CGRectMake(40, 40, 160, 120), RGB(1, 1, 1, 0.5)); a.shouldRasterize = YES; a.rasterizationScale = 1; a.cornerRadius = 20; a.opacity = 0.8;
	[a addSublayer:box(CGRectMake(20, 20, 80, 60), RGB(1, 0, 0, 1))]; [a addSublayer:box(CGRectMake(60, 50, 80, 60), RGB(0, 0, 1, 1))]; [r addSublayer:a]; return r;
}
static CALayer *s_flipped(void)
{
	CALayer *r = rootLayer();
	CALayer *a = box(CGRectMake(40, 40, 160, 120), RGB(1, 1, 1, 0.3)); a.geometryFlipped = YES;
	[a addSublayer:box(CGRectMake(10, 10, 60, 30), RGB(1, 0, 0, 1))]; [a addSublayer:box(CGRectMake(80, 70, 60, 40), RGB(0, 0, 1, 1))]; [r addSublayer:a];
	CALayer *b = box(CGRectMake(240, 40, 130, 120), RGB(1, 1, 1, 0.3)); b.geometryFlipped = YES; b.transform = CATransform3DMakeRotation(0.4, 0, 0, 1);
	[b addSublayer:box(CGRectMake(10, 10, 60, 30), RGB(1, 0.6, 0, 1))]; [r addSublayer:b];
	CALayer *p = box(CGRectMake(40, 190, 160, 90), RGB(0.2, 0.2, 0.2, 0.5)); p.geometryFlipped = YES; CALayer *c = box(CGRectMake(10, 10, 60, 30), RGB(0, 1, 0, 1)); c.geometryFlipped = YES; [p addSublayer:c]; [r addSublayer:p];
	return r;
}
static CGImageRef asymImage(void)
{
	int iw = 32, ih = 32; uint8_t *px = malloc(iw * ih * 4);
	for (int y = 0; y < ih; y++) for (int x = 0; x < iw; x++) { uint8_t *p = px + (y * iw + x) * 4; p[0] = x * 8; p[1] = y * 8; p[2] = (x < 8 && y < 8) ? 255 : 30; p[3] = 255; }
	CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB(); CGContextRef c = CGBitmapContextCreate(px, iw, ih, 8, iw * 4, cs, kCGImageAlphaPremultipliedLast); return CGBitmapContextCreateImage(c);
}
static CALayer *s_flipped_contents(void)
{
	CALayer *r = rootLayer(); CGImageRef img = asymImage();
	/* 1: unflipped layer with contents; 2: flipped layer with contents; 3: flipped parent, unflipped child with contents; 4: flipped parent, flipped child with contents */
	CALayer *a = [CALayer layer]; a.frame = CGRectMake(20, 20, 64, 64); a.contents = (__bridge id)img; [r addSublayer:a];
	CALayer *b = [CALayer layer]; b.frame = CGRectMake(110, 20, 64, 64); b.contents = (__bridge id)img; b.geometryFlipped = YES; [r addSublayer:b];
	CALayer *pp = box(CGRectMake(200, 20, 90, 90), RGB(1, 1, 1, 0.2)); pp.geometryFlipped = YES; [r addSublayer:pp];
	CALayer *c = [CALayer layer]; c.frame = CGRectMake(5, 5, 64, 64); c.contents = (__bridge id)img; [pp addSublayer:c];
	CALayer *qq = box(CGRectMake(300, 20, 90, 90), RGB(1, 1, 1, 0.2)); qq.geometryFlipped = YES; [r addSublayer:qq];
	CALayer *d = [CALayer layer]; d.frame = CGRectMake(5, 5, 64, 64); d.contents = (__bridge id)img; d.geometryFlipped = YES; [qq addSublayer:d];
	return r;
}
static struct { const char *name; SceneFn fn; } kScenes[] = {
	{ "flipped_contents", s_flipped_contents },
	{ "flipped", s_flipped },
	{ "shape", s_shape }, { "gradient", s_gradient }, { "text", s_text }, { "replicator", s_replicator }, { "zorder", s_zorder }, { "transformlayer", s_transformlayer }, { "rasterize", s_rasterize },
	{ "contents_unclipped", s_contents_unclipped },
	{ "blur_filter", s_blur_filter }, { "backdrop_blur", s_backdrop_blur }, { "color_filters", s_color_filters }, { "filters_color", s_filters_color }, { "solid", s_solid }, { "rounded", s_rounded }, { "opacity", s_opacity }, { "shadow", s_shadow }, { "transform", s_transform }, { "perspective", s_perspective },
	{ "clip", s_clip }, { "border_order", s_border_order }, { "contents", s_gradient_img }, { "mask", s_mask }, { "sublayer_transform", s_sublayer_transform }, { "nested_opacity", s_nested_opacity },
};

int main(int argc, char **argv)
{
	setvbuf(stdout, NULL, _IONBF, 0);
	const char *outdir = argc > 1 ? argv[1] : "/tmp/scenes";
	@autoreleasepool {
		[[NSFileManager defaultManager] createDirectoryAtPath:[NSString stringWithUTF8String:outdir] withIntermediateDirectories:YES attributes:nil error:nil];
		uint8_t *buf = malloc(W * H * 4);
#ifdef REAL_CA
		id<MTLDevice> dev = MTLCreateSystemDefaultDevice(); id<MTLCommandQueue> q = [dev newCommandQueue];
		MTLTextureDescriptor *td = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:W height:H mipmapped:NO]; td.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead; td.storageMode = MTLStorageModeShared;
		id<MTLTexture> tex = [dev newTextureWithDescriptor:td];
#endif
		for (size_t i = 0; i < sizeof kScenes / sizeof kScenes[0]; i++) {
			if (argc > 2 && strcmp(argv[2], kScenes[i].name)) continue;
			CALayer *root = kScenes[i].fn();
			if (getenv("CTXMODE")) {
				CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB(); memset(buf, 0, W * H * 4);
				CGContextRef c = CGBitmapContextCreate(buf, W, H, 8, W * 4, cs, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
				[root renderInContext:c]; CGContextRelease(c); CGColorSpaceRelease(cs);
				char path[512]; snprintf(path, sizeof path, "%s/%s.bgra", outdir, kScenes[i].name); FILE *f = fopen(path, "wb"); fwrite(buf, 1, W * H * 4, f); fclose(f);
				continue;
			}
#ifdef REAL_CA
			CARenderer *R = [CARenderer rendererWithMTLTexture:tex options:@{ kCARendererMetalCommandQueue: q }];
			R.layer = root; R.bounds = CGRectMake(0, 0, W, H); [CATransaction flush];
			[R beginFrameAtTime:CACurrentMediaTime() timeStamp:NULL]; [R addUpdateRect:R.bounds]; [R render]; [R endFrame];
			id<MTLCommandBuffer> cb = [q commandBuffer]; [cb commit]; [cb waitUntilCompleted];
			[tex getBytes:buf bytesPerRow:W * 4 fromRegion:MTLRegionMake2D(0, 0, W, H) mipmapLevel:0];
#else
			memset(buf, 0, W * H * 4);
			CARenderer *R = [CARenderer rendererWithBitmap:buf width:W height:H bytesPerRow:W * 4 options:nil];
			R.layer = root; R.bounds = CGRectMake(0, 0, W, H); [CATransaction flush];
			[R beginFrameAtTime:CACurrentMediaTime() timeStamp:NULL]; [R addUpdateRect:R.bounds]; [R render]; [R endFrame];
#endif
			char path[512]; snprintf(path, sizeof path, "%s/%s.bgra", outdir, kScenes[i].name);
			FILE *f = fopen(path, "wb"); fwrite(buf, 1, W * H * 4, f); fclose(f);
		}
	}
	return 0;
}
