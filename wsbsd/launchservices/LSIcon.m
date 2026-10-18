#import "LSIcon.h"
#import <ImageIO/ImageIO.h>
#include "icns.h"
#include <math.h>

static CGImageRef DecodeData(NSData *d, int px)
{
	CGImageSourceRef src = CGImageSourceCreateWithData((__bridge CFDataRef)d, NULL); if (!src) return NULL;
	CGImageRef im = CGImageSourceCreateImageAtIndex(src, 0, NULL); CFRelease(src); (void)px; return im;
}

CGImageRef LSIconCreateFromICNS(NSString *path, int px)
{
	NSData *d = [NSData dataWithContentsOfFile: path]; if (!d) return NULL;
	IcnsPick p; if (!icns_pick([d bytes], [d length], px, &p)) return NULL;
	if (p.png) return DecodeData([NSData dataWithBytes: p.png length: p.png_len], px);
	CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB(); int w = p.px;
	uint8_t *pm = p.rgba;                                         /* straight alpha to premultiplied */
	for (int i = 0; i < w * w; i++) { int a = pm[i * 4 + 3]; pm[i * 4] = pm[i * 4] * a / 255; pm[i * 4 + 1] = pm[i * 4 + 1] * a / 255; pm[i * 4 + 2] = pm[i * 4 + 2] * a / 255; }
	CGContextRef c = CGBitmapContextCreate(pm, w, w, 8, w * 4, cs, kCGImageAlphaPremultipliedLast);
	CGImageRef im = c ? CGBitmapContextCreateImage(c) : NULL; if (c) CGContextRelease(c); CGColorSpaceRelease(cs); free(pm); return im;
}

static CGPathRef RoundRectPath(CGRect r, CGFloat rx)
{
	CGMutablePathRef p = CGPathCreateMutable(); CGFloat x0 = CGRectGetMinX(r), x1 = CGRectGetMaxX(r), y0 = CGRectGetMinY(r), y1 = CGRectGetMaxY(r);
	if (rx * 2 > r.size.height) rx = r.size.height / 2; if (rx * 2 > r.size.width) rx = r.size.width / 2;
	CGPathMoveToPoint(p, NULL, x0 + rx, y0); CGPathAddLineToPoint(p, NULL, x1 - rx, y0); CGPathAddArc(p, NULL, x1 - rx, y0 + rx, rx, -M_PI / 2, 0, 0);
	CGPathAddLineToPoint(p, NULL, x1, y1 - rx); CGPathAddArc(p, NULL, x1 - rx, y1 - rx, rx, 0, M_PI / 2, 0);
	CGPathAddLineToPoint(p, NULL, x0 + rx, y1); CGPathAddArc(p, NULL, x0 + rx, y1 - rx, rx, M_PI / 2, M_PI, 0);
	CGPathAddLineToPoint(p, NULL, x0, y0 + rx); CGPathAddArc(p, NULL, x0 + rx, y0 + rx, rx, M_PI, 3 * M_PI / 2, 0);
	CGPathCloseSubpath(p); return p;
}

static void Fill(CGContextRef c, double r, double g, double b, double a) { CGContextSetRGBFillColor(c, r, g, b, a); CGContextSetRGBStrokeColor(c, r, g, b, a); }
static void Grad(CGContextRef c, CGRect r, const double *top, const double *bot)
{
	CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB(); CGFloat comps[8] = { top[0], top[1], top[2], 1, bot[0], bot[1], bot[2], 1 }, loc[2] = { 0, 1 };
	CGGradientRef g = CGGradientCreateWithColorComponents(cs, comps, loc, 2);
	CGContextDrawLinearGradient(c, g, CGPointMake(r.origin.x, CGRectGetMaxY(r)), CGPointMake(r.origin.x, r.origin.y), 0); CGGradientRelease(g); CGColorSpaceRelease(cs);
}

/* the drawing is done in a 64 x 64 box (y up), scaled to the image */
static void DrawFolder(CGContextRef c)
{
	CGRect body = CGRectMake(0.5, 6, 63, 40), tab = CGRectMake(0.5, 6, 25, 47);
	CGContextSaveGState(c); 
	CGContextRestoreGState(c);
	CGMutablePathRef p = CGPathCreateMutable();                                 /* back with the tab */
	CGPathMoveToPoint(p, NULL, 4.5, 6); CGPathAddLineToPoint(p, NULL, 4.5 - 4, 6); CGPathAddArc(p, NULL, 4.5, 10, 4, -M_PI / 2, -M_PI, 1);
	CGPathAddLineToPoint(p, NULL, 0.5, 49); CGPathAddArc(p, NULL, 4.5, 49, 4, M_PI, M_PI / 2, 1);
	CGPathAddLineToPoint(p, NULL, 20, 53); CGPathAddCurveToPoint(p, NULL, 24, 53, 24.5, 49, 28, 48.5); CGPathAddLineToPoint(p, NULL, 59, 48.5);
	CGPathAddArc(p, NULL, 59, 44.5, 4, M_PI / 2, 0, 1); CGPathAddLineToPoint(p, NULL, 63, 10); CGPathAddArc(p, NULL, 59, 10, 4, 0, -M_PI / 2, 1); CGPathCloseSubpath(p);
	CGContextSaveGState(c); CGContextAddPath(c, p); CGContextClip(c);
	const double t1[3] = { 98 / 255., 196 / 255., 241 / 255. }, b1[3] = { 64 / 255., 169 / 255., 219 / 255. };
	Grad(c, CGRectMake(0, 6, 64, 47), t1, b1);
	CGContextRestoreGState(c); CGPathRelease(p);
	(void)body; (void)tab;
	/* the front flap */
	CGRect fr = CGRectMake(0.5, 6, 63, 38); CGMutablePathRef q = CGPathCreateMutable();
	CGPathAddPath(q, NULL, RoundRectPath(fr, 4));
	CGContextSaveGState(c); CGContextAddPath(c, q); CGContextClip(c);
	const double t2[3] = { 104 / 255., 200 / 255., 244 / 255. }, b2[3] = { 66 / 255., 170 / 255., 220 / 255. };
	Grad(c, fr, t2, b2); CGContextRestoreGState(c);
	Fill(c, 1, 1, 1, 0.25); CGContextSetLineWidth(c, 0.8); CGContextMoveToPoint(c, 4.5, 43.6); CGContextAddLineToPoint(c, 59.5, 43.6); CGContextStrokePath(c);
	CGPathRelease(q);
}

static void DrawPage(CGContextRef c, NSString *kind, NSString *label)
{
	CGRect pg = CGRectMake(10.5, 3.5, 43, 57); double cut = 13, rr = 2.2;
	CGMutablePathRef p = CGPathCreateMutable();
	CGPathMoveToPoint(p, NULL, pg.origin.x + rr, pg.origin.y); CGPathAddLineToPoint(p, NULL, CGRectGetMaxX(pg) - rr, pg.origin.y);
	CGPathAddArcToPoint(p, NULL, CGRectGetMaxX(pg), pg.origin.y, CGRectGetMaxX(pg), pg.origin.y + rr, rr);
	CGPathAddLineToPoint(p, NULL, CGRectGetMaxX(pg), CGRectGetMaxY(pg) - cut); CGPathAddLineToPoint(p, NULL, CGRectGetMaxX(pg) - cut, CGRectGetMaxY(pg));
	CGPathAddLineToPoint(p, NULL, pg.origin.x + rr, CGRectGetMaxY(pg)); CGPathAddArcToPoint(p, NULL, pg.origin.x, CGRectGetMaxY(pg), pg.origin.x, CGRectGetMaxY(pg) - rr, rr);
	CGPathAddLineToPoint(p, NULL, pg.origin.x, pg.origin.y + rr); CGPathAddArcToPoint(p, NULL, pg.origin.x, pg.origin.y, pg.origin.x + rr, pg.origin.y, rr); CGPathCloseSubpath(p);
	CGContextSaveGState(c); CGContextAddPath(c, p); CGContextClip(c);
	const double t[3] = { 0.975, 0.975, 0.975 }, b[3] = { 0.93, 0.935, 0.935 }; Grad(c, pg, t, b); CGContextRestoreGState(c);
	Fill(c, 0, 0, 0, 0.14); CGContextSetLineWidth(c, 0.6); CGContextAddPath(c, p); CGContextStrokePath(c); CGPathRelease(p);
	/* the folded corner */
	CGMutablePathRef f = CGPathCreateMutable(); double fx = CGRectGetMaxX(pg), fy = CGRectGetMaxY(pg);
	CGPathMoveToPoint(f, NULL, fx - cut, fy); CGPathAddLineToPoint(f, NULL, fx - cut, fy - cut + 1.5); CGPathAddArcToPoint(f, NULL, fx - cut, fy - cut, fx - cut + 1.5, fy - cut, 1.5); CGPathAddLineToPoint(f, NULL, fx, fy - cut); CGPathCloseSubpath(f);
	CGContextSaveGState(c); CGContextAddPath(c, f); CGContextClip(c); const double ft[3] = { 1, 1, 1 }, fb[3] = { 0.9, 0.9, 0.9 }; Grad(c, CGRectMake(fx - cut, fy - cut, cut, cut), ft, fb); CGContextRestoreGState(c);
	Fill(c, 0, 0, 0, 0.18); CGContextSetLineWidth(c, 0.6); CGContextAddPath(c, f); CGContextStrokePath(c); CGPathRelease(f);
	double cx = pg.origin.x + pg.size.width / 2;
	if ([kind isEqual: @"zip"] || [kind isEqual: @"bin"]) {
		Fill(c, 0.62, 0.64, 0.66, 1); CGContextSetLineCap(c, kCGLineCapRound);
		CGContextFillEllipseInRect(c, CGRectMake(cx - 2.2, 41, 4.4, 4.4));
		CGContextSetLineWidth(c, 4.4); CGContextMoveToPoint(c, cx, 52); CGContextAddLineToPoint(c, cx, 44); CGContextStrokePath(c);
		Fill(c, 0.97, 0.97, 0.97, 1); CGContextFillEllipseInRect(c, CGRectMake(cx - 1, 41.8, 2, 2));
		CGContextSetLineWidth(c, 1.3); Fill(c, 0.66, 0.68, 0.7, 1);
		for (int i = 0; i < 4; i++) { double y = 38 - i * 3.6, x = (i & 1) ? cx - 3.2 : cx - 1.2; CGContextMoveToPoint(c, x, y); CGContextAddLineToPoint(c, x + 4.4, y); CGContextStrokePath(c); }
	} else if ([kind isEqual: @"dmg"]) {
		Fill(c, 0.7, 0.72, 0.75, 1); CGContextSetLineWidth(c, 3); CGContextSetLineCap(c, kCGLineCapRound); CGContextSetLineJoin(c, kCGLineJoinRound);
		CGContextMoveToPoint(c, cx, 40); CGContextAddLineToPoint(c, cx, 24); CGContextStrokePath(c);
		CGContextMoveToPoint(c, cx - 6, 29); CGContextAddLineToPoint(c, cx, 22); CGContextAddLineToPoint(c, cx + 6, 29); CGContextStrokePath(c);
	} else if ([kind isEqual: @"pdf"]) {
		Fill(c, 0.82, 0.2, 0.2, 1); label = @"PDF";
	} else if ([kind isEqual: @"text"] || [kind isEqual: @"sheet"] || [kind isEqual: @"code"]) {
		Fill(c, 0.7, 0.72, 0.76, 1); CGContextSetLineWidth(c, 1.4);
		for (int i = 0; i < 6; i++) { double y = 40 - i * 5; CGContextMoveToPoint(c, pg.origin.x + 7, y); CGContextAddLineToPoint(c, pg.origin.x + pg.size.width - 7 - (i == 5 ? 14 : 0), y); CGContextStrokePath(c); }
	} else if ([kind isEqual: @"image"]) {
		Fill(c, 0.55, 0.78, 0.95, 1); CGContextFillRect(c, CGRectMake(pg.origin.x + 6, 14, pg.size.width - 12, 24));
		Fill(c, 0.35, 0.65, 0.4, 1); CGContextMoveToPoint(c, pg.origin.x + 6, 14); CGContextAddLineToPoint(c, pg.origin.x + 18, 28); CGContextAddLineToPoint(c, pg.origin.x + 26, 20); CGContextAddLineToPoint(c, pg.origin.x + 31, 24); CGContextAddLineToPoint(c, pg.origin.x + 37, 14); CGContextFillPath(c);
	}
	if (label.length) {                                                          /* the small type label at the foot of the page */
		CGContextSelectFont(c, "Helvetica-Bold", 7.5, kCGEncodingMacRoman); CGContextSetTextMatrix(c, CGAffineTransformIdentity);
		const char *s = [label UTF8String]; CGContextSaveGState(c); CGContextTranslateCTM(c, -100000, -100000); CGContextSetTextPosition(c, 0, 0); CGContextShowText(c, s, strlen(s)); double w = CGContextGetTextPosition(c).x; CGContextRestoreGState(c);
		Fill(c, 0.74, 0.75, 0.77, 1); CGContextShowTextAtPoint(c, cx - w / 2, 8.5, s, strlen(s));
	}
}

static void DrawApp(CGContextRef c)
{
	CGRect r = CGRectMake(4, 4, 56, 56); CGMutablePathRef p = CGPathCreateMutable(); CGPathAddPath(p, NULL, RoundRectPath(r, 12.5));
	CGContextSaveGState(c); CGContextAddPath(c, p); CGContextClip(c); const double t[3] = { 0.78, 0.9, 1 }, b[3] = { 0.36, 0.55, 0.9 }; Grad(c, r, t, b); CGContextRestoreGState(c);
	Fill(c, 1, 1, 1, 0.95); CGContextSetLineWidth(c, 4.5); CGContextSetLineCap(c, kCGLineCapRound); CGContextSetLineJoin(c, kCGLineJoinRound);
	CGContextMoveToPoint(c, 20, 18); CGContextAddLineToPoint(c, 32, 46); CGContextAddLineToPoint(c, 44, 18); CGContextStrokePath(c);
	CGContextMoveToPoint(c, 24.5, 28); CGContextAddLineToPoint(c, 39.5, 28); CGContextStrokePath(c); CGPathRelease(p);
}

NSString *LSKindForPath(NSString *path)
{
	BOOL dir = NO; if (![[NSFileManager defaultManager] fileExistsAtPath: path isDirectory: &dir]) dir = NO;
	NSString *e = [[path pathExtension] lowercaseString];
	if (dir) return [e isEqual: @"app"] ? @"app" : @"folder";
	NSDictionary *map = @{ @"zip": @"zip", @"gz": @"zip", @"tgz": @"zip", @"bz2": @"zip", @"xz": @"zip", @"tar": @"zip", @"7z": @"zip", @"rar": @"zip", @"bin": @"bin", @"dmg": @"dmg", @"iso": @"dmg",
		@"pdf": @"pdf", @"txt": @"text", @"md": @"text", @"rtf": @"text", @"log": @"text", @"csv": @"sheet", @"xlsx": @"sheet", @"xls": @"sheet", @"numbers": @"sheet",
		@"png": @"image", @"jpg": @"image", @"jpeg": @"image", @"gif": @"image", @"tiff": @"image", @"heic": @"image", @"webp": @"image", @"bmp": @"image",
		@"c": @"code", @"h": @"code", @"m": @"code", @"cpp": @"code", @"py": @"code", @"js": @"code", @"swift": @"code", @"sh": @"code", @"json": @"code", @"html": @"code", @"xml": @"code" };
	return map[e] ?: @"doc";
}

CGImageRef LSIconCreateForKind(NSString *kind, int px)
{
	CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
	CGContextRef c = CGBitmapContextCreate(NULL, px, px, 8, px * 4, cs, kCGImageAlphaPremultipliedLast); CGColorSpaceRelease(cs); if (!c) return NULL;
	CGContextScaleCTM(c, px / 64.0, px / 64.0);
	if ([kind isEqual: @"folder"]) DrawFolder(c); else if ([kind isEqual: @"app"]) DrawApp(c);
	else { NSString *lab = nil; if ([kind isEqual: @"zip"]) lab = @"ZIP"; else if ([kind isEqual: @"bin"]) lab = @"BIN"; DrawPage(c, kind, lab); }
	CGImageRef im = CGBitmapContextCreateImage(c); CGContextRelease(c); return im;
}

static NSString *BundleIconFile(NSString *app)
{
	NSString *res = [app stringByAppendingPathComponent: @"Contents/Resources"];
	NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile: [app stringByAppendingPathComponent: @"Contents/Info.plist"]];
	NSString *n = info[@"CFBundleIconFile"];
	if (![n isKindOfClass: [NSString class]] || !n.length) { NSArray *files = info[@"CFBundleIconFiles"]; n = [files isKindOfClass: [NSArray class]] ? [files firstObject] : nil; }
	if (n.length) { if (![[n pathExtension] length]) n = [n stringByAppendingPathExtension: @"icns"]; NSString *p = [res stringByAppendingPathComponent: n]; if ([[NSFileManager defaultManager] fileExistsAtPath: p]) return p; }
	NSString *guess = [res stringByAppendingPathComponent: @"AppIcon.icns"]; if ([[NSFileManager defaultManager] fileExistsAtPath: guess]) return guess;
	for (NSString *f in [[NSFileManager defaultManager] contentsOfDirectoryAtPath: res error: NULL]) if ([[f pathExtension] isEqual: @"icns"]) return [res stringByAppendingPathComponent: f];
	return nil;
}

CGImageRef LSIconCreateForPath(NSString *path, int px)
{
	NSString *kind = LSKindForPath(path);
	if ([kind isEqual: @"app"]) { NSString *f = BundleIconFile(path); if (f) { CGImageRef im = LSIconCreateFromICNS(f, px); if (im) return im; } }
	return LSIconCreateForKind(kind, px);
}
