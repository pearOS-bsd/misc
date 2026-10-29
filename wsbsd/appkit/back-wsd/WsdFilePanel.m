/* The Open and Save panels of the Mac, drawn after the real ones (AppKit's NSOpenPanel / NSSavePanel run in the "Open and Save Panel Service", not in the Finder). The sizes and colours come from the panel of this Mac measured in a test program:
 * the Open panel is 880 x 448 with a sidebar 135 wide, a toolbar 63 high, columns 244 wide with rows of 22, a bar of 66 at the bottom; the Save panel is a form of 370 x 204 (Save As, Tags, Where).
 * GNUstep's NSSavePanel / NSOpenPanel stay the API: -[NSApplication runModalForWindow:] of one of them runs this panel instead, and the answers are handed out through the panel's accessors. */
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#import <GNUstepGUI/GSDisplayServer.h>
#include <math.h>
#include "car.h"
#include "bvg.h"
#ifdef __FreeBSD__
#include <sys/types.h>
#include <sys/extattr.h>
#endif

static IMP origSetName, origRunModal, origRunModalRel, origBeginCompletion, origSaveFilename, origOpenFilenames;
static const char kResult = 0, kTags = 0;
@class WsdTagField;

@interface GSDisplayServer (WsdDropFiles) - (BOOL) wsdDropFiles: (NSArray *)paths atScreenPoint: (NSPoint)p; @end
@interface GSDisplayServer (WsdCorners) - (void) wsdWindowCorners: (int)radius : (int)win; - (void) wsdWindowScale: (float)scale : (int)win; @end
static void ScaleWindow(NSWindow *w, float scale) { id srv = GSCurrentServer(); if ([srv respondsToSelector: @selector(wsdWindowScale::)]) [srv wsdWindowScale: scale : (int)[w windowNumber]]; }
/* the panel's open animation, measured on the Mac: scale 0.98 -> 1.0023 (at about 0.1 s) -> 1 within 0.2 s while it fades in; closing fades out in 0.1 s */
/* the tags chosen in the Save panel go onto the file once the application has written it (the Mac's panel does the same: the file is not there yet when the panel closes) */
@interface WsdTagApplier : NSObject { NSString *path; NSArray *tags; int tries; } + (void)apply:(NSArray *)tags toPath:(NSString *)p; @end
static void SetTags(NSString *path, NSArray *names);
@implementation WsdTagApplier
+ (void)apply:(NSArray *)t toPath:(NSString *)p { WsdTagApplier *a = [WsdTagApplier new]; a->path = p; a->tags = t; [[NSRunLoop currentRunLoop] addTimer: [NSTimer scheduledTimerWithTimeInterval: 0.5 target: a selector: @selector(tick:) userInfo: nil repeats: YES] forMode: NSDefaultRunLoopMode]; }
- (void)tick:(NSTimer *)t { if ([[NSFileManager defaultManager] fileExistsAtPath: path]) { SetTags(path, tags); [t invalidate]; } else if (++tries > 40) [t invalidate]; }
@end
@interface WsdPanelAnim : NSObject { NSWindow *win; NSDate *t0; NSTimer *timer; } + (void)open:(NSWindow *)w; + (void)close:(NSWindow *)w; @end
@implementation WsdPanelAnim
+ (void)open:(NSWindow *)w
{
	WsdPanelAnim *a = [WsdPanelAnim new]; a->win = w; a->t0 = [NSDate date]; [w setAlphaValue: 0]; ScaleWindow(w, 0.98f);
	a->timer = [NSTimer timerWithTimeInterval: 1.0 / 60 target: a selector: @selector(tick:) userInfo: nil repeats: YES];
	[[NSRunLoop currentRunLoop] addTimer: a->timer forMode: NSDefaultRunLoopMode]; [[NSRunLoop currentRunLoop] addTimer: a->timer forMode: NSModalPanelRunLoopMode];
}
- (void)tick:(NSTimer *)t
{
	double e = -[t0 timeIntervalSinceNow];
	if (e >= 0.3) { ScaleWindow(win, 1.0f); [win setAlphaValue: 1]; [timer invalidate]; return; }
	ScaleWindow(win, (float)(1 - 0.02 * exp(-9 * e) * cos(18 * e))); [win setAlphaValue: (CGFloat)fmin(1, e / 0.1)];
}
+ (void)close:(NSWindow *)w
{
	NSDate *t0 = [NSDate date]; double e;
	while ((e = -[t0 timeIntervalSinceNow]) < 0.1) { [w setAlphaValue: (CGFloat)(1 - e / 0.1)]; [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 1.0 / 60]]; }
}
@end
static void RoundWindow(NSWindow *w, int radius) { id srv = GSCurrentServer(); if ([srv respondsToSelector: @selector(wsdWindowCorners::)]) [srv wsdWindowCorners: radius : (int)[w windowNumber]]; }
static BOOL DrawSymbol(NSString *name, NSRect cell, CGFloat pointSize, NSColor *tint);
static NSTextField *SearchField(NSView *root, NSRect f);
static NSTextField *Field(NSRect f, NSString *val); static NSButton *Btn(NSString *title, NSRect f, id target, SEL action, BOOL def);
static NSColor *RGB(int r, int g, int b) { return [NSColor colorWithCalibratedRed: r / 255.0 green: g / 255.0 blue: b / 255.0 alpha: 1]; }
static NSColor *RGBA(int r, int g, int b, double a) { return [NSColor colorWithCalibratedRed: r / 255.0 green: g / 255.0 blue: b / 255.0 alpha: a]; }
extern BOOL WsdAppearanceIsDark(void);
static BOOL PDark(void) { return WsdAppearanceIsDark(); }
/* the palette: measured on the dark panel (the light one is the same structure on white) */
#define P_CONTENT   (PDark() ? RGB(28, 36, 44) : RGB(255, 255, 255))
#define P_SIDEBAR   (PDark() ? RGB(31, 41, 50) : RGB(236, 236, 238))
#define P_CONTROL   (PDark() ? RGB(45, 52, 60) : RGB(245, 245, 247))
#define P_FIELD     (PDark() ? RGB(23, 24, 25) : RGB(255, 255, 255))
#define P_LINE      (PDark() ? RGB(50, 57, 65) : RGB(214, 214, 218))
#define P_SELECT    (PDark() ? RGB(46, 55, 64) : RGB(222, 222, 226))
#define P_TEXT      (PDark() ? RGBA(255, 255, 255, 0.85) : RGBA(0, 0, 0, 0.85))
#define P_DIM       (PDark() ? RGBA(255, 255, 255, 0.42) : RGBA(0, 0, 0, 0.42))
#define P_HEADER    (PDark() ? RGB(150, 157, 160) : RGB(120, 120, 124))

static NSDictionary *Attr(CGFloat size, BOOL bold, NSColor *col) { return @{ NSFontAttributeName: bold ? [NSFont boldSystemFontOfSize: size] : [NSFont systemFontOfSize: size], NSForegroundColorAttributeName: col }; }
static void Text(NSString *s, NSPoint left_center, CGFloat size, BOOL bold, NSColor *col, BOOL flipped)       /* the text's vertical centre at left_center.y */
{
	NSDictionary *a = Attr(size, bold, col); NSSize ts = [s sizeWithAttributes: a];
	[s drawAtPoint: NSMakePoint(left_center.x, left_center.y - ts.height / 2) withAttributes: a]; (void)flipped;
}
static void TextFit(NSString *s, NSPoint left_center, CGFloat size, NSColor *col, CGFloat maxW)               /* the text cut with an ellipsis to fit */
{
	NSDictionary *a = Attr(size, NO, col);
	if ([s sizeWithAttributes: a].width > maxW) { NSString *t = s; while ([t length] > 1 && [[t stringByAppendingString: @"\u2026"] sizeWithAttributes: a].width > maxW) t = [t substringToIndex: [t length] - 1]; s = [t stringByAppendingString: @"\u2026"]; }
	Text(s, left_center, size, NO, col, NO);
}
static void FillRound(NSRect r, CGFloat rad, NSColor *c) { [c setFill]; [[NSBezierPath bezierPathWithRoundedRect: r xRadius: rad yRadius: rad] fill]; }

/* ---- the pictures: bitmaps taken from the system's own asset catalogues (coreui: .car files of the Mac), scaled with an area filter and tinted when asked.
 * A picture is named "car:<catalogue>:<rendition>" (one bitmap) or "set:<catalogue>:<image set>" (the size that fits best) */
static NSString *CarPath(NSString *name)
{
	static NSArray *dirs; if (!dirs) dirs = @[ @"/usr/local/share/wsbsd/coreui", @"/root/wsbsd/coreui/assets", @"/System/Library/PrivateFrameworks/DesktopServicesPriv.framework/Versions/A/Resources", @"/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources" ];
	for (NSString *d in dirs) for (NSString *f in @[ [name stringByAppendingString: @".car"], @"Assets.car" ]) { NSString *p = [d stringByAppendingPathComponent: f]; if ([[NSFileManager defaultManager] fileExistsAtPath: p] && ([f isEqual: @"Assets.car"] ? [d containsString: name] : YES)) return p; }
	return nil;
}
static CarFile *CarNamed(NSString *name)
{
	static NSMutableDictionary *cache; if (!cache) cache = [NSMutableDictionary dictionary];
	NSValue *v = cache[name]; if (v) return [v pointerValue] ? (CarFile *)[v pointerValue] : NULL;
	NSString *p = CarPath(name); CarFile *c = p ? car_open([p fileSystemRepresentation]) : NULL; cache[name] = [NSValue valueWithPointer: c]; return c;
}
static NSBitmapImageRep *RepFromPixels(const uint8_t *p, int w, int h, int bpp)                                   /* BGRA premultiplied or gray + alpha -> straight RGBA */
{
	NSBitmapImageRep *r = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes: NULL pixelsWide: w pixelsHigh: h bitsPerSample: 8 samplesPerPixel: 4 hasAlpha: YES isPlanar: NO colorSpaceName: NSDeviceRGBColorSpace bitmapFormat: NSAlphaNonpremultipliedBitmapFormat bytesPerRow: 0 bitsPerPixel: 0];
	unsigned char *d = [r bitmapData]; NSInteger bpr = [r bytesPerRow];
	for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
		const uint8_t *q = p + ((size_t)y * w + x) * bpp; unsigned char *o = d + y * bpr + x * 4;
		if (bpp == 2) { o[0] = o[1] = o[2] = q[0]; o[3] = q[1]; }
		else { unsigned a = q[3]; if (a) { o[0] = (unsigned char)fmin(255, q[2] * 255.0 / a + 0.5); o[1] = (unsigned char)fmin(255, q[1] * 255.0 / a + 0.5); o[2] = (unsigned char)fmin(255, q[0] * 255.0 / a + 0.5); } else o[0] = o[1] = o[2] = 0; o[3] = (unsigned char)a; }
	}
	return r;
}

/* the window buttons of the title bar (close, minimize, zoom) from the Mac's own catalogue: Aqua.car / DarkAqua.car, "WindowFrame_WindowControlButtons_Regular": the key has Dimension1 = the button (0 close, 1 minimize, 2 zoom, 3 close of an edited document, 4 / 5 full screen) and State (0 rest: the plain disc, 1 the pointer is over the group: with its glyph, 2 pressed). 16 pt discs, one rendition per scale (the pixels lie in a packed atlas, coreui's car_bitmap_linked). NULL when the catalogue is not there. */
/* a window button drawn as the Mac does while it is held and dragged: it swells to 1.14 and stretches like rubber toward the pointer (subtle: the long axis grows with the distance up to 1.3 times, the short one gives way so that the area stays), and drifts up to 3 px toward it. `pull` is the vector from the disc's centre to the pointer in the view's own coordinates. The measured part is the swelling (14 to 16 px); the stretch was described by the user ("rubber when you drag far") and drawn by eye. */
void WsdDrawWindowButton(NSImage *im, NSRect r, BOOL held, NSPoint pull)
{
	if (!held) { [im drawInRect: r fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1.0]; return; }
	double d = hypot(pull.x, pull.y), e = d / (d + 120.0), L = 1.143 * (1.0 + 0.30 * e), S = 1.143 / sqrt(1.0 + 0.30 * e), ang = d > 0.5 ? atan2(pull.y, pull.x) : 0, off = e * 3.0;      /* subtle: at most 1.3 times longer and 3 px of drift */
	NSGraphicsContext *gc = [NSGraphicsContext currentContext]; [gc saveGraphicsState];
	NSAffineTransform *t = [NSAffineTransform transform]; NSAffineTransformStruct m = { cos(ang) * L, sin(ang) * L, -sin(ang) * S, cos(ang) * S, NSMidX(r) + (d > 0.5 ? pull.x / d * off : 0), NSMidY(r) + (d > 0.5 ? pull.y / d * off : 0) };      /* translate * rotate * scale, written out */
	[t setTransformStruct: m]; [t concat];
	[im drawInRect: NSMakeRect(-r.size.width / 2, -r.size.height / 2, r.size.width, r.size.height) fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1.0];
	[gc restoreGraphicsState];
}
NSImage *WsdWindowButtonImage(int kind, int state, BOOL dark)
{
	static NSMutableDictionary *cache; if (!cache) cache = [[NSMutableDictionary alloc] init];
	NSString *key = [NSString stringWithFormat: @"%d.%d.%d", kind, state, dark ? 1 : 0]; id hit = cache[key]; if (hit) return hit == [NSNull null] ? nil : hit;
	NSImage *img = nil; CarFile *car = CarNamed(dark ? @"DarkAqua" : @"Aqua"); if (!car) car = CarNamed(dark ? @"Aqua" : @"DarkAqua");
	if (car) { int at[32]; for (int i = 0; i < 32; i++) at[i] = -1; at[1] = 24; at[2] = 1; at[8] = kind; at[10] = state; at[12] = 1; at[14] = 0; CarRendition r; int w, h, bpp; uint8_t *px = NULL;
		if (!car_find_attrs(car, "WindowFrame_WindowControlButtons_Regular.psd", at, &r)) px = car_bitmap_linked(car, &r, &w, &h, &bpp);
		if (px && bpp == 4) { NSBitmapImageRep *rep = RepFromPixels(px, w, h, bpp); if (rep) { img = [[NSImage alloc] initWithSize: NSMakeSize(w, h)]; [img addRepresentation: rep]; } } free(px); }
	cache[key] = img ?: (id)[NSNull null]; return img;
}
static NSBitmapImageRep *LoadRep(NSString *file, int px)
{
	static NSMutableDictionary *cache; if (!cache) cache = [NSMutableDictionary dictionary];
	NSArray *parts = [file componentsSeparatedByString: @":"]; if ([parts count] != 3) return nil;
	CarFile *car = CarNamed(parts[1]); if (!car) return nil;
	CarRendition r; BOOL ok = NO; const char *nm = [parts[2] UTF8String];
	if ([parts[0] isEqual: @"set"]) ok = !car_image_set(car, nm, px * 2, &r); else ok = !car_find(car, nm, -1, -1, -1, &r);
	if (!ok) return nil;
	NSString *key = [NSString stringWithFormat: @"%@|%d", file, r.width]; id c = cache[key]; if (c) return c == [NSNull null] ? nil : c;
	int w, h, bpp; uint8_t *pix = car_bitmap(&r, &w, &h, &bpp); NSBitmapImageRep *rep = pix ? RepFromPixels(pix, w, h, bpp) : nil; free(pix);
	if (getenv("WSD_PANEL_DEBUG")) NSLog(@"panel picture %@ -> %s %dx%d bpp %d %s", file, r.name, w, h, bpp, rep ? "ok" : "FAILED");
	cache[key] = rep ?: (id)[NSNull null]; return rep;
}
/* the picture `file` at px x px (box filter in premultiplied space); tint: every pixel gets this colour, the alpha stays */
static NSImage *Picture(NSString *file, int px, NSColor *tint)
{
	static NSMutableDictionary *cache; if (!cache) cache = [NSMutableDictionary dictionary];
	NSString *key = [NSString stringWithFormat: @"%@|%d|%@", file, px, tint ? [tint description] : @""]; id hit = cache[key]; if (hit) return hit == [NSNull null] ? nil : hit;
	NSBitmapImageRep *src = LoadRep(file, px); if (!src) { cache[key] = [NSNull null]; return nil; }
	int sw = (int)[src pixelsWide], sh = (int)[src pixelsHigh]; NSInteger sbpr = [src bytesPerRow]; const unsigned char *sp = [src bitmapData];
	NSBitmapImageRep *dst = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes: NULL pixelsWide: px pixelsHigh: px bitsPerSample: 8 samplesPerPixel: 4 hasAlpha: YES isPlanar: NO colorSpaceName: NSDeviceRGBColorSpace bitmapFormat: NSAlphaNonpremultipliedBitmapFormat bytesPerRow: 0 bitsPerPixel: 0];
	unsigned char *dp = [dst bitmapData]; NSInteger dbpr = [dst bytesPerRow]; CGFloat tr = 0, tg = 0, tb = 0, ta = 1; if (tint) [[tint colorUsingColorSpaceName: NSCalibratedRGBColorSpace] getRed: &tr green: &tg blue: &tb alpha: &ta];
	double kx = (double)sw / px, ky = (double)sh / px;
	for (int y = 0; y < px; y++) for (int x = 0; x < px; x++) {
		double y0 = y * ky, y1 = (y + 1) * ky, x0 = x * kx, x1 = (x + 1) * kx, sr = 0, sg = 0, sb = 0, sa = 0, wsum = 0;
		for (int yy = (int)y0; yy < (int)ceil(y1) && yy < sh; yy++) for (int xx = (int)x0; xx < (int)ceil(x1) && xx < sw; xx++) {
			double w = (fmin(xx + 1, x1) - fmax(xx, x0)) * (fmin(yy + 1, y1) - fmax(yy, y0)); const unsigned char *q = sp + yy * sbpr + xx * 4; double a = q[3] / 255.0;
			sr += w * a * q[0]; sg += w * a * q[1]; sb += w * a * q[2]; sa += w * a; wsum += w;
		}
		unsigned char *o = dp + (px - 1 - y) * dbpr + x * 4; double a = wsum > 0 ? sa / wsum : 0;                       /* rows reversed: the pictures are drawn in flipped views */
		if (tint) { o[0] = (unsigned char)(tr * 255 + 0.5); o[1] = (unsigned char)(tg * 255 + 0.5); o[2] = (unsigned char)(tb * 255 + 0.5); o[3] = (unsigned char)(a * ta * 255 + 0.5); }
		else if (sa > 0) { o[0] = (unsigned char)fmin(255, sr / sa + 0.5); o[1] = (unsigned char)fmin(255, sg / sa + 0.5); o[2] = (unsigned char)fmin(255, sb / sa + 0.5); o[3] = (unsigned char)(a * 255 + 0.5); }
		else o[0] = o[1] = o[2] = o[3] = 0;
	}
	if (getenv("WSD_PANEL_DEBUG")) [[dst representationUsingType: NSPNGFileType properties: nil] writeToFile: [NSString stringWithFormat: @"/tmp/panelpic_%lu_%d.png", (unsigned long)[key hash], px] atomically: NO];
	NSImage *img = [[NSImage alloc] initWithSize: NSMakeSize(px, px)]; [img addRepresentation: dst]; cache[key] = img; return img;
}
static void DrawPic(NSImage *img, NSRect r) { if (img) [img drawInRect: r fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1.0]; }
static int PxOf(NSRect r) { return (int)fmax(8, round(fmax(r.size.width, r.size.height))); }

static void DrawFolder(NSRect r)                                                                                    /* the folder bitmaps of DesktopServices: one per nominal size */
{
	int px = PxOf(r), n = px <= 32 ? 32 : px <= 64 ? 64 : px <= 256 ? 256 : px <= 512 ? 512 : 1024;
	NSImage *i = Picture([NSString stringWithFormat: @"car:DesktopServicesPriv:FolderEmpty%dx%d.png", n, n], px, nil);
	if (i) { DrawPic(i, r); return; }
	NSBezierPath *b = [NSBezierPath bezierPathWithRoundedRect: NSMakeRect(r.origin.x, r.origin.y + 2.5, r.size.width, r.size.height - 4.5) xRadius: 2 yRadius: 2]; [RGB(86, 176, 244) setFill]; [b fill];
}
static void DrawAppIcon(NSRect r)
{
	NSImage *i = Picture(@"set:CoreTypes:GenericApplicationIcon", PxOf(r), nil);
	if (i) DrawPic(i, r); else FillRound(NSInsetRect(r, 1, 1), 4, RGB(120, 130, 140));
}

/* the type declarations of CoreTypes (its Info.plist): extension -> type -> the icon recipe (a background picture, an SF Symbol, a label) up the chain of conformance */
static NSDictionary *IconSpecForExt(NSString *ext)
{
	static NSDictionary *byExt, *byId; static BOOL tried;
	if (!tried) {
		tried = YES; NSMutableDictionary *e = [NSMutableDictionary dictionary], *d = [NSMutableDictionary dictionary]; NSDictionary *info = nil;
		for (NSString *dir in @[ @"/usr/local/share/wsbsd/coreui", @"/root/wsbsd/coreui/assets", @"/System/Library/CoreServices/CoreTypes.bundle/Contents" ]) {
			NSString *f = [dir stringByAppendingPathComponent: [dir hasSuffix: @"Contents"] ? @"Info.plist" : @"CoreTypes-Info.plist"]; NSData *data = [NSData dataWithContentsOfFile: f];
			id pl = data ? [NSPropertyListSerialization propertyListWithData: data options: 0 format: NULL error: NULL] : nil; if ([pl isKindOfClass: [NSDictionary class]]) { info = pl; break; }
		}
		for (NSString *k in @[ @"UTExportedTypeDeclarations", @"UTImportedTypeDeclarations" ]) for (NSDictionary *t in info[k]) {
			NSString *u = t[@"UTTypeIdentifier"]; if (!u) continue; if (!d[u]) d[u] = t;
			id x = t[@"UTTypeTagSpecification"][@"public.filename-extension"]; if ([x isKindOfClass: [NSString class]]) x = @[ x ];
			for (NSString *ex in x) { NSMutableArray *a = e[[ex lowercaseString]]; if (!a) e[[ex lowercaseString]] = a = [NSMutableArray array]; [a addObject: u]; }
		}
		byExt = e; byId = d;
		if (getenv("WSD_PANEL_DEBUG")) NSLog(@"panel types: %lu extensions, %lu types (info %@)", (unsigned long)[e count], (unsigned long)[d count], info ? @"loaded" : @"MISSING");
	}
	NSMutableArray *queue = [NSMutableArray arrayWithArray: byExt[ext] ?: @[]]; NSMutableSet *seen = [NSMutableSet set];
	while ([queue count]) {
		NSString *u = queue[0]; [queue removeObjectAtIndex: 0]; if ([seen containsObject: u]) continue; [seen addObject: u];
		NSDictionary *t = byId[u]; if (!t) continue; NSDictionary *ic = t[@"UTTypeIcons"];
		if ([ic count] && !([ic count] == 1 && ic[@"ISDocumentIconConfiguration"] == nil && ic[@"ISSymbolName"] != nil && NO)) { if (ic[@"ISDocumentIconConfiguration"] || ic[@"UTTypeIconBackgroundName"] || ic[@"UTTypeIconName"] || ic[@"UTTypeIconFile"]) return ic; }
		id c = t[@"UTTypeConformsTo"]; if ([c isKindOfClass: [NSString class]]) c = @[ c ]; [queue addObjectsFromArray: c ?: @[]];
	}
	return nil;
}
/* the generic document of the new look: a page with a folded corner, drawn on the 128-point canvas the system icons use (measured: the page is 86 x 114 at (21, 7), the fold 32 wide) */
static void DrawDocPage(NSRect r)
{
	double s = fmin(r.size.width, r.size.height) / 128.0; NSPoint o = NSMakePoint(NSMidX(r) - 64 * s, NSMidY(r) - 64 * s);
	#define PT(a_, b_) NSMakePoint(o.x + (a_) * s, o.y + (b_) * s)
	NSBezierPath *page = [NSBezierPath bezierPath]; double rad = 3.5;
	[page moveToPoint: PT(21 + rad, 7)]; [page lineToPoint: PT(75, 7)]; [page lineToPoint: PT(106, 38)]; [page lineToPoint: PT(106, 120 - rad)];
	[page curveToPoint: PT(106 - rad, 120) controlPoint1: PT(106, 120 - rad * 0.45) controlPoint2: PT(106 - rad * 0.45, 120)]; [page lineToPoint: PT(21 + rad, 120)];
	[page curveToPoint: PT(21, 120 - rad) controlPoint1: PT(21 + rad * 0.45, 120) controlPoint2: PT(21, 120 - rad * 0.45)]; [page lineToPoint: PT(21, 7 + rad)];
	[page curveToPoint: PT(21 + rad, 7) controlPoint1: PT(21, 7 + rad * 0.45) controlPoint2: PT(21 + rad * 0.45, 7)]; [page closePath];
	if (s > 0.3) { NSBezierPath *sh = [page copy]; NSAffineTransform *t = [NSAffineTransform transform]; [t translateXBy: 0 yBy: 1.2 * s]; [sh transformUsingAffineTransform: t]; [RGBA(0, 0, 0, 0.16) setFill]; [sh fill]; }
	NSGradient *g = [[NSGradient alloc] initWithStartingColor: RGB(236, 236, 238) endingColor: RGB(248, 248, 249)]; [g drawInBezierPath: page angle: 90];
	NSBezierPath *fold = [NSBezierPath bezierPath]; [fold moveToPoint: PT(75, 7)]; [fold lineToPoint: PT(75, 38 - 1)]; [fold lineToPoint: PT(106, 38)]; [fold closePath];
	[RGB(250, 250, 251) setFill]; [fold fill];
	[RGBA(0, 0, 0, 0.10) setStroke]; [fold setLineWidth: fmax(0.5, s * 0.8)]; [fold stroke];
	#undef PT
}
static void DrawDirIcon(NSRect r, NSString *name) { if ([[[name pathExtension] lowercaseString] isEqual: @"app"]) DrawAppIcon(r); else DrawFolder(r); }
static void DrawFileIcon(NSRect ic, NSString *name)
{
	NSString *ext = [[name pathExtension] lowercaseString]; int px = PxOf(ic); NSDictionary *spec = [ext length] ? IconSpecForExt(ext) : nil;
	DrawDocPage(ic); if (px < 12) return;
	NSString *bg = spec[@"UTTypeIconBackgroundName"], *sym = spec[@"ISDocumentIconConfiguration"][@"ISSymbolName"];
	if (getenv("WSD_PANEL_DEBUG")) NSLog(@"panel icon %@ px %d spec %@ bg %@ sym %@", name, px, spec ? @"yes" : @"no", bg, sym);
	if ([bg length]) { NSImage *im = Picture([NSString stringWithFormat: @"set:CoreTypes:%@", [bg hasSuffix: @"_16"] ? [bg substringToIndex: [bg length] - 3] : bg], px, nil); if (im) DrawPic(im, ic); }
	double s = fmin(ic.size.width, ic.size.height) / 128.0; NSPoint c = NSMakePoint(NSMidX(ic), NSMidY(ic));
	if ([sym length]) DrawSymbol(sym, NSMakeRect(c.x - 40 * s, c.y - 40 * s, 80 * s, 80 * s), (CGFloat)(48 * s), RGBA(120, 120, 124, 0.62));
	if (([sym length] || spec[@"ISSymbolTreatment"]) && px >= 40 && [ext length] < 6) {
		NSString *lab = [ext uppercaseString]; NSDictionary *a = Attr((CGFloat)(16.5 * s), YES, RGBA(130, 130, 134, 0.72)); NSSize ts = [lab sizeWithAttributes: a];
		[lab drawAtPoint: NSMakePoint(c.x - ts.width / 2, ic.origin.y + 109 * s - ts.height * 0.80) withAttributes: a];
	}
}

/* ---- the entries of a directory, newest first, in the groups the Mac shows */
/* ---- tags: the names and colours of the Mac's seven, kept the way the Mac keeps them (the extended attribute com.apple.metadata:_kMDItemUserTags, a binary plist of "Name\nColorNumber"), or in ~/Library/Preferences/com.wsbsd.tags.plist where the file system has no attributes */
static NSArray *TagNames(void) { return @[ @"Red", @"Orange", @"Yellow", @"Green", @"Blue", @"Purple", @"Gray" ]; }
static NSColor *TagColor(NSString *n)
{
	static NSDictionary *c; if (!c) c = @{ @"Red": RGB(255, 69, 58), @"Orange": RGB(255, 159, 10), @"Yellow": RGB(255, 214, 10), @"Green": RGB(48, 209, 88), @"Blue": RGB(10, 132, 255), @"Purple": RGB(191, 90, 242), @"Gray": RGB(152, 152, 157) };
	return c[n] ?: RGB(152, 152, 157);
}
static int TagNumber(NSString *n) { static NSDictionary *d; if (!d) d = @{ @"Gray": @1, @"Green": @2, @"Purple": @3, @"Blue": @4, @"Yellow": @5, @"Red": @6, @"Orange": @7 }; return [d[n] intValue]; }
static NSString *TagDBPath(void) { return [NSHomeDirectory() stringByAppendingPathComponent: @"Library/Preferences/com.wsbsd.tags.plist"]; }
static NSArray *TagsOf(NSString *path)
{
	static const char *attr = "com.apple.metadata:_kMDItemUserTags"; NSMutableArray *out = [NSMutableArray array];
#ifdef __FreeBSD__
	char buf[2048]; ssize_t n = extattr_get_file([path fileSystemRepresentation], EXTATTR_NAMESPACE_USER, attr, buf, sizeof buf);
	if (n > 0) { id pl = [NSPropertyListSerialization propertyListWithData: [NSData dataWithBytes: buf length: (NSUInteger)n] options: 0 format: NULL error: NULL]; if ([pl isKindOfClass: [NSArray class]]) { for (NSString *t in pl) { NSString *nm = [[t componentsSeparatedByString: @"\n"] firstObject]; if ([nm length]) [out addObject: nm]; } return out; } }
#endif
	static NSDictionary *db; static NSDate *dbT; NSDate *mt = [[[NSFileManager defaultManager] attributesOfItemAtPath: TagDBPath() error: NULL] fileModificationDate];
	if (!db || (mt && ![mt isEqual: dbT])) { db = [NSDictionary dictionaryWithContentsOfFile: TagDBPath()] ?: @{}; dbT = mt; }
	NSArray *a = db[path]; return a ? [a mutableCopy] : out;
	(void)attr;
}
static NSString *TagIndexPath(void) { return [NSHomeDirectory() stringByAppendingPathComponent: @"Library/Preferences/com.wsbsd.tags.index.plist"]; }
static void IndexTags(NSString *path, NSArray *names)                                                       /* tag -> paths, so a tag can be listed without walking the disk (the Mac asks Spotlight) */
{
	NSMutableDictionary *ix = [[NSDictionary dictionaryWithContentsOfFile: TagIndexPath()] mutableCopy] ?: [NSMutableDictionary dictionary];
	for (NSString *t in TagNames()) { NSMutableArray *a = [ix[t] mutableCopy] ?: [NSMutableArray array]; [a removeObject: path]; if ([names containsObject: t]) [a addObject: path]; ix[t] = a; }
	[[NSFileManager defaultManager] createDirectoryAtPath: [TagIndexPath() stringByDeletingLastPathComponent] withIntermediateDirectories: YES attributes: nil error: NULL]; [ix writeToFile: TagIndexPath() atomically: YES];
}
static void SetTags(NSString *path, NSArray *names)
{
	IndexTags(path, names);
	NSMutableArray *lines = [NSMutableArray array]; for (NSString *n in names) [lines addObject: [NSString stringWithFormat: @"%@\n%d", n, TagNumber(n)]];
#ifdef __FreeBSD__
	NSData *d = [NSPropertyListSerialization dataWithPropertyList: lines format: NSPropertyListBinaryFormat_v1_0 options: 0 error: NULL];
	if (d && extattr_set_file([path fileSystemRepresentation], EXTATTR_NAMESPACE_USER, "com.apple.metadata:_kMDItemUserTags", [d bytes], [d length]) >= 0) return;
#endif
	NSMutableDictionary *db = [[NSDictionary dictionaryWithContentsOfFile: TagDBPath()] mutableCopy] ?: [NSMutableDictionary dictionary];
	if ([names count]) db[path] = names; else [db removeObjectForKey: path];
	[[NSFileManager defaultManager] createDirectoryAtPath: [TagDBPath() stringByDeletingLastPathComponent] withIntermediateDirectories: YES attributes: nil error: NULL];
	[db writeToFile: TagDBPath() atomically: YES];
}
/* the coloured dots after a name: up to four, overlapping, the last on top */
static void DrawTagDots(NSArray *names, double rightEdge, double cy)
{
	int n = (int)fmin([names count], 4); double x = rightEdge - (n > 0 ? 10 + (n - 1) * 6 : 0);
	for (int i = 0; i < n; i++) { NSRect r = NSMakeRect(x + i * 6, cy - 5, 10, 10); [P_CONTENT setFill]; [[NSBezierPath bezierPathWithOvalInRect: NSInsetRect(r, -1, -1)] fill]; [TagColor(names[i]) setFill]; [[NSBezierPath bezierPathWithOvalInRect: r] fill]; }
}
static double TagDotsWidth(NSArray *names) { int n = (int)fmin([names count], 4); return n ? 10 + (n - 1) * 6 : 0; }

@interface WsdEntry : NSObject { @public NSString *name, *path; BOOL dir, enabled; NSDate *date; NSArray *tags; } @end
@implementation WsdEntry @end
static NSString *GroupOf(NSDate *d)
{
	NSCalendar *cal = [NSCalendar currentCalendar]; NSDate *now = [NSDate date]; NSTimeInterval age = [now timeIntervalSinceDate: d];
	NSDateComponents *a = [cal components: NSDayCalendarUnit | NSMonthCalendarUnit | NSYearCalendarUnit fromDate: d], *n = [cal components: NSDayCalendarUnit | NSMonthCalendarUnit | NSYearCalendarUnit fromDate: now];
	if ([a day] == [n day] && [a month] == [n month] && [a year] == [n year]) return @"Today";
	if (age < 2 * 86400 && [a day] != [n day]) return @"Yesterday";
	if (age < 7 * 86400) return @"Previous 7 Days";
	if (age < 30 * 86400) return @"Previous 30 Days";
	NSArray *months = @[ @"January", @"February", @"March", @"April", @"May", @"June", @"July", @"August", @"September", @"October", @"November", @"December" ];
	NSString *m = months[([a month] - 1) % 12];
	return [a year] == [n year] ? m : [NSString stringWithFormat: @"%@ %ld", m, (long)[a year]];
}

static NSString *KindOf(NSString *path, BOOL dir)
{
	if (dir) return @"Folder";
	static NSDictionary *k; if (!k) k = @{ @"pdf": @"PDF document", @"txt": @"Plain text document", @"c": @"C source code", @"h": @"C header", @"m": @"Objective-C source code", @"py": @"Python script", @"md": @"Markdown document", @"png": @"PNG image", @"jpg": @"JPEG image", @"jpeg": @"JPEG image", @"gif": @"GIF image", @"tiff": @"TIFF image", @"zip": @"ZIP archive", @"hex": @"Document", @"elf": @"Unix executable", @"js": @"JavaScript source code", @"json": @"JSON document", @"html": @"HTML document", @"sh": @"Shell script", @"iso": @"Disk image", @"log": @"Log file" };
	return k[[[path pathExtension] lowercaseString]] ?: @"Document";
}
static NSString *SizeText(unsigned long long n)
{
	if (n < 1024) return [NSString stringWithFormat: @"%llu bytes", n];
	if (n < 1024ULL * 1024) return [NSString stringWithFormat: @"%.0f KB", n / 1024.0];
	if (n < 1024ULL * 1024 * 1024) return [NSString stringWithFormat: @"%.1f MB", n / 1048576.0];
	return [NSString stringWithFormat: @"%.2f GB", n / 1073741824.0];
}

/* ---- the preview of a selected file: a picture, the name, the kind and size, Information */
@interface WsdPreview : NSView { @public NSString *path; } @end
@implementation WsdPreview
- (BOOL)isFlipped { return YES; }
- (void)drawRect:(NSRect)dirty
{
	[P_CONTENT setFill]; NSRectFill(dirty); if (!path) return;
	NSFileManager *fm = [NSFileManager defaultManager]; NSDictionary *at = [fm attributesOfItemAtPath: path error: NULL]; double W = [self bounds].size.width;
	NSString *ext = [[path pathExtension] lowercaseString]; NSImage *img = [@[ @"png", @"jpg", @"jpeg", @"gif", @"tiff", @"bmp" ] containsObject: ext] ? [[NSImage alloc] initWithContentsOfFile: path] : nil;
	NSRect th = NSMakeRect(floor((W - 132) / 2) - 2, 11, 132, 188);                                        /* the picture: a page of 132 x 188 */
	if (img && [img size].width > 0) { double k = fmin(132.0 / [img size].width, 188.0 / [img size].height); NSSize z = NSMakeSize([img size].width * k, [img size].height * k); NSRect r = NSMakeRect(NSMidX(th) - z.width / 2, NSMidY(th) - z.height / 2, z.width, z.height); [img drawInRect: r fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1]; }
	else {
		[RGB(250, 250, 250) setFill]; NSRectFill(th); NSString *txt = nil;
		if (![ext isEqual: @"pdf"] && [at fileSize] < 4 * 1024 * 1024) { NSFileHandle *fh = [NSFileHandle fileHandleForReadingAtPath: path]; NSData *dd = [fh readDataOfLength: 2400]; [fh closeFile]; txt = dd.length ? [[NSString alloc] initWithData: dd encoding: NSUTF8StringEncoding] : nil; }
		if ([txt length]) {                                                                                              /* a text file: the first lines, tiny, on the page */
			NSDictionary *ta = @{ NSFontAttributeName: [NSFont userFixedPitchFontOfSize: 4.5], NSForegroundColorAttributeName: RGB(60, 60, 60) }; double y = th.origin.y + 8; int n = 0;
			for (NSString *ln in [txt componentsSeparatedByString: @"\n"]) { if (++n > 38) break; NSString *l = [ln length] > 34 ? [ln substringToIndex: 34] : ln; [l drawAtPoint: NSMakePoint(th.origin.x + 8, y) withAttributes: ta]; y += 4.6; }
		} else { NSRect ic = NSMakeRect(NSMidX(th) - 28, NSMidY(th) - 34, 56, 68); DrawFileIcon(ic, [path lastPathComponent]); }
	}
	Text([path lastPathComponent], NSMakePoint(11, 230 + 7), 15, YES, P_TEXT, YES);
	Text([NSString stringWithFormat: @"%@ - %@", KindOf(path, NO), SizeText([at fileSize])], NSMakePoint(11, 252 + 6), 13, NO, P_DIM, YES);
	Text(@"Information", NSMakePoint(11, 275 + 5), 13, YES, P_TEXT, YES);
	NSDictionary *la = Attr(13, NO, RGB(10, 132, 255)); NSSize ls = [@"Show More" sizeWithAttributes: la]; [@"Show More" drawAtPoint: NSMakePoint(W - 28 - ls.width, 275 + 5 - ls.height / 2) withAttributes: la];
	NSDateFormatter *df = [[NSDateFormatter alloc] init]; [df setDateFormat: @"EEEE, d MMMM yyyy 'at' HH:mm"];
	NSArray *rows = @[ @[ @"Created", [at fileCreationDate] ?: [NSDate date] ], @[ @"Modified", [at fileModificationDate] ?: [NSDate date] ] ]; double y = 299 + 5;
	for (NSArray *r in rows) { [P_LINE setFill]; NSRectFill(NSMakeRect(11, y - 15, W - 24, 1)); Text(r[0], NSMakePoint(11, y + 4), 13, NO, P_DIM, YES); NSString *v = [df stringFromDate: r[1]]; NSDictionary *va = Attr(13, NO, P_TEXT); NSSize vs = [v sizeWithAttributes: va]; [v drawAtPoint: NSMakePoint(W - 28 - vs.width, y + 4 - vs.height / 2) withAttributes: va]; y += 24; }
	Text(@"Tags", NSMakePoint(11, y + 12), 13, YES, P_TEXT, YES); NSArray *tg = TagsOf(path); y += 33;
	if ([tg count]) { DrawTagDots(tg, 11 + TagDotsWidth(tg), y); Text([tg componentsJoinedByString: @", "], NSMakePoint(11 + TagDotsWidth(tg) + 8, y), 13, NO, P_TEXT, YES); }
	else Text(@"Add Tags\u2026", NSMakePoint(11, y), 13, NO, P_DIM, YES);
}
@end

/* ---- one column of the browser */
@class WsdColumn;
@protocol WsdColumnDelegate - (void)column:(WsdColumn *)c clicked:(WsdEntry *)e doubleClick:(BOOL)dbl; @end
@interface WsdColumn : NSView { @public NSString *dir; NSMutableArray *rows; NSInteger selected; BOOL active; id<WsdColumnDelegate> delegate; NSArray *types; BOOL filesOK, dirsOK; NSString *filter; } @end
@implementation WsdColumn
- (BOOL)acceptsFirstResponder { return YES; }
- (BOOL)becomeFirstResponder { active = YES; [self setNeedsDisplay: YES]; return YES; }
- (BOOL)isFlipped { return YES; }
- (void)load
{
	rows = [NSMutableArray array]; NSFileManager *fm = [NSFileManager defaultManager]; NSMutableArray *ents = [NSMutableArray array];
	NSArray *names = nil; NSString *base = dir;
	if ([dir hasPrefix: @"tag://"]) {                                                                                      /* a tag in the sidebar: the files and folders carrying it (three levels under the home folder) */
		NSString *want = [dir substringFromIndex: 6]; NSMutableArray *found = [NSMutableArray array]; NSString *home = NSHomeDirectory(); int visited = 0;
		NSMutableArray *queue = [NSMutableArray arrayWithObject: @""], *depth = [NSMutableArray arrayWithObject: @0];
		for (NSUInteger qi = 0; qi < [queue count] && visited < 4000; qi++) {
			NSString *rel0 = queue[qi]; int dp = [depth[qi] intValue]; int k = 0;
			for (NSString *nm in [fm contentsOfDirectoryAtPath: [home stringByAppendingPathComponent: rel0] error: NULL]) {
				if ([nm hasPrefix: @"."] || (!dp && [nm isEqual: @"Library"])) continue; if (++k > 400 || ++visited > 4000) break;
				NSString *rel = [rel0 stringByAppendingPathComponent: nm], *full = [home stringByAppendingPathComponent: rel]; BOOL d = NO; [fm fileExistsAtPath: full isDirectory: &d];
				if ([TagsOf(full) containsObject: want]) [found addObject: rel];
				if (d && dp < 2) { [queue addObject: rel]; [depth addObject: @(dp + 1)]; }
			}
		}
		names = found; base = home;
	} else if ([dir isEqual: @"recents://"]) {                                                                                  /* Recents: the newest files under the home folder (three levels deep) */
		NSMutableArray *found = [NSMutableArray array]; NSString *home = NSHomeDirectory(); int visited = 0;
		NSMutableArray *queue = [NSMutableArray arrayWithObject: @""], *depth = [NSMutableArray arrayWithObject: @0];       /* breadth first, three levels, at most 400 names of a folder and 4000 in all */
		for (NSUInteger qi = 0; qi < [queue count] && visited < 4000; qi++) {
			NSString *rel0 = queue[qi]; int dp = [depth[qi] intValue]; NSArray *ls = [fm contentsOfDirectoryAtPath: [home stringByAppendingPathComponent: rel0] error: NULL]; int k = 0;
			for (NSString *nm in ls) {
				if ([nm hasPrefix: @"."] || (!dp && [nm isEqual: @"Library"])) continue; if (++k > 400 || ++visited > 4000) break;
				NSString *rel = [rel0 stringByAppendingPathComponent: nm]; BOOL d = NO; [fm fileExistsAtPath: [home stringByAppendingPathComponent: rel] isDirectory: &d];
				if (d) { if (dp < 2) { [queue addObject: rel]; [depth addObject: @(dp + 1)]; } } else [found addObject: rel];
			}
		}
		[found sortUsingComparator: ^NSComparisonResult(NSString *a, NSString *b) { return [[[fm attributesOfItemAtPath: [home stringByAppendingPathComponent: b] error: NULL] fileModificationDate] compare: [[fm attributesOfItemAtPath: [home stringByAppendingPathComponent: a] error: NULL] fileModificationDate] ?: [NSDate distantPast]]; }];
		names = [found count] > 100 ? [found subarrayWithRange: NSMakeRange(0, 100)] : found; base = home;
	} else names = [fm contentsOfDirectoryAtPath: dir error: NULL];
	for (NSString *n in names) {
		if ([[n lastPathComponent] hasPrefix: @"."]) continue;
		if ([filter length] && [n rangeOfString: filter options: NSCaseInsensitiveSearch].location == NSNotFound) continue;
		WsdEntry *e = [WsdEntry new]; e->name = n; e->path = [base stringByAppendingPathComponent: n]; if ([dir isEqual: @"recents://"] || [dir hasPrefix: @"tag://"]) e->name = [n lastPathComponent]; BOOL d = NO; [fm fileExistsAtPath: e->path isDirectory: &d]; e->dir = d;
		e->date = [[fm attributesOfItemAtPath: e->path error: NULL] fileModificationDate] ?: [NSDate distantPast];
		e->tags = TagsOf(e->path); e->enabled = d || (filesOK && (!types.count || [types containsObject: [[n pathExtension] lowercaseString]]));
		[ents addObject: e];
	}
	[ents sortUsingComparator: ^NSComparisonResult(WsdEntry *a, WsdEntry *b) { return [b->date compare: a->date]; }];
	NSString *last = nil;
	for (WsdEntry *e in ents) { NSString *g = GroupOf(e->date); if (![g isEqualToString: last]) { [rows addObject: g]; last = g; } [rows addObject: e]; }
	selected = -1;
	double h = 8; BOOL first = YES; for (id r in rows) { if ([r isKindOfClass: [NSString class]]) { h += first ? 26 : 48; first = NO; } else h += 22; }
	[self setFrameSize: NSMakeSize([self frame].size.width, fmax(h + 8, 40))];
}
- (NSRect)rectOfRow:(NSInteger)i
{
	double y = 0; BOOL first = YES;
	for (NSInteger k = 0; k <= i; k++) {
		id r = rows[k];
		if ([r isKindOfClass: [NSString class]]) { y += first ? 8 : 22; if (k == i) return NSMakeRect(0, y, [self bounds].size.width, 26); y += 26; first = NO; }
		else { if (k == i) return NSMakeRect(0, y, [self bounds].size.width, 22); y += 22; }
	}
	return NSZeroRect;
}
- (void)drawRect:(NSRect)dirty
{
	[P_CONTENT setFill]; NSRectFill(dirty);
	for (NSInteger i = 0; i < (NSInteger)[rows count]; i++) {
		NSRect rr = [self rectOfRow: i]; if (!NSIntersectsRect(rr, dirty)) continue; id r = rows[i];
		if ([r isKindOfClass: [NSString class]]) { Text(r, NSMakePoint(37, NSMinY(rr) + 14), 11, YES, P_HEADER, YES); continue; }
		WsdEntry *e = r; BOOL sel = i == selected; double W = rr.size.width;
		if (sel) { NSColor *sc = active ? RGB(0, 89, 209) : P_SELECT; if (e->dir) FillRound(NSMakeRect(10, NSMinY(rr), W - 20, 22), 7, sc); else { [sc setFill]; NSRectFill(NSMakeRect(0, NSMinY(rr), W, 22)); } }     /* a folder's row is a rounded capsule, a file's runs edge to edge */
		NSRect ic = NSMakeRect(17, NSMinY(rr) + 3, 16, 16);
		if (e->dir) DrawDirIcon(ic, e->name); else DrawFileIcon(ic, e->name);
		NSColor *tc = sel && active ? [NSColor whiteColor] : (e->enabled ? P_TEXT : P_DIM);
		double tdw = TagDotsWidth(e->tags); TextFit(e->name, NSMakePoint(40, NSMidY(rr)), 13, tc, W - 40 - (e->dir ? 30 : 14) - (tdw ? tdw + 16 : 0)); DrawTagDots(e->tags, W - 26, NSMidY(rr));
		if (e->dir) { NSBezierPath *p = [NSBezierPath bezierPath]; double cx = W - 22, cy = NSMidY(rr); [p setLineWidth: 1.3]; [p moveToPoint: NSMakePoint(cx, cy - 3.5)]; [p lineToPoint: NSMakePoint(cx + 3.5, cy)]; [p lineToPoint: NSMakePoint(cx, cy + 3.5)]; [(sel && active ? [NSColor whiteColor] : P_DIM) setStroke]; [p stroke]; }
	}
}
- (void)keyDown:(NSEvent *)ev
{
	NSString *k = [ev characters]; if (![k length]) return; unichar ch = [k characterAtIndex: 0];
	NSInteger n = (NSInteger)[rows count], i = selected;
	if (ch == NSDownArrowFunctionKey || ch == NSUpArrowFunctionKey) {
		NSInteger d = ch == NSDownArrowFunctionKey ? 1 : -1; i = i < 0 ? (d > 0 ? -1 : n) : i;
		for (i += d; i >= 0 && i < n; i += d) if (![rows[i] isKindOfClass: [NSString class]] && ((WsdEntry *)rows[i])->enabled) break;
		if (i < 0 || i >= n) return;
		selected = i; [self scrollRectToVisible: [self rectOfRow: i]]; [self setNeedsDisplay: YES]; [delegate column: self clicked: rows[i] doubleClick: NO];
	} else if (ch == NSRightArrowFunctionKey) [(id)delegate performSelector: @selector(focusNextColumnFrom:) withObject: self];
	else if (ch == NSLeftArrowFunctionKey) [(id)delegate performSelector: @selector(focusPreviousColumnFrom:) withObject: self];
	else [super keyDown: ev];
}
- (void)mouseDown:(NSEvent *)ev
{
	[[self window] makeFirstResponder: self];
	NSPoint p = [self convertPoint: [ev locationInWindow] fromView: nil];
	for (NSInteger i = 0; i < (NSInteger)[rows count]; i++) if (![rows[i] isKindOfClass: [NSString class]] && NSPointInRect(p, [self rectOfRow: i])) {
		WsdEntry *e = rows[i]; if (!e->enabled) return;
		selected = i; [self setNeedsDisplay: YES]; [delegate column: self clicked: e doubleClick: [ev clickCount] >= 2]; return;
	}
}
@end

/* ---- the list: name, size, kind, date added (the expanded Save panel; also the Open panel's list mode) */
@interface WsdListColumn : WsdColumn @end
@implementation WsdListColumn
- (void)drawRect:(NSRect)dirty
{
	[P_CONTENT setFill]; NSRectFill(dirty); double W = [self bounds].size.width;
	NSDateFormatter *df = [[NSDateFormatter alloc] init]; [df setDateFormat: @"d MMM yyyy 'at' HH:mm"];
	for (NSInteger i = 0; i < (NSInteger)[rows count]; i++) {
		NSRect rr = [self rectOfRow: i]; if (!NSIntersectsRect(rr, dirty)) continue; id r = rows[i];
		if ([r isKindOfClass: [NSString class]]) { Text(r, NSMakePoint(40, NSMinY(rr) + 14), 11, YES, P_HEADER, YES); continue; }
		WsdEntry *e = r; BOOL sel = i == selected;
		if (sel) FillRound(NSMakeRect(10, NSMinY(rr), W - 20, 22), 7, active ? RGB(0, 89, 209) : P_SELECT);
		NSColor *tc = sel && active ? [NSColor whiteColor] : (e->enabled ? P_TEXT : P_DIM), *dc = sel && active ? RGBA(255, 255, 255, 0.85) : P_DIM;
		NSRect ic = NSMakeRect(26, NSMinY(rr) + 3, 16, 16); if (e->dir) DrawDirIcon(ic, e->name); else DrawFileIcon(ic, e->name);
		double tdw = TagDotsWidth(e->tags); TextFit(e->name, NSMakePoint(48, NSMidY(rr)), 13, tc, 250 - 48 - 12 - (tdw ? tdw + 6 : 0));
		if (tdw) { double nw = fmin([e->name sizeWithAttributes: Attr(13, NO, tc)].width, 250 - 48 - 12 - tdw - 6); DrawTagDots(e->tags, 48 + nw + 6 + tdw, NSMidY(rr)); }
		NSDictionary *at = [[NSFileManager defaultManager] attributesOfItemAtPath: e->path error: NULL];
		NSString *sz = e->dir ? @"--" : SizeText([at fileSize]); NSDictionary *sa = Attr(13, NO, dc); NSSize ss = [sz sizeWithAttributes: sa]; [sz drawAtPoint: NSMakePoint(341 - ss.width, NSMidY(rr) - ss.height / 2) withAttributes: sa];
		Text(KindOf(e->path, e->dir), NSMakePoint(355, NSMidY(rr)), 13, NO, dc, YES);
		Text([df stringFromDate: e->date], NSMakePoint(469, NSMidY(rr)), 13, NO, dc, YES);
	}
}
@end
/* ---- the icon view: a grid of 96 x 92 cells, the picture above the name */
@interface WsdIconColumn : WsdColumn { NSMutableArray *ents; NSInteger perRow; } @end
@implementation WsdIconColumn
- (void)load
{
	[super load]; ents = [NSMutableArray array]; for (id r in rows) if (![r isKindOfClass: [NSString class]]) [ents addObject: r];
	double W = [self frame].size.width; perRow = (NSInteger)fmax(1, floor((W - 16) / 96)); NSInteger nr = ((NSInteger)[ents count] + perRow - 1) / perRow;
	[self setFrameSize: NSMakeSize(W, fmax(nr * 92 + 24, 60))]; selected = -1;
}
- (NSRect)cell:(NSInteger)k { return NSMakeRect(8 + (k % perRow) * 96, 10 + (k / perRow) * 92, 96, 92); }
- (void)drawRect:(NSRect)dirty
{
	[P_CONTENT setFill]; NSRectFill(dirty);
	for (NSInteger k = 0; k < (NSInteger)[ents count]; k++) {
		NSRect c = [self cell: k]; if (!NSIntersectsRect(c, dirty)) continue; WsdEntry *e = ents[k]; BOOL sel = k == selected;
		NSRect ic = NSMakeRect(NSMidX(c) - 28, c.origin.y + 4, 56, 56);
		if (sel) FillRound(NSInsetRect(ic, -4, -3), 8, active ? RGBA(255, 255, 255, 0.14) : P_SELECT);
		if (e->dir) DrawDirIcon(ic, e->name); else DrawFileIcon(ic, e->name);
		NSDictionary *a = Attr(12, NO, sel && active ? [NSColor whiteColor] : (e->enabled ? P_TEXT : P_DIM)); NSString *nm = e->name;
		if ([nm sizeWithAttributes: a].width > 88) { while ([nm length] > 1 && [[nm stringByAppendingString: @"\u2026"] sizeWithAttributes: a].width > 88) nm = [nm substringToIndex: [nm length] - 1]; nm = [nm stringByAppendingString: @"\u2026"]; }
		NSSize ts = [nm sizeWithAttributes: a]; NSRect lr = NSMakeRect(NSMidX(c) - ts.width / 2 - 5, c.origin.y + 64, ts.width + 10, 18);
		if (sel && active) FillRound(lr, 6, RGB(0, 89, 209));
		[nm drawAtPoint: NSMakePoint(NSMidX(c) - ts.width / 2, lr.origin.y + 9 - ts.height / 2) withAttributes: a]; DrawTagDots(e->tags, NSMidX(c) - ts.width / 2 - 4, lr.origin.y + 9);
	}
}
- (void)mouseDown:(NSEvent *)ev
{
	[[self window] makeFirstResponder: self]; NSPoint p = [self convertPoint: [ev locationInWindow] fromView: nil];
	for (NSInteger k = 0; k < (NSInteger)[ents count]; k++) if (NSPointInRect(p, [self cell: k])) { WsdEntry *e = ents[k]; if (!e->enabled) return; selected = k; [self setNeedsDisplay: YES]; [delegate column: self clicked: e doubleClick: [ev clickCount] >= 2]; return; }
}
- (void)keyDown:(NSEvent *)ev
{
	NSString *k = [ev characters]; if (![k length]) return; unichar ch = [k characterAtIndex: 0]; NSInteger n = (NSInteger)[ents count], i = selected < 0 ? 0 : selected;
	if (ch == NSRightArrowFunctionKey) i++; else if (ch == NSLeftArrowFunctionKey) i--; else if (ch == NSDownArrowFunctionKey) i += perRow; else if (ch == NSUpArrowFunctionKey) i -= perRow; else { [super keyDown: ev]; return; }
	if (i < 0 || i >= n) return; selected = i; [self scrollRectToVisible: [self cell: i]]; [self setNeedsDisplay: YES]; [delegate column: self clicked: ents[i] doubleClick: NO];
}
@end
@interface WsdListHeader : NSView { @public NSString *group; } @end
@implementation WsdListHeader
- (BOOL)isFlipped { return YES; }
- (void)drawRect:(NSRect)dirty
{
	[P_CONTENT setFill]; NSRectFill(dirty); double W = [self bounds].size.width;
	[P_LINE setFill]; NSRectFill(NSMakeRect(0, 25, W, 1));
	Text(group ?: @"", NSMakePoint(40, 13), 11, YES, P_HEADER, YES);
	for (NSNumber *x in @[ @250, @347, @460 ]) NSRectFill(NSMakeRect([x doubleValue], 3, 1, 19));
	Text(@"Size", NSMakePoint(255, 13), 11, YES, P_HEADER, YES); Text(@"Kind", NSMakePoint(353, 13), 11, YES, P_HEADER, YES); Text(@"Date Added", NSMakePoint(467, 13), 11, YES, P_TEXT, YES);
	NSBezierPath *ch = [NSBezierPath bezierPath]; [ch setLineWidth: 1.3]; [ch moveToPoint: NSMakePoint(W - 28, 11)]; [ch lineToPoint: NSMakePoint(W - 24, 15)]; [ch lineToPoint: NSMakePoint(W - 20, 11)]; [P_TEXT setStroke]; [ch stroke];
}
@end

/* ---- the sidebar */
/* ---- the SF Symbols, from the system's own catalogue: CoreGlyphs' Assets.car holds each symbol as a vector glyph ("BVG " container, decoded in coreui/bvg.c the way CoreUI does); drawn here as filled paths at a point size
 * (the glyph's units are points at 13 pt, the size every symbol is designed for) */
@interface WsdGlyph : NSObject { @public NSMutableArray *paths; NSMutableArray *alphas; NSSize size; } @end
@implementation WsdGlyph @end
static NSString *GlyphDir(void)
{
	static NSString *dir; static BOOL done; if (done) return dir; done = YES;
	NSArray *c = @[ @"/usr/local/share/wsbsd/coreui", @"/root/wsbsd/coreui/assets", @"/System/Library/PrivateFrameworks/SFSymbols.framework/Versions/A/Resources/CoreGlyphs.bundle/Contents/Resources" ];
	for (NSString *d in c) for (NSString *f in @[ @"CoreGlyphs.car", @"Assets.car" ]) if ([[NSFileManager defaultManager] fileExistsAtPath: [d stringByAppendingPathComponent: f]]) { dir = d; return dir; }
	return dir;
}
static NSDictionary *GlyphTableW(NSArray *want, int weight)                                                                            /* name -> WsdGlyph, every wanted symbol found in one pass over the catalogue */
{
	static NSMutableDictionary *tables; static NSDictionary *alias; static CarFile *car;
	if (!tables) tables = [NSMutableDictionary dictionary]; static int noCat = -1; if (noCat < 0) noCat = getenv("WSD_NO_SYMBOLS") != NULL;       /* a test aid: behave as an image without the catalogue */
	NSMutableDictionary *table = tables[@(weight)]; if (noCat) return table; if (!table) tables[@(weight)] = table = [NSMutableDictionary dictionary];
	if (!alias) { NSString *d = GlyphDir(); if (!d) return table;
		NSString *f = [d stringByAppendingPathComponent: @"CoreGlyphs.car"]; if (![[NSFileManager defaultManager] fileExistsAtPath: f]) f = [d stringByAppendingPathComponent: @"Assets.car"];
		car = car_open([f fileSystemRepresentation]);
		NSData *ad = [NSData dataWithContentsOfFile: [d stringByAppendingPathComponent: @"name_aliases.strings"]];                      /* a binary property list in spite of the name */
		id pl = ad ? [NSPropertyListSerialization propertyListWithData: ad options: 0 format: NULL error: NULL] : nil; alias = [pl isKindOfClass: [NSDictionary class]] ? pl : @{};
	}
	if (!car) return table;
	NSMutableArray *todo = [NSMutableArray array]; for (NSString *n in want) if (!table[n]) [todo addObject: n];
	if (![todo count]) return table;
	int n = (int)[todo count]; const char **names = calloc((size_t)n, sizeof *names); uint8_t **bufs = calloc((size_t)n, sizeof *bufs); size_t *lens = calloc((size_t)n, sizeof *lens);
	for (int i = 0; i < n; i++) { NSString *nm = alias[todo[i]] ?: todo[i]; names[i] = strdup([nm UTF8String]); }
	car_symbols(car, names, n, weight, bufs, lens);
	for (int i = 0; i < n; i++) {
		BvgGlyph g; WsdGlyph *w = nil;
		if (bufs[i] && !bvg_parse(bufs[i], lens[i], &g)) {
			w = [WsdGlyph new]; w->paths = [NSMutableArray array]; w->alphas = [NSMutableArray array]; double x1 = 0, y1 = 0;
			for (int l = 0; l < g.nlayer; l++) {
				NSBezierPath *p = [NSBezierPath bezierPath]; NSPoint cur = NSZeroPoint;
				for (int k = g.layer[l].first; k < g.layer[l].first + g.layer[l].count; k++) {
					BvgSeg *sg = &g.seg[k];
					switch (sg->op) {
					case 'M': cur = NSMakePoint(sg->p[0], sg->p[1]); [p moveToPoint: cur]; break;
					case 'L': cur = NSMakePoint(sg->p[0], sg->p[1]); [p lineToPoint: cur]; break;
					case 'C': [p curveToPoint: NSMakePoint(sg->p[4], sg->p[5]) controlPoint1: NSMakePoint(sg->p[0], sg->p[1]) controlPoint2: NSMakePoint(sg->p[2], sg->p[3])]; break;
					case 'Z': [p closePath]; break;
					}
					int np = sg->op == 'C' ? 3 : sg->op == 'Z' ? 0 : 1; for (int j = 0; j < np; j++) { if (sg->p[2 * j] > x1) x1 = sg->p[2 * j]; if (sg->p[2 * j + 1] > y1) y1 = sg->p[2 * j + 1]; }
				}
				if (g.layer[l].knockout && [w->paths count]) { [(NSBezierPath *)[w->paths lastObject] appendBezierPath: p]; [[w->paths lastObject] setWindingRule: NSEvenOddWindingRule]; continue; }      /* cut out of the enclosure before it */
				[w->paths addObject: p]; [w->alphas addObject: @(g.layer[l].opacity)];
			}
			w->size = NSMakeSize(x1, y1); bvg_free(&g);
		}
		table[todo[i]] = w ?: (id)[NSNull null]; free(bufs[i]); free((void *)names[i]);
	}
	free(names); free(bufs); free(lens); return table;
}
static NSDictionary *GlyphTable(NSArray *want) { return GlyphTableW(want, 4); }
static NSArray *AllSymbolNames(void) { return @[ @"clock", @"person.2", @"app", @"menubar.dock.rectangle", @"desktopcomputer", @"doc", @"arrow.down.circle", @"icloud", @"house", @"externaldrive", @"internaldrive", @"macwindow", @"a.square", @"folder", @"airplayaudio", @"wifi", @"tag", @"circle", @"magnifyingglass", @"chevron.left", @"chevron.right", @"chevron.down", @"chevron.up.chevron.down", @"square.grid.2x2", @"list.bullet", @"rectangle.split.3x1", @"square.grid.3x1.below.line.grid.1x2", @"sidebar.left", @"apps.iphone", @"rectangle.grid.1x2", @"rectangle.grid.3x2", @"square.and.arrow.down" ]; }
static BOOL DrawSymbol(NSString *name, NSRect cell, CGFloat pointSize, NSColor *tint)                                  /* centred in `cell`; NO when the catalogue has no such symbol */
{
	id g = GlyphTable(AllSymbolNames())[name]; if (!g) g = GlyphTable(@[ name ])[name];
	if (!g || g == [NSNull null]) { extern BOOL WsdFallbackSymbolDraw(NSString *, NSRect, CGFloat, NSColor *); return WsdFallbackSymbolDraw(name, cell, pointSize, tint); }
	WsdGlyph *w = g; double k = pointSize / 13.0; NSAffineTransform *t = [NSAffineTransform transform];
	extern int WsdSymbolFlip; BOOL flipped = WsdSymbolFlip >= 0 ? (WsdSymbolFlip != 0) : [[NSGraphicsContext currentContext] isFlipped];       /* the catalogue's paths run y down: an unflipped view (a menu row) needs them mirrored */
	if (flipped) { [t translateXBy: NSMidX(cell) - w->size.width * k / 2 yBy: NSMidY(cell) - w->size.height * k / 2]; [t scaleBy: (CGFloat)k]; }
	else { [t translateXBy: NSMidX(cell) - w->size.width * k / 2 yBy: NSMidY(cell) + w->size.height * k / 2]; [t scaleXBy: (CGFloat)k yBy: -(CGFloat)k]; }
	for (NSUInteger i = 0; i < [w->paths count]; i++) { NSBezierPath *p = [t transformBezierPath: w->paths[i]]; [p setWindingRule: NSEvenOddWindingRule]; [[tint colorWithAlphaComponent: [tint alphaComponent] * [w->alphas[i] doubleValue]] setFill]; [p fill]; }
	return YES;
}
/* for NSImage's system symbols (WsdSymbolImage.m): the symbol's size in points at `pointSize`, and its drawing in the colour `tint` centred in `cell` */
NSSize WsdSymbolSize(NSString *name, CGFloat pointSize, int weight)
{
	id g = GlyphTableW(@[ name ], weight)[name]; if (!g || g == [NSNull null]) { extern NSSize WsdFallbackSymbolSize(NSString *, CGFloat); return WsdFallbackSymbolSize(name, pointSize); }
	WsdGlyph *w = g; return NSMakeSize(w->size.width * pointSize / 13.0, w->size.height * pointSize / 13.0);
}
BOOL WsdSymbolDraw(NSString *name, NSRect cell, CGFloat pointSize, int weight, NSColor *tint)
{
	id g = GlyphTableW(@[ name ], weight)[name]; if (!g || g == [NSNull null]) { extern BOOL WsdFallbackSymbolDraw(NSString *, NSRect, CGFloat, NSColor *); return WsdFallbackSymbolDraw(name, cell, pointSize, tint); }
	WsdGlyph *w = g; double k = pointSize / 13.0; NSAffineTransform *t = [NSAffineTransform transform];
	extern int WsdSymbolFlip; BOOL flipped = WsdSymbolFlip >= 0 ? (WsdSymbolFlip != 0) : [[NSGraphicsContext currentContext] isFlipped];       /* the catalogue's paths run y down: an unflipped view (a menu row) needs them mirrored */
	if (flipped) { [t translateXBy: NSMidX(cell) - w->size.width * k / 2 yBy: NSMidY(cell) - w->size.height * k / 2]; [t scaleBy: (CGFloat)k]; }
	else { [t translateXBy: NSMidX(cell) - w->size.width * k / 2 yBy: NSMidY(cell) + w->size.height * k / 2]; [t scaleXBy: (CGFloat)k yBy: -(CGFloat)k]; }
	for (NSUInteger i = 0; i < [w->paths count]; i++) { NSBezierPath *p = [t transformBezierPath: w->paths[i]]; [p setWindingRule: NSEvenOddWindingRule]; [[tint colorWithAlphaComponent: [tint alphaComponent] * [w->alphas[i] doubleValue]] setFill]; [p fill]; }
	return YES;
}
static void DrawSideIcon(NSString *name, NSRect r, NSColor *tint)                                              /* the SF Symbols of the sidebar, in the accent colour (grey when the window is not key) */
{
	static NSDictionary *map; if (!map) map = @{ @"Recents": @"clock", @"Shared": @"person.2", @"Applications": @"applications", @"Desktop": @"menubar.dock.rectangle", @"Documents": @"doc", @"Downloads": @"arrow.down.circle", @"Macintosh HD": @"internaldrive", @"Home": @"house", @"iCloud Drive": @"icloud" };
	NSString *sym = map[name] ?: @"folder"; if ([sym isEqual: @"applications"]) sym = @"a.square";
	DrawSymbol(sym, r, 17, tint);
}
@interface WsdSidebar : NSView { @public NSMutableArray *items; NSInteger selected; id target; SEL action; } @end
@implementation WsdSidebar
- (BOOL)isFlipped { return YES; }
- (void)setup
{
	NSString *home = NSHomeDirectory(); items = [NSMutableArray array];
	void (^add)(NSString *, NSString *, NSString *) = ^(NSString *kind, NSString *title, NSString *path) { [items addObject: @{ @"k": kind, @"t": title, @"p": path ?: @"" }]; };
	add(@"item", @"Recents", @"recents://"); add(@"item", @"Shared", @"/Users");
	add(@"head", @"Favorites", nil); add(@"item", @"Applications", @"/Applications"); add(@"item", @"Desktop", [home stringByAppendingPathComponent: @"Desktop"]);
	add(@"item", @"Documents", [home stringByAppendingPathComponent: @"Documents"]); add(@"item", @"Downloads", [home stringByAppendingPathComponent: @"Downloads"]);
	add(@"head", @"Locations", nil); add(@"item", @"Macintosh HD", @"/"); add(@"item", [home lastPathComponent], home);
	add(@"head", @"Tags", nil); for (NSString *t in TagNames()) add(@"tag", t, [@"tag://" stringByAppendingString: t]);
	selected = -1; [self setFrameSize: NSMakeSize(135, NSMaxY([self rectOfItem: (NSInteger)[items count] - 1]) + 12)];
}
- (NSRect)rectOfItem:(NSInteger)i
{
	double y = 11;                                                                                                       /* measured: rows 30 high every 32, a header 24 high with 11 above and 21 to the next row's top */
	for (NSInteger k = 0; k <= i; k++) { BOOL head = [items[k][@"k"] isEqual: @"head"]; if (head) { y += 11; if (k == i) return NSMakeRect(0, y, 135, 24); y += 21; } else { if (k == i) return NSMakeRect(10, y, 108, 30); y += 32; } }
	return NSZeroRect;
}
- (void)drawRect:(NSRect)dirty
{
	[P_SIDEBAR setFill]; NSRectFill(dirty);
	for (NSInteger i = 0; i < (NSInteger)[items count]; i++) {
		NSDictionary *it = items[i]; NSRect r = [self rectOfItem: i]; if (!NSIntersectsRect(r, dirty)) continue;
		if ([it[@"k"] isEqual: @"head"]) { Text(it[@"t"], NSMakePoint(16, NSMidY(r)), 11, YES, P_HEADER, YES); continue; }
		if (i == selected) FillRound(r, 8, P_SELECT);
		NSRect ic = NSMakeRect(18, NSMidY(r) - 8, 18, 16);
		if ([it[@"k"] isEqual: @"tag"]) {
			NSDictionary *cols = @{ @"Red": RGB(255, 69, 58), @"Orange": RGB(255, 159, 10), @"Yellow": RGB(255, 214, 10), @"Green": RGB(48, 209, 88), @"Blue": RGB(10, 132, 255), @"Purple": RGB(191, 90, 242), @"Gray": RGB(152, 152, 157) };
			[cols[it[@"t"]] setFill]; [[NSBezierPath bezierPathWithOvalInRect: NSMakeRect(21, NSMidY(r) - 6, 12, 12)] fill];
		} else DrawSideIcon(it[@"t"] == [NSHomeDirectory() lastPathComponent] || [it[@"p"] isEqual: NSHomeDirectory()] && ![it[@"t"] isEqual: @"Recents"] ? @"Home" : it[@"t"], ic, RGB(64, 156, 255));
		TextFit(it[@"t"], NSMakePoint(46, NSMidY(r)), 13, P_TEXT, 72);
	}
}
- (void)mouseDown:(NSEvent *)ev
{
	NSPoint p = [self convertPoint: [ev locationInWindow] fromView: nil];
	for (NSInteger i = 0; i < (NSInteger)[items count]; i++) if (![items[i][@"k"] isEqual: @"head"] && NSPointInRect(p, [self rectOfItem: i])) { selected = i; [self setNeedsDisplay: YES]; [target performSelector: action withObject: items[i][@"p"]]; return; }
}
@end

/* ---- the toolbar: back / forward, view mode, grouping, the path pop-up, the search field */
@interface WsdToolbar : NSView { @public id target; BOOL canBack, canFwd, compact; int mode; NSString *pathTitle; NSTextField *search; } @end
@implementation WsdToolbar
- (BOOL)isFlipped { return YES; }
- (void)drawRect:(NSRect)dirty
{
	[P_CONTENT setFill]; NSRectFill([self bounds]);
	[P_LINE setFill]; NSRectFill(NSMakeRect(0, 63, [self bounds].size.width, 1));
	double x0 = 20;                                                                                               /* measured in the panel's own coordinates minus the sidebar (135) */
	FillRound(NSMakeRect(x0, 20, 50, 24), 8, P_CONTROL);
	[(PDark() ? RGBA(255, 255, 255, 0.16) : RGBA(0, 0, 0, 0.14)) setFill]; NSRectFill(NSMakeRect(x0 + 25, 26, 1, 12));                       /* the divider of the segmented back / forward control */
	DrawSymbol(@"chevron.left", NSMakeRect(x0, 20, 25, 24), 13, canBack ? P_TEXT : P_DIM); DrawSymbol(@"chevron.right", NSMakeRect(x0 + 25, 20, 25, 24), 13, canFwd ? P_TEXT : P_DIM);
	FillRound(NSMakeRect(76, 20, 66, 24), 8, P_CONTROL); FillRound(NSMakeRect(150, 20, 66, 24), 8, P_CONTROL);                      /* the view mode and the grouping, each with a pop-up arrow */
	DrawSymbol(mode == 1 || compact ? @"list.bullet" : mode == 0 ? @"square.grid.2x2" : @"rectangle.split.3x1", NSMakeRect(86, 20, 24, 24), 14, P_TEXT); DrawSymbol(@"square.grid.3x1.below.line.grid.1x2", NSMakeRect(160, 20, 24, 24), 14, P_TEXT);
	DrawSymbol(@"chevron.down", NSMakeRect(118, 20, 16, 24), 9, P_TEXT); DrawSymbol(@"chevron.down", NSMakeRect(192, 20, 16, 24), 9, P_TEXT);
	double px = compact ? 224 : 258, pw = compact ? 198 : 229, sx = compact ? 462 : 529, sw = compact ? 195 : 196;
	NSRect pp = NSMakeRect(px, 20, pw, 24); FillRound(pp, 8, P_CONTROL);                                         /* the path pop-up: a folder, the name, the up / down arrows */
	DrawFolder(NSMakeRect(px + 10, 26, 14, 12)); Text(pathTitle ?: @"", NSMakePoint(px + 29, 32), 13, NO, P_TEXT, YES);
	DrawSymbol(@"chevron.up.chevron.down", NSMakeRect(NSMaxX(pp) - 24, 20, 16, 24), 9, P_TEXT);
	if (compact) { FillRound(NSMakeRect(430, 20, 22, 24), 8, P_CONTROL); DrawSymbol(@"chevron.down", NSMakeRect(430, 20, 22, 24), 10, P_TEXT); }   /* the button that folds the browser away */
	(void)sw; (void)sx;
}
- (void)mouseDown:(NSEvent *)ev
{
	NSPoint p = [self convertPoint: [ev locationInWindow] fromView: nil];
	if (NSPointInRect(p, NSMakeRect(20, 20, 25, 24)) && canBack) [target performSelector: @selector(goBack)];
	else if (NSPointInRect(p, NSMakeRect(45, 20, 25, 24)) && canFwd) [target performSelector: @selector(goForward)];
	else if (NSPointInRect(p, NSMakeRect(compact ? 224 : 258, 20, compact ? 198 : 229, 24))) [target performSelector: @selector(showPathMenu:) withObject: [NSValue valueWithPoint: NSMakePoint(compact ? 359 : 393, 44)]];
	else if (compact && NSPointInRect(p, NSMakeRect(430, 20, 22, 24))) [target performSelector: @selector(toggleExpanded)];
	else if (NSPointInRect(p, NSMakeRect(76, 20, 66, 24)) && !compact) [target performSelector: @selector(showViewMenu)];
}
@end

/* ---- the panel's content: the rounded background, the browser, the bottom bar, or the Save form */
/* the three window buttons of the expanded Save panel, over the sidebar */
@interface WsdLights : NSView { @public BOOL show; } @end
@implementation WsdLights
- (BOOL)isFlipped { return YES; }
- (BOOL)isOpaque { return NO; }
- (NSView *)hitTest:(NSPoint)p { return nil; }
- (void)drawRect:(NSRect)r { if (!show) return; for (int k = 0; k < 3; k++) { [(k == 0 ? RGB(255, 95, 87) : k == 1 ? RGB(254, 188, 46) : RGB(40, 200, 64)) setFill]; [[NSBezierPath bezierPathWithOvalInRect: NSMakeRect(8 + k * 24, 11, 13, 13)] fill]; } }
@end

/* the window's rounded corners: the views inside are square, this view on top cuts the corners out */
@interface WsdCorners : NSView { @public double radius; } @end
@implementation WsdCorners
- (BOOL)isFlipped { return YES; }
- (BOOL)isOpaque { return NO; }
- (NSView *)hitTest:(NSPoint)p { return nil; }
- (void)drawRect:(NSRect)r
{
	NSRect b = [self bounds]; double R = radius; NSGraphicsContext *g = [NSGraphicsContext currentContext]; [g saveGraphicsState]; [g setCompositingOperation: NSCompositeCopy];
	for (int k = 0; k < 4; k++) {
		double x = (k & 1) ? NSMaxX(b) : 0, y = (k & 2) ? NSMaxY(b) : 0, sx = (k & 1) ? -1 : 1, sy = (k & 2) ? -1 : 1;
		NSBezierPath *p = [NSBezierPath bezierPath]; [p moveToPoint: NSMakePoint(x, y)]; [p lineToPoint: NSMakePoint(x + sx * R, y)];
		for (int a = 0; a <= 16; a++) { double t = a / 16.0 * M_PI / 2; [p lineToPoint: NSMakePoint(x + sx * (R - R * sin(t)), y + sy * (R - R * cos(t)))]; }
		[p closePath]; [[NSColor clearColor] setFill]; [p fill];
	}
	[g restoreGraphicsState];
}
@end

@interface WsdPanelController : NSObject <WsdColumnDelegate> {
	@public NSPanel *win; NSView *root; WsdSidebar *sidebar; WsdToolbar *toolbar; NSMutableArray *cols; NSString *dir; NSMutableArray *history; NSInteger hpos;
	NSView *corners; WsdPreview *preview; int viewMode; NSString *listDir; BOOL expanded; NSString *saveDir, *savedName, *okTitle; NSScrollView *listScroll; WsdColumn *listView; WsdListHeader *listHeader; NSButton *newFolder; NSString *searchText; BOOL isSave, filesOK, dirsOK, multiple; NSArray *types; NSString *chosen; NSButton *ok, *cancel; NSTextField *nameField; WsdTagField *tagField; NSInteger result; NSString *message, *prompt;
}
@end
/* ---- a pop-up menu: a small window of its own next to the panel (GNUstep's own pop-up windows come out far too big under this window server); it works while the panel is modal, closes when it loses the key or is picked from */
@interface WsdPopupWindow : NSPanel @end
@implementation WsdPopupWindow
- (BOOL)canBecomeKeyWindow { return NO; }
- (BOOL)worksWhenModal { return YES; }
@end
@class WsdPopup;
@interface WsdPopupCatcher : NSView { @public WsdPopup *popup; } @end
@interface WsdPopup : NSView { NSArray *rows; NSInteger hoverDot; NSArray *titles, *dots; NSIndexSet *checks; NSInteger checked, hover; void (^pick)(NSInteger); NSWindow *parent, *owned; WsdPopupCatcher *catcher; }
- (void)finish:(NSInteger)i; - (void)keyDown:(NSEvent *)e;
+ (void)showIn:(NSView *)root titles:(NSArray *)t checked:(NSInteger)c at:(NSPoint)p pick:(void (^)(NSInteger))block;
+ (void)showIn:(NSView *)root titles:(NSArray *)t dots:(NSArray *)d at:(NSPoint)p pick:(void (^)(NSInteger))block;
+ (void)showIn:(NSView *)root titles:(NSArray *)t dots:(NSArray *)d checks:(NSIndexSet *)c at:(NSPoint)p pick:(void (^)(NSInteger))block;
+ (void)showIn:(NSView *)root rows:(NSArray *)r at:(NSPoint)p pick:(void (^)(NSInteger))block;
@end
static NSIndexSet *gPendingChecks; static NSArray *gPendingRows;
static double RowH(NSDictionary *r) { return [r[@"sep"] boolValue] ? 11 : r[@"dots"] ? 30 : 24; }
@implementation WsdPopup
+ (void)showIn:(NSView *)root titles:(NSArray *)t checked:(NSInteger)c at:(NSPoint)p pick:(void (^)(NSInteger))block { [self showIn: root titles: t dots: nil checked: c at: p pick: block]; }
+ (void)showIn:(NSView *)root titles:(NSArray *)t dots:(NSArray *)d at:(NSPoint)p pick:(void (^)(NSInteger))block { [self showIn: root titles: t dots: d checked: -1 at: p pick: block]; }
+ (void)showIn:(NSView *)root rows:(NSArray *)r at:(NSPoint)p pick:(void (^)(NSInteger))block { NSMutableArray *t = [NSMutableArray array]; for (NSDictionary *x in r) [t addObject: [x[@"sep"] boolValue] ? @"-" : (x[@"t"] ?: @"")]; gPendingRows = r; [self showIn: root titles: t dots: nil checked: -1 at: p pick: block]; }
+ (void)showIn:(NSView *)root titles:(NSArray *)t dots:(NSArray *)d checks:(NSIndexSet *)c at:(NSPoint)p pick:(void (^)(NSInteger))block { gPendingChecks = c; [self showIn: root titles: t dots: d checked: -1 at: p pick: block]; }
+ (void)showIn:(NSView *)root titles:(NSArray *)t dots:(NSArray *)d checked:(NSInteger)c at:(NSPoint)p pick:(void (^)(NSInteger))block
{
	NSArray *rws = gPendingRows; gPendingRows = nil; double w = 60; double h = 10;
	if (rws) { w = 200; for (NSDictionary *r in rws) { h += RowH(r); if (r[@"t"]) w = fmax(w, [r[@"t"] sizeWithAttributes: Attr(13, NO, P_TEXT)].width + ([r[@"sym"] length] ? 76 : 56)); if (r[@"dots"]) w = fmax(w, 14 + 22 * (double)[r[@"dots"] count] + 14); } }
	else for (NSString *s in t) { if ([s isEqual: @"-"]) { h += 9; continue; } w = fmax(w, [s sizeWithAttributes: Attr(13, NO, P_TEXT)].width + 44); h += 24; }
	NSPoint scr = [[root window] convertBaseToScreen: [root convertPoint: p toView: nil]];
	WsdPopup *v = [[WsdPopup alloc] initWithFrame: NSMakeRect(0, 0, w, h)]; v->rows = rws; v->titles = t; v->dots = d; v->checked = c; v->hoverDot = -1; v->checks = gPendingChecks; gPendingChecks = nil; v->hover = -1; v->pick = block; v->parent = [root window];
	WsdPopupWindow *win = [[WsdPopupWindow alloc] initWithContentRect: NSMakeRect(scr.x, scr.y - h, w, h) styleMask: NSBorderlessWindowMask backing: NSBackingStoreBuffered defer: NO];
	[win setOpaque: NO]; [win setBackgroundColor: [NSColor clearColor]]; [win setReleasedWhenClosed: NO]; [win setLevel: NSPopUpMenuWindowLevel]; [win setContentView: v]; [win setAcceptsMouseMovedEvents: YES];
	WsdPopupCatcher *cat = [[WsdPopupCatcher alloc] initWithFrame: [root bounds]]; cat->popup = v; v->catcher = cat; [root addSubview: cat]; [[root window] makeFirstResponder: cat];
	v->owned = win;                                                                                              /* kept alive until the menu is done (the window holds the view, the view holds the window: a cycle broken in -finish:) */
	[win orderFront: nil]; RoundWindow(win, 10); if (getenv("WSD_PANEL_DEBUG")) NSLog(@"popup window %ld at %@ visible %d", (long)[win windowNumber], NSStringFromRect([win frame]), [win isVisible]);
}
- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstResponder { return YES; }
- (BOOL)acceptsFirstMouse:(NSEvent *)e { return YES; }
- (NSRect)rowRect:(NSInteger)i { if (rows) { double y = 5; for (NSInteger k = 0; k < i; k++) y += RowH(rows[k]); return NSMakeRect(5, y, [self bounds].size.width - 10, RowH(rows[i])); } double y = 5; for (NSInteger k = 0; k < i; k++) y += [titles[k] isEqual: @"-"] ? 9 : 24; return NSMakeRect(5, y, [self bounds].size.width - 10, [titles[i] isEqual: @"-"] ? 9 : 24); }
- (void)drawRect:(NSRect)dirty
{
	NSRect box = [self bounds]; FillRound(box, 10, PDark() ? RGBA(54, 60, 68, 0.98) : RGBA(246, 246, 248, 0.98));
	[(PDark() ? RGBA(255, 255, 255, 0.14) : RGBA(0, 0, 0, 0.12)) setStroke]; NSBezierPath *o = [NSBezierPath bezierPathWithRoundedRect: NSInsetRect(box, 0.5, 0.5) xRadius: 10 yRadius: 10]; [o setLineWidth: 1]; [o stroke];
	if (rows) { for (NSInteger i = 0; i < (NSInteger)[rows count]; i++) { NSDictionary *rw = rows[i]; NSRect r = [self rowRect: i];
			if ([rw[@"sep"] boolValue]) { [(PDark() ? RGBA(255, 255, 255, 0.14) : RGBA(0, 0, 0, 0.12)) setFill]; NSRectFill(NSMakeRect(r.origin.x + 6, NSMidY(r), r.size.width - 12, 1)); continue; }
			if (rw[@"dots"]) { NSArray *cs = rw[@"dots"]; for (NSInteger k = 0; k < (NSInteger)[cs count]; k++) { NSRect dr = NSMakeRect(r.origin.x + 9 + k * 22 + 2, NSMidY(r) - 7, 14, 14); if (k == hoverDot) { [RGBA(255, 255, 255, 0.25) setFill]; [[NSBezierPath bezierPathWithOvalInRect: NSInsetRect(dr, -3, -3)] fill]; } [cs[k] setFill]; [[NSBezierPath bezierPathWithOvalInRect: dr] fill]; } continue; }
			BOOL dim = [rw[@"dim"] boolValue]; if (i == hover && !dim) FillRound(r, 5, RGB(10, 132, 255)); NSColor *tc = dim ? P_DIM : (i == hover ? RGB(255, 255, 255) : P_TEXT); double tx = r.origin.x + 10;
			if ([rw[@"sym"] length]) { WsdSymbolDraw(rw[@"sym"], NSMakeRect(r.origin.x + 8, NSMidY(r) - 9, 18, 18), 12, 4, tc); tx = r.origin.x + 30; } if ([rw[@"check"] boolValue]) { Text(@"✓", NSMakePoint(r.origin.x + 8, NSMidY(r)), 12, YES, tc, YES); tx = r.origin.x + 26; }
			Text(rw[@"t"], NSMakePoint(tx, NSMidY(r)), 13, NO, tc, YES); if ([rw[@"sub"] boolValue]) WsdSymbolDraw(@"chevron.right", NSMakeRect(NSMaxX(r) - 24, NSMidY(r) - 8, 16, 16), 9, 5, tc); }
		return; }
	for (NSInteger i = 0; i < (NSInteger)[titles count]; i++) {
		NSRect r = [self rowRect: i]; if ([titles[i] isEqual: @"-"]) { [(PDark() ? RGBA(255, 255, 255, 0.14) : RGBA(0, 0, 0, 0.12)) setFill]; NSRectFill(NSMakeRect(r.origin.x + 6, NSMidY(r), r.size.width - 12, 1)); continue; } if (i == hover) FillRound(r, 5, RGB(10, 132, 255));
		NSColor *tc = i == hover ? RGB(255, 255, 255) : P_TEXT; if (i == checked || [checks containsIndex: (NSUInteger)i]) Text(@"✓", NSMakePoint(r.origin.x + 8, NSMidY(r)), 12, YES, tc, YES);
		if (dots && dots[i] != [NSNull null]) { [dots[i] setFill]; [[NSBezierPath bezierPathWithOvalInRect: NSMakeRect(r.origin.x + 8, NSMidY(r) - 5, 10, 10)] fill]; }
		Text(titles[i], NSMakePoint(r.origin.x + 26, NSMidY(r)), 13, NO, tc, YES);
	}
}
- (NSInteger)rowAt:(NSPoint)p { for (NSInteger i = 0; i < (NSInteger)[titles count]; i++) { if ([titles[i] isEqual: @"-"] || (rows && [rows[i][@"dim"] boolValue])) continue; if (NSPointInRect(p, [self rowRect: i])) { if (rows && rows[i][@"dots"]) { NSRect r = [self rowRect: i]; NSInteger k = (NSInteger)floor((p.x - r.origin.x - 9) / 22); if (k >= 0 && k < (NSInteger)[rows[i][@"dots"] count]) return 1000 + k; return -1; } return i; } } return -1; }
- (void)mouseMoved:(NSEvent *)e { NSInteger h = [self rowAt: [self convertPoint: [e locationInWindow] fromView: nil]]; NSInteger hd = h >= 1000 ? h - 1000 : -1; if (h >= 1000) h = -1; if (h != hover || hd != hoverDot) { hover = h; hoverDot = hd; [self setNeedsDisplay: YES]; } }
- (void)mouseDragged:(NSEvent *)e { [self mouseMoved: e]; }
- (void)mouseDown:(NSEvent *)e { [self mouseMoved: e]; NSInteger i = [self rowAt: [self convertPoint: [e locationInWindow] fromView: nil]]; if (i >= 0) [self finish: i]; }      /* picks on the press: a release does not reach a window of a modal session here */
- (void)finish:(NSInteger)i
{
	if (getenv("WSD_PANEL_DEBUG")) NSLog(@"popup finish %ld", (long)i);
	void (^cb)(NSInteger) = pick; pick = nil; [catcher removeFromSuperview]; catcher = nil; [[self window] orderOut: nil]; owned = nil;
	if (i >= 0 && cb) cb(i);
}
- (void)mouseUp:(NSEvent *)e { NSInteger i = [self rowAt: [self convertPoint: [e locationInWindow] fromView: nil]]; if (i >= 0) [self finish: i]; }
- (void)keyDown:(NSEvent *)e
{
	NSString *c = [e characters]; if ([c isEqual: @"\033"]) { [self finish: -1]; return; }
	NSInteger n = (NSInteger)[titles count]; unichar ch = [c length] ? [c characterAtIndex: 0] : 0;
	if (ch == NSDownArrowFunctionKey) hover = (hover + 1) % n; else if (ch == NSUpArrowFunctionKey) hover = hover <= 0 ? n - 1 : hover - 1;
	else if ((ch == '\r' || ch == '\n') && hover >= 0) { [self finish: hover]; return; }
	[self setNeedsDisplay: YES];
}
@end
@implementation WsdPopupCatcher
- (BOOL)acceptsFirstResponder { return YES; }
- (void)mouseDown:(NSEvent *)e { [popup finish: -1]; }
- (void)keyDown:(NSEvent *)e { [popup keyDown: e]; }
@end
/* ---- the Tags field of the Save panel: the chosen tags as tokens (a dot and the name); a click opens the list of the tags to choose from */
@interface WsdTagField : NSView { @public NSMutableArray *chosen; } @end
@implementation WsdTagField
- (BOOL)isFlipped { return YES; }
- (instancetype)initWithFrame:(NSRect)f { if ((self = [super initWithFrame: f])) chosen = [NSMutableArray array]; return self; }
- (void)drawRect:(NSRect)dirty
{
	NSRect b = NSInsetRect([self bounds], 0.5, 0.5); FillRound(b, 6, P_FIELD); [(PDark() ? RGBA(255, 255, 255, 0.10) : RGBA(0, 0, 0, 0.14)) setStroke]; NSBezierPath *o = [NSBezierPath bezierPathWithRoundedRect: b xRadius: 6 yRadius: 6]; [o setLineWidth: 1]; [o stroke];
	double x = 7; for (NSString *t in chosen) {
		NSDictionary *a = Attr(12, NO, P_TEXT); NSSize ts = [t sizeWithAttributes: a]; NSRect pill = NSMakeRect(x, 4, ts.width + 26, 18);
		FillRound(pill, 9, PDark() ? RGBA(255, 255, 255, 0.12) : RGBA(0, 0, 0, 0.08)); [TagColor(t) setFill]; [[NSBezierPath bezierPathWithOvalInRect: NSMakeRect(x + 6, 8, 10, 10)] fill];
		[t drawAtPoint: NSMakePoint(x + 20, 13 - ts.height / 2) withAttributes: a]; x += pill.size.width + 4;
	}
}
- (void)mouseDown:(NSEvent *)e
{
	NSMutableArray *names = [NSMutableArray array], *dots = [NSMutableArray array]; for (NSString *t in TagNames()) if (![chosen containsObject: t]) { [names addObject: t]; [dots addObject: TagColor(t)]; }
	if (![names count]) return; NSView *root = [[self window] contentView]; NSPoint at = [root convertPoint: NSMakePoint(0, [self bounds].size.height + 2) fromView: self];
	__weak WsdTagField *me = self; [WsdPopup showIn: root titles: names dots: dots at: at pick: ^(NSInteger k) { WsdTagField *f = me; if (getenv("WSD_PANEL_DEBUG")) NSLog(@"tag picked %ld field %@", (long)k, f); if (!f) return; [f->chosen addObject: names[k]]; [f setNeedsDisplay: YES]; }];
}
@end
@interface WsdRoot : NSView { @public BOOL saveForm, expanded; id owner; NSString *whereTitle; } @end
@implementation WsdRoot
- (BOOL)isFlipped { return YES; }
- (void)drawRect:(NSRect)r
{
	[[NSColor clearColor] set]; NSRectFillUsingOperation(r, NSCompositeCopy); FillRound([self bounds], saveForm ? 18 : 22, P_CONTENT);
	if (!saveForm) return;
	if (expanded) {                                                                                                   /* the Save panel with its browser: the window buttons, the title, the labels of the fields */
		Text(@"Save", NSMakePoint(150, 16), 13, YES, P_DIM, YES);
		NSDictionary *la = Attr(13, NO, P_DIM); NSSize s1 = [@"Save As:" sizeWithAttributes: la], s2 = [@"Tags:" sizeWithAttributes: la];
		Text(@"Save As:", NSMakePoint(353 - s1.width, 54), 13, NO, P_DIM, YES); Text(@"Tags:", NSMakePoint(353 - s2.width, 92), 13, NO, P_DIM, YES);
		[P_LINE setFill]; NSRectFill(NSMakeRect(135, 271, [self bounds].size.width - 135, 1));
		return;
	}
	NSRect pp = NSMakeRect(100, 116, 198, 24); FillRound(pp, 8, P_CONTROL); FillRound(NSMakeRect(308, 116, 22, 24), 8, P_CONTROL);   /* Where: the folder pop-up and the button that expands the browser */
	DrawFolder(NSMakeRect(110, 122, 14, 12)); Text(whereTitle ?: @"", NSMakePoint(129, 128), 13, NO, P_TEXT, YES);
	for (int k = 0; k < 2; k++) { NSBezierPath *p = [NSBezierPath bezierPath]; [p setLineWidth: 1.2]; double cx = NSMaxX(pp) - 14, cy = k ? 131 : 125; [p moveToPoint: NSMakePoint(cx - 3, cy + (k ? -2 : 2))]; [p lineToPoint: NSMakePoint(cx, cy + (k ? 1 : -1))]; [p lineToPoint: NSMakePoint(cx + 3, cy + (k ? -2 : 2))]; [P_TEXT setStroke]; [p stroke]; }
	NSBezierPath *ch = [NSBezierPath bezierPath]; [ch setLineWidth: 1.4]; [ch moveToPoint: NSMakePoint(314, 126)]; [ch lineToPoint: NSMakePoint(319, 130)]; [ch lineToPoint: NSMakePoint(324, 126)]; [P_TEXT setStroke]; [ch stroke];
}
- (void)mouseDown:(NSEvent *)ev
{
	if (!saveForm || expanded) return;
	NSPoint p = [self convertPoint: [ev locationInWindow] fromView: nil];
	if (NSPointInRect(p, NSMakeRect(308, 116, 22, 24))) { [owner performSelector: @selector(toggleExpanded)]; return; }
	if (NSPointInRect(p, NSMakeRect(100, 116, 198, 24))) [owner performSelector: @selector(showPathMenu:) withObject: [NSValue valueWithPoint: p]];
}
@end

@implementation WsdPanelController
- (void)column:(WsdColumn *)c clicked:(WsdEntry *)e doubleClick:(BOOL)dbl
{
	if (!isSave && c == listView) {                                                                                       /* the list or icons of the Open panel */
		chosen = e->path; if (e->dir && dbl) { [self openListGo: e->path push: YES]; return; }
		if (dbl && ((e->dir && dirsOK) || (!e->dir && filesOK))) [self accept: nil]; [self refresh]; return;
	}
	if (isSave) {                                                                                                          /* the list of the expanded Save panel */
		if (e->dir) { if (dbl) [self saveGo: e->path push: YES]; } else { [nameField setStringValue: e->name]; if (dbl) [self accept: nil]; }
		[self refresh]; return;
	}
	NSInteger idx = [cols indexOfObject: c];
	for (WsdColumn *x in cols) x->active = (x == c);
	while ((NSInteger)[cols count] > idx + 1) { NSScrollView *sv = [[cols lastObject] enclosingScrollView]; [sv setDocumentView: nil]; [sv removeFromSuperview]; [cols removeLastObject]; }
	chosen = e->path; if (preview) { [preview removeFromSuperview]; preview = nil; }
	if (!e->dir) { preview = [[WsdPreview alloc] initWithFrame: NSMakeRect(0, 0, 400, 300)]; preview->path = e->path; [root addSubview: preview]; [self layoutColumns]; }
	if (e->dir) {
		if (dbl && !dirsOK) { [self navigate: e->path push: YES]; return; }
		[self addColumnFor: e->path];
	}
	if (dbl && ((e->dir && dirsOK) || (!e->dir && filesOK))) [self accept: nil];
	if (isSave && !e->dir) [nameField setStringValue: e->name];
	[self refresh];
}
- (void)focusNextColumnFrom:(WsdColumn *)c
{
	NSInteger i = [cols indexOfObject: c]; if (i + 1 >= (NSInteger)[cols count]) return; WsdColumn *n = cols[i + 1]; if (![n->rows count]) return;
	for (NSInteger k = 0; k < (NSInteger)[n->rows count]; k++) if (![n->rows[k] isKindOfClass: [NSString class]]) { n->selected = k; break; }
	[win makeFirstResponder: n]; for (WsdColumn *x in cols) { x->active = (x == n); [x setNeedsDisplay: YES]; } if (n->selected >= 0) [self column: n clicked: n->rows[n->selected] doubleClick: NO];
}
- (void)focusPreviousColumnFrom:(WsdColumn *)c
{
	NSInteger i = [cols indexOfObject: c]; if (i <= 0) return; WsdColumn *p = cols[i - 1]; [win makeFirstResponder: p]; for (WsdColumn *x in cols) { x->active = (x == p); [x setNeedsDisplay: YES]; }
}
- (void)addColumnFor:(NSString *)path
{
	WsdColumn *c = [[WsdColumn alloc] initWithFrame: NSMakeRect(0, 0, 244, 100)]; c->dir = path; c->types = types; c->filesOK = filesOK || isSave; c->dirsOK = dirsOK; c->delegate = self; c->filter = searchText; [c load];
	[cols addObject: c]; [self layoutColumns];
}
- (void)layoutColumns
{
	WsdRoot *rv = (WsdRoot *)root; double areaW = [rv bounds].size.width - 135, w = 244; NSInteger n = [cols count] + (preview ? 2 : 0), vis = (NSInteger)(areaW / (w + 1)); NSInteger first = n > vis ? n - vis : 0;
	for (NSInteger i = 0; i < (NSInteger)[cols count]; i++) {
		WsdColumn *c = cols[i]; NSScrollView *sv = (NSScrollView *)[c enclosingScrollView];
		if (!sv) { sv = [[NSScrollView alloc] initWithFrame: NSZeroRect]; [sv setHasVerticalScroller: YES]; [sv setBorderType: NSNoBorder]; [sv setAutohidesScrollers: YES]; [sv setDrawsBackground: NO]; [sv setDocumentView: c]; [rv addSubview: sv]; }
		[sv setHidden: i < first]; [sv setFrame: NSMakeRect(135 + (i - first) * w, 64, w, [rv bounds].size.height - 64 - 66)]; [c setFrameSize: NSMakeSize(w, [c frame].size.height)];
	}
	if (preview) { NSInteger at = (NSInteger)[cols count] - first; [preview setFrame: NSMakeRect(135 + at * w, 64, [rv bounds].size.width - (135 + at * w), [rv bounds].size.height - 64 - 66)]; [preview setNeedsDisplay: YES]; }
	[rv setNeedsDisplay: YES];
}
- (void)navigate:(NSString *)path push:(BOOL)push
{
	if (!path) return;
	if (push) { while ((NSInteger)[history count] > hpos + 1) [history removeLastObject]; [history addObject: path]; hpos = (NSInteger)[history count] - 1; }
	if (preview) { [preview removeFromSuperview]; preview = nil; }
	for (WsdColumn *c in cols) { NSScrollView *sv = [c enclosingScrollView]; [sv setDocumentView: nil]; [sv removeFromSuperview]; } [cols removeAllObjects];
	dir = path; [self addColumnFor: path]; ((WsdColumn *)cols[0])->active = YES; chosen = nil; [self refresh];
}
/* ---- the Save panel: compact (the form) or expanded (the form above a list of the folder) */
- (void)saveGo:(NSString *)path push:(BOOL)push
{
	if (!path) return;
	if (push) { while ((NSInteger)[history count] > hpos + 1) [history removeLastObject]; [history addObject: path]; hpos = (NSInteger)[history count] - 1; }
	saveDir = path; [self reloadList]; [self refresh];
}
- (void)reloadList
{
	if (!expanded || !listView) return;
	listView->dir = saveDir; listView->filter = searchText; [listView load]; [listView setNeedsDisplay: YES];
	for (id r in listView->rows) if ([r isKindOfClass: [NSString class]]) { listHeader->group = r; break; } [listHeader setNeedsDisplay: YES];
}
/* ---- the Open panel's view modes: icons (0), list (1), columns (2); gallery (3) shows the columns */
- (void)showViewMenu
{
	__weak WsdPanelController *me = self;
	[WsdPopup showIn: root titles: @[ @"as Icons", @"as List", @"as Columns", @"as Gallery" ] checked: viewMode at: NSMakePoint(135 + 76, 64 - 20) pick: ^(NSInteger k) { [me setViewMode: k == 3 ? 2 : (int)k]; }];
}
- (void)viewModePicked:(NSMenuItem *)it { [self setViewMode: (int)[it tag] == 3 ? 2 : (int)[it tag]]; }
- (void)clearBrowser
{
	if (preview) { [preview removeFromSuperview]; preview = nil; }
	for (WsdColumn *c in cols) { NSScrollView *sv = [c enclosingScrollView]; [sv setDocumentView: nil]; [sv removeFromSuperview]; } [cols removeAllObjects];
	if (listScroll) { [listScroll setDocumentView: nil]; [listScroll removeFromSuperview]; listScroll = nil; } if (listHeader) { [listHeader removeFromSuperview]; listHeader = nil; } listView = nil;
}
- (void)setViewMode:(int)m
{
	if (isSave || m == viewMode) return;
	NSString *d = [self currentDir]; viewMode = m; [self clearBrowser]; chosen = nil;
	if (m == 2) { [self navigate: d push: NO]; return; }
	listDir = d; double H = [root bounds].size.height, W = [root bounds].size.width - 135, hy = 64;
	if (m == 1) { listHeader = [[WsdListHeader alloc] initWithFrame: NSMakeRect(135, 64, W, 26)]; [root addSubview: listHeader]; hy = 90; }
	listScroll = [[NSScrollView alloc] initWithFrame: NSMakeRect(135, hy, W, H - 66 - hy)]; [listScroll setHasVerticalScroller: YES]; [listScroll setBorderType: NSNoBorder]; [listScroll setDrawsBackground: NO];
	listView = m == 1 ? [[WsdListColumn alloc] initWithFrame: NSMakeRect(0, 0, W - 15, 100)] : [[WsdIconColumn alloc] initWithFrame: NSMakeRect(0, 0, W - 15, 100)];
	listView->types = types; listView->filesOK = filesOK; listView->dirsOK = dirsOK; listView->delegate = self; listView->active = YES; listView->dir = d; listView->filter = searchText; [listView load];
	[listScroll setDocumentView: listView]; [root addSubview: listScroll]; [win makeFirstResponder: listView]; [self refreshListHeader]; [self refresh];
}
- (void)refreshListHeader { if (!listHeader || !listView) return; for (id r in listView->rows) if ([r isKindOfClass: [NSString class]]) { listHeader->group = r; break; } [listHeader setNeedsDisplay: YES]; }
- (void)openListGo:(NSString *)path push:(BOOL)push
{
	if (!path) return;
	if (push) { while ((NSInteger)[history count] > hpos + 1) [history removeLastObject]; [history addObject: path]; hpos = (NSInteger)[history count] - 1; }
	listDir = path; listView->dir = path; [listView load]; [listView scrollRectToVisible: NSMakeRect(0, 0, 1, 1)]; [listView setNeedsDisplay: YES]; chosen = nil; [self refreshListHeader]; [self refresh];
}
- (void)toggleExpanded { expanded = !expanded; [self buildSave]; }
- (void)makeNewFolder:(id)sender
{
	NSFileManager *fm = [NSFileManager defaultManager]; NSString *base = [saveDir stringByAppendingPathComponent: @"untitled folder"], *p = base; for (int i = 2; [fm fileExistsAtPath: p]; i++) p = [base stringByAppendingFormat: @" %d", i];
	[fm createDirectoryAtPath: p withIntermediateDirectories: NO attributes: nil error: NULL]; [self reloadList];
}
- (void)buildSave
{
	NSString *name = nameField ? [nameField stringValue] : savedName; savedName = name; NSArray *keepTags = tagField ? [tagField->chosen copy] : nil;
	for (NSView *v in [[root subviews] copy]) [v removeFromSuperview];
	corners = nil; toolbar = nil; sidebar = nil; listView = nil; listScroll = nil; listHeader = nil;
	NSSize size = expanded ? NSMakeSize(812, 333) : NSMakeSize(370, 204); NSRect wf = [win frame]; NSPoint ctr = NSMakePoint(NSMidX(wf), NSMidY(wf));
	[win setFrame: NSMakeRect(round(ctr.x - size.width / 2), round(ctr.y - size.height / 2), size.width, size.height) display: NO];
	[root setFrame: NSMakeRect(0, 0, size.width, size.height)]; ((WsdRoot *)root)->expanded = expanded;
	if (!expanded) {
		NSTextField *t = Field(NSMakeRect(0, 8, 370, 20), @"Save"); [t setAlignment: NSCenterTextAlignment]; [t setTextColor: P_DIM]; [t setEditable: NO]; [root addSubview: t];
		NSArray *labels = @[ @"Save As:", @"Tags:", @"Where:" ]; double ys[3] = { 41, 79, 116 };
		for (int i = 0; i < 3; i++) { NSTextField *l = Field(NSMakeRect(10, ys[i], 84, 20), labels[i]); [l setAlignment: NSRightTextAlignment]; [l setEditable: NO]; [l setTextColor: P_DIM]; [root addSubview: l]; }
		nameField = Field(NSMakeRect(100, 41, 230, 25), name); [nameField setBezeled: YES]; [nameField setDelegate: (id)self]; [root addSubview: nameField];
		tagField = [[WsdTagField alloc] initWithFrame: NSMakeRect(100, 79, 230, 25)]; [root addSubview: tagField];
		cancel = Btn(@"Cancel", NSMakeRect(184, 160, 78, 24), self, @selector(cancelIt:), NO); ok = Btn(okTitle, NSMakeRect(271, 160, 79, 24), self, @selector(accept:), YES);
		[root addSubview: cancel]; [root addSubview: ok];
	} else {
		WsdSidebar *sb = [[WsdSidebar alloc] initWithFrame: NSMakeRect(0, 0, 135, 333)]; [sb setup]; sb->target = self; sb->action = @selector(sidebarGo:); sidebar = sb;
		NSScrollView *ssv = [[NSScrollView alloc] initWithFrame: NSMakeRect(0, 0, 135, 333)]; [ssv setHasVerticalScroller: YES]; [ssv setAutohidesScrollers: YES]; [ssv setBorderType: NSNoBorder]; [ssv setDrawsBackground: NO]; [ssv setDocumentView: sb]; [root addSubview: ssv]; [[ssv contentView] scrollToPoint: NSMakePoint(0, 32)]; [ssv reflectScrolledClipView: [ssv contentView]];           /* the window buttons cover the top of the sidebar: it starts scrolled (Shared is the first row) */
		nameField = Field(NSMakeRect(358, 41, 232, 26), name); [nameField setBezeled: YES]; [nameField setDelegate: (id)self]; [root addSubview: nameField];
		tagField = [[WsdTagField alloc] initWithFrame: NSMakeRect(358, 79, 232, 26)]; [root addSubview: tagField];
		WsdToolbar *tb = [[WsdToolbar alloc] initWithFrame: NSMakeRect(135, 104, 677, 64)]; tb->target = self; tb->compact = YES; toolbar = tb; [root addSubview: tb];
		NSTextField *sf2 = SearchField(root, NSMakeRect(135 + 462, 123, 195, 26)); [sf2 setDelegate: (id)self]; tb->search = sf2;
		listHeader = [[WsdListHeader alloc] initWithFrame: NSMakeRect(135, 169, 677, 26)]; [root addSubview: listHeader];
		listScroll = [[NSScrollView alloc] initWithFrame: NSMakeRect(135, 195, 677, 76)]; [listScroll setHasVerticalScroller: YES]; [listScroll setBorderType: NSNoBorder]; [listScroll setDrawsBackground: NO];
		listView = [[WsdListColumn alloc] initWithFrame: NSMakeRect(0, 0, 662, 100)]; listView->types = types; listView->filesOK = YES; listView->dirsOK = NO; listView->delegate = self; listView->active = YES; [listScroll setDocumentView: listView]; [root addSubview: listScroll];
		newFolder = Btn(@"New Folder", NSMakeRect(155, 289, 94, 25), self, @selector(makeNewFolder:), NO); [root addSubview: newFolder];
		cancel = Btn(@"Cancel", NSMakeRect(626, 289, 79, 25), self, @selector(cancelIt:), NO); ok = Btn(okTitle, NSMakeRect(713, 289, 79, 25), self, @selector(accept:), YES); [root addSubview: cancel]; [root addSubview: ok];
		[self reloadList];
	}
	{ WsdLights *lt = [[WsdLights alloc] initWithFrame: [root bounds]]; lt->show = expanded; [root addSubview: lt]; }
	if (keepTags) [tagField->chosen addObjectsFromArray: keepTags];
	RoundWindow(win, 18); [root setNeedsDisplay: YES]; [self refresh]; [win makeFirstResponder: nameField];
}
- (void)sidebarGo:(NSString *)path { if (isSave) [self saveGo: path push: YES]; else if (viewMode != 2) [self openListGo: path push: YES]; else [self navigate: path push: YES]; }
- (void)goTo:(NSString *)path { if (isSave) [self saveGo: path push: NO]; else if (viewMode != 2) [self openListGo: path push: NO]; else [self navigate: path push: NO]; }
- (void)goBack { if (hpos > 0) { hpos--; [self goTo: history[hpos]]; } }
- (void)goForward { if (hpos + 1 < (NSInteger)[history count]) { hpos++; [self goTo: history[hpos]]; } }
- (NSString *)currentDir { if (isSave) return saveDir ?: dir; if (viewMode != 2 && listDir) return listDir; WsdColumn *c = [cols lastObject]; return c ? c->dir : dir; }
- (void)showPathMenu:(NSValue *)v
{
	NSString *p = [self currentDir]; NSMutableArray *chain = [NSMutableArray array], *names = [NSMutableArray array];
	while ([p length] > 1) { [chain addObject: p]; p = [p stringByDeletingLastPathComponent]; } [chain addObject: @"/"];
	for (NSString *q in chain) [names addObject: [q isEqual: @"/"] ? @"Macintosh HD" : [q lastPathComponent]];
	__weak WsdPanelController *me = self;
	[WsdPopup showIn: root titles: names checked: 0 at: isSave ? NSMakePoint(100, 140) : NSMakePoint(135 + 258, 64 - 20) pick: ^(NSInteger k) { [me sidebarGo: chain[k]]; }];
}
- (void)pathPicked:(NSMenuItem *)it { [self sidebarGo: [it representedObject]]; }
- (void)refresh
{
	NSString *d = [self currentDir], *title = [d isEqual: @"/"] ? @"Macintosh HD" : ([d isEqual: @"recents://"] ? @"Recents" : ([d hasPrefix: @"tag://"] ? [d substringFromIndex: 6] : [d lastPathComponent])); if (toolbar) { toolbar->mode = viewMode; toolbar->pathTitle = title; toolbar->canBack = hpos > 0; toolbar->canFwd = hpos + 1 < (NSInteger)[history count]; }
	BOOL enable = chosen != nil;
	if (chosen) { BOOL isDir = NO; [[NSFileManager defaultManager] fileExistsAtPath: chosen isDirectory: &isDir]; enable = isDir ? dirsOK : filesOK; }
	if (isSave) enable = [[nameField stringValue] length] > 0;
	if (isSave) { ((WsdRoot *)root)->whereTitle = title; [root setNeedsDisplay: YES]; }
	[ok setEnabled: enable]; [toolbar setNeedsDisplay: YES]; [sidebar setNeedsDisplay: YES];
}
- (void)accept:(id)sender
{
	NSMutableArray *res = [NSMutableArray array];
	if (isSave) {
		NSString *n = [nameField stringValue]; if (![n length]) return;
		if (types.count && ![[n pathExtension] length]) n = [n stringByAppendingPathExtension: types[0]];
		[res addObject: [[self currentDir] stringByAppendingPathComponent: n]]; if ([tagField->chosen count]) objc_setAssociatedObject(self->win, &kTags, [tagField->chosen copy], OBJC_ASSOCIATION_RETAIN);
	} else if (chosen) [res addObject: chosen]; else if (dirsOK) [res addObject: [self currentDir]];
	if (![res count]) return;
	objc_setAssociatedObject(self->win, &kResult, res, OBJC_ASSOCIATION_RETAIN); result = 1; [NSApp stopModalWithCode: 1];
}
- (void)cancelIt:(id)sender { result = 0; [NSApp stopModalWithCode: 0]; }
- (void)controlTextDidChange:(NSNotification *)n
{
	if ([n object] == toolbar->search && toolbar) {                                                                    /* the search field filters the folders shown by name */
		searchText = [toolbar->search stringValue]; for (WsdColumn *c in cols) { c->filter = searchText; [c load]; [c setNeedsDisplay: YES]; }
		if (listView) { listView->filter = searchText; [listView load]; [listView setNeedsDisplay: YES]; [self refreshListHeader]; }
	}
	[self refresh];
}
@end

@interface WsdFilePanelWindow : NSPanel @end
@implementation WsdFilePanelWindow
- (BOOL)canBecomeKeyWindow { return YES; }
- (BOOL)canBecomeMainWindow { return YES; }
- (void)cancelOperation:(id)s { [(WsdPanelController *)[self delegate] cancelIt: nil]; }
@end

static NSButton *Btn(NSString *title, NSRect f, id target, SEL action, BOOL def)
{
	NSButton *b = [[NSButton alloc] initWithFrame: f]; [b setTitle: title]; [b setBezelStyle: NSRoundedBezelStyle]; [b setTarget: target]; [b setAction: action]; if (def) [b setKeyEquivalent: @"\r"]; else if ([title isEqual: @"Cancel"]) [b setKeyEquivalent: @"\033"];
	return b;
}
@interface WsdSearchCell : NSTextFieldCell @end
@implementation WsdSearchCell
- (NSRect)drawingRectForBounds:(NSRect)r { r = [super drawingRectForBounds: r]; r.origin.x += 20; r.size.width -= 20; return r; }
@end
@interface WsdGlyphView : NSView { @public NSString *name; CGFloat size; } @end
@implementation WsdGlyphView
- (BOOL)isFlipped { return YES; }
- (NSView *)hitTest:(NSPoint)p { return nil; }
- (void)drawRect:(NSRect)r { DrawSymbol(name, [self bounds], size, P_DIM); }
@end
static NSTextField *SearchField(NSView *root, NSRect f)                                            /* a rounded field with the magnifying glass inside at its left */
{
	NSTextField *t = [[NSTextField alloc] initWithFrame: f]; WsdSearchCell *c = [[WsdSearchCell alloc] initTextCell: @""]; [t setCell: c]; [t setBordered: NO]; [t setBezeled: YES]; [t setDrawsBackground: NO]; [t setFont: [NSFont systemFontOfSize: 13]]; [t setTextColor: P_TEXT]; [t setFocusRingType: NSFocusRingTypeNone];
	[c setPlaceholderAttributedString: [[NSAttributedString alloc] initWithString: @"Search" attributes: Attr(13, NO, P_DIM)]]; [root addSubview: t];
	WsdGlyphView *g = [[WsdGlyphView alloc] initWithFrame: NSMakeRect(f.origin.x + 4, f.origin.y, 20, f.size.height)]; g->name = @"magnifyingglass"; g->size = 12; [root addSubview: g]; return t;
}
static NSTextField *Field(NSRect f, NSString *val)
{
	NSTextField *t = [[NSTextField alloc] initWithFrame: f]; [t setBordered: NO]; [t setBezeled: NO]; [t setDrawsBackground: NO]; [t setStringValue: val ?: @""]; [t setFont: [NSFont systemFontOfSize: 13]]; [t setTextColor: P_TEXT]; [t setFocusRingType: NSFocusRingTypeNone];
	return t;
}

static NSInteger WsdRunPanel(NSSavePanel *sp)
{
	BOOL open = [sp isKindOfClass: [NSOpenPanel class]]; WsdPanelController *pc = [WsdPanelController new]; pc->isSave = !open;
	pc->filesOK = open ? [(NSOpenPanel *)sp canChooseFiles] : YES; pc->dirsOK = open ? [(NSOpenPanel *)sp canChooseDirectories] : NO; pc->multiple = open ? [(NSOpenPanel *)sp allowsMultipleSelection] : NO;
	NSMutableArray *ty = [NSMutableArray array]; for (NSString *t in [sp allowedFileTypes] ?: @[]) if ([t length]) [ty addObject: [t lowercaseString]]; pc->types = ty;
	NSString *nm = objc_getAssociatedObject(sp, "wsdname"); NSString *d = [sp directory]; if (![d length] || ![[NSFileManager defaultManager] fileExistsAtPath: d]) d = NSHomeDirectory();
	pc->cols = [NSMutableArray array]; pc->history = [NSMutableArray array];
	NSRect frame = open ? NSMakeRect(0, 0, 880, 448) : NSMakeRect(0, 0, 370, 204);
	NSScreen *sc = [NSScreen mainScreen]; NSRect sf = [sc frame]; frame.origin = NSMakePoint(floor((sf.size.width - frame.size.width) / 2), floor((sf.size.height - frame.size.height) / 2 + 30));
	WsdFilePanelWindow *w = [[WsdFilePanelWindow alloc] initWithContentRect: frame styleMask: NSBorderlessWindowMask backing: NSBackingStoreBuffered defer: NO];
	[w setOpaque: NO]; [w setBackgroundColor: [NSColor clearColor]]; [w setDelegate: (id)pc]; [w setReleasedWhenClosed: NO]; pc->win = w;
	WsdRoot *root = [[WsdRoot alloc] initWithFrame: NSMakeRect(0, 0, frame.size.width, frame.size.height)]; pc->root = root; root->owner = pc; root->saveForm = !open; [w setContentView: root];
	if (open) {
		WsdSidebar *sb = [[WsdSidebar alloc] initWithFrame: NSMakeRect(0, 0, 135, 448)]; [sb setup]; sb->target = pc; sb->action = @selector(sidebarGo:); pc->sidebar = sb;
		NSScrollView *ssv = [[NSScrollView alloc] initWithFrame: NSMakeRect(0, 0, 135, 448)]; [ssv setHasVerticalScroller: YES]; [ssv setAutohidesScrollers: YES]; [ssv setBorderType: NSNoBorder]; [ssv setDrawsBackground: NO]; [ssv setDocumentView: sb]; [root addSubview: ssv];
		WsdToolbar *tb = [[WsdToolbar alloc] initWithFrame: NSMakeRect(135, 0, 745, 64)]; tb->target = pc; pc->toolbar = tb; [root addSubview: tb];
		NSTextField *sf2 = SearchField(root, NSMakeRect(135 + 529, 19, 196, 26)); [sf2 setDelegate: (id)pc]; tb->search = sf2;
		pc->cancel = Btn(@"Cancel", NSMakeRect(695, 448 - 43, 77, 22), pc, @selector(cancelIt:), NO); pc->ok = Btn(([sp prompt].length && ![[sp prompt] isEqual: @"Name:"]) ? [sp prompt] : @"Open", NSMakeRect(781, 448 - 43, 79, 22), pc, @selector(accept:), YES);
		[root addSubview: pc->cancel]; [root addSubview: pc->ok]; [pc->ok setEnabled: NO];
		pc->viewMode = 2; [pc navigate: d push: YES]; if (getenv("WSD_PANEL_VIEW")) [pc setViewMode: atoi(getenv("WSD_PANEL_VIEW"))]; for (NSInteger i = 0; i < (NSInteger)[sb->items count]; i++) if ([sb->items[i][@"p"] isEqual: d]) sb->selected = i;
	} else {
		pc->okTitle = ([sp prompt].length && ![[sp prompt] isEqual: @"Name:"]) ? [sp prompt] : @"Save"; pc->savedName = nm ?: ([sp nameFieldStringValue] ?: @""); pc->saveDir = d; pc->dir = d;
		[pc->history addObject: d]; pc->hpos = 0; [pc buildSave];
		objc_setAssociatedObject(w, "dirpath", d, OBJC_ASSOCIATION_RETAIN);
	}
	[w makeKeyAndOrderFront: nil]; RoundWindow(w, open ? 22 : 18); if (!getenv("WSD_NO_PANEL_ANIM")) [WsdPanelAnim open: w];
	if (open && [pc->cols count]) [w makeFirstResponder: pc->cols[0]];
	if (!open) [w makeFirstResponder: pc->nameField];
	NSInteger r = ((NSInteger (*)(id, SEL, NSWindow *))origRunModal)(NSApp, @selector(runModalForWindow:), w);
	NSArray *res = objc_getAssociatedObject(w, &kResult);
	NSArray *chosenTags = objc_getAssociatedObject(w, &kTags); if (r == 1 && [chosenTags count] && [res count]) [WsdTagApplier apply: chosenTags toPath: res[0]];
	objc_setAssociatedObject(sp, &kResult, r == 1 ? res : nil, OBJC_ASSOCIATION_RETAIN);
	if (!getenv("WSD_NO_PANEL_ANIM")) [WsdPanelAnim close: w];
	[w orderOut: nil]; [w setAlphaValue: 1]; ScaleWindow(w, 1.0f);
	return r == 1 ? NSOKButton : NSCancelButton;
}
/* the Save form draws its own fields (they are not NSControls with bezels): the Where pop-up and the expand button */
@interface WsdSaveFormDrawing : NSObject @end

static NSInteger wsdRunModalForWindow(id self, SEL _cmd, NSWindow *w)
{
	if ([w isKindOfClass: [NSSavePanel class]] && !getenv("WSD_NO_MACFILEPANEL")) return WsdRunPanel((NSSavePanel *)w);
	return ((NSInteger (*)(id, SEL, NSWindow *))origRunModal)(self, _cmd, w);
}
static NSInteger wsdRunModalRel(id self, SEL _cmd, NSWindow *w, NSWindow *rel)
{
	if ([w isKindOfClass: [NSSavePanel class]] && !getenv("WSD_NO_MACFILEPANEL")) return WsdRunPanel((NSSavePanel *)w);
	return ((NSInteger (*)(id, SEL, NSWindow *, NSWindow *))origRunModalRel)(self, _cmd, w, rel);
}
static void wsdBeginCompletion(id self, SEL _cmd, void (^handler)(NSInteger))
{
	if (getenv("WSD_NO_MACFILEPANEL")) { ((void (*)(id, SEL, id))origBeginCompletion)(self, _cmd, handler); return; }
	NSInteger r = WsdRunPanel((NSSavePanel *)self); if (handler) handler(r);
}
static NSString *wsdSaveFilename(id self, SEL _cmd)
{
	NSArray *r = objc_getAssociatedObject(self, &kResult); if ([r count]) return r[0];
	return ((NSString *(*)(id, SEL))origSaveFilename)(self, _cmd);
}
static NSArray *wsdOpenFilenames(id self, SEL _cmd)
{
	NSArray *r = objc_getAssociatedObject(self, &kResult); if (r) return r;
	return ((NSArray *(*)(id, SEL))origOpenFilenames)(self, _cmd);
}

static void wsdSetName(id self, SEL _cmd, NSString *v) { objc_setAssociatedObject(self, "wsdname", v, OBJC_ASSOCIATION_COPY); ((void (*)(id, SEL, id))origSetName)(self, _cmd, v); }
/* the pieces of the panel the Finder window reuses (the Finder is a separate program: it finds this class by name) */
@interface WsdFinderSupport : NSObject @end
@implementation WsdFinderSupport
+ (void)roundWindow:(NSWindow *)w radius:(int)r { RoundWindow(w, r); }
+ (void)setKeyWindow:(NSWindow *)w { id srv = GSCurrentServer(); if ([srv respondsToSelector: @selector(wsdSetKeyWindow:)]) ((void (*)(id, SEL, int))objc_msgSend)(srv, @selector(wsdSetKeyWindow:), (int)[w windowNumber]); }
+ (BOOL)drawSymbol:(NSString *)name inRect:(NSRect)cell size:(CGFloat)pt weight:(int)weight color:(NSColor *)c { return WsdSymbolDraw(name, cell, pt, weight, c); }
+ (BOOL)isDark { return WsdAppearanceIsDark(); }
+ (void)drawWindowButton:(NSImage *)im rect:(NSRect)r held:(BOOL)held pull:(NSPoint)pull { WsdDrawWindowButton(im, r, held, pull); }
+ (NSImage *)windowButtonKind:(int)kind state:(int)state { return WsdWindowButtonImage(kind, state, WsdAppearanceIsDark()); }          /* the Finder draws its own title bar buttons with the Mac's pictures */
+ (BOOL)dropFiles:(NSArray *)paths atScreenPoint:(NSPoint)p { id srv = GSCurrentServer(); if ([srv respondsToSelector: @selector(wsdDropFiles:atScreenPoint:)]) return [srv wsdDropFiles: paths atScreenPoint: p]; return NO; }
+ (void)popupInView:(NSView *)root rows:(NSArray *)rows at:(NSPoint)p pick:(void (^)(NSInteger))b { [WsdPopup showIn: root rows: rows at: p pick: b]; }
+ (void)popupInView:(NSView *)root titles:(NSArray *)t dots:(NSArray *)d checks:(NSIndexSet *)c at:(NSPoint)p pick:(void (^)(NSInteger))b { [WsdPopup showIn: root titles: t dots: d checks: c at: p pick: b]; }
+ (NSArray *)tagsOfPath:(NSString *)path { return TagsOf(path); }
+ (void)setTags:(NSArray *)names ofPath:(NSString *)path { SetTags(path, names); }
+ (NSArray *)tagNames { return TagNames(); }
+ (NSArray *)pathsTagged:(NSString *)tag { NSMutableArray *out = [NSMutableArray array]; for (NSString *p in [NSDictionary dictionaryWithContentsOfFile: TagIndexPath()][tag]) if ([[NSFileManager defaultManager] fileExistsAtPath: p] && [TagsOf(p) containsObject: tag]) [out addObject: p]; return out; }
+ (NSColor *)colorOfTag:(NSString *)name { return TagColor(name); }
+ (void)drawTagDots:(NSArray *)names rightEdge:(double)x centerY:(double)cy { DrawTagDots(names, x, cy); }
+ (double)tagDotsWidth:(NSArray *)names { return TagDotsWidth(names); }
+ (void)drawIconOfName:(NSString *)name directory:(BOOL)dir inRect:(NSRect)r { if (dir) DrawDirIcon(r, name); else DrawFileIcon(r, name); }
@end
void WsdInstallFilePanel(void)
{
	if (origRunModal) return;
	Method m1 = class_getInstanceMethod([NSApplication class], @selector(runModalForWindow:)); if (m1) origRunModal = method_setImplementation(m1, (IMP)wsdRunModalForWindow);
	Method m2 = class_getInstanceMethod([NSApplication class], @selector(runModalForWindow:relativeToWindow:)); if (m2) origRunModalRel = method_setImplementation(m2, (IMP)wsdRunModalRel);
	Method m3 = class_getInstanceMethod([NSSavePanel class], @selector(beginWithCompletionHandler:)); if (m3) origBeginCompletion = method_setImplementation(m3, (IMP)wsdBeginCompletion);
	Method m6 = class_getInstanceMethod([NSSavePanel class], @selector(setNameFieldStringValue:)); if (m6) origSetName = method_setImplementation(m6, (IMP)wsdSetName);
	Method m4 = class_getInstanceMethod([NSSavePanel class], @selector(filename)); if (m4) origSaveFilename = method_setImplementation(m4, (IMP)wsdSaveFilename);
	Method m5 = class_getInstanceMethod([NSOpenPanel class], @selector(filenames)); if (m5) origOpenFilenames = method_setImplementation(m5, (IMP)wsdOpenFilenames);
}
