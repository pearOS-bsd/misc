/* Scenes rendered by the real QuartzCore (CARenderer into a Metal texture) and by this implementation; the images are compared. */
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#ifdef REAL_CA
#import <Metal/Metal.h>
#endif
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
static struct { const char *name; SceneFn fn; } kScenes[] = {
	{ "contents_unclipped", s_contents_unclipped },
	{ "solid", s_solid }, { "rounded", s_rounded }, { "opacity", s_opacity }, { "shadow", s_shadow }, { "transform", s_transform }, { "perspective", s_perspective },
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
