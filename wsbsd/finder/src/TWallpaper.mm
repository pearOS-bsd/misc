/* The desktop picture: drawn under the icons by the desktop window (as the Mac's wallpaper agent does) and reduced to a coarse grid of colours that the windows of every program use to tint
 * their background (WsdAppearance.m, "Tint window background with wallpaper color"). The picture is the preference DesktopPicture (a path), or FINDER_WALLPAPER. */
#import "TFinderViews.h"

NSString *TFWallpaperPath(void)
{
	const char *e = getenv("FINDER_WALLPAPER"); NSString *p = e ? [NSString stringWithUTF8String: e] : TFPref(@"DesktopPicture", nil);
	return [p length] && [[NSFileManager defaultManager] fileExistsAtPath: p] ? p : nil;
}
static NSImage *gPicture; static NSString *gPicturePath;
NSImage *TFWallpaperImage(void)
{
	NSString *p = TFWallpaperPath(); if (!p) { gPicture = nil; gPicturePath = nil; return nil; }
	if (![p isEqual: gPicturePath]) { gPicture = [[NSImage alloc] initWithContentsOfFile: p]; gPicturePath = p; if (!gPicture || [gPicture size].width < 1) gPicture = nil; }
	return gPicture;
}
/* the part of the picture that fills a screen of this size (the Mac's "Fill Screen") */
static NSRect FillRect(NSSize img, NSSize dst)
{
	double k = MAX(dst.width / img.width, dst.height / img.height), w = dst.width / k, h = dst.height / k; return NSMakeRect((img.width - w) / 2, (img.height - h) / 2, w, h);
}
/* the colours behind the windows: the picture filled to the screen, 64 cells wide, written where the programs look for it (removed when there is no picture) */
void TFWriteWallpaperGrid(NSSize screen)
{
	NSString *dir = [NSHomeDirectory() stringByAppendingPathComponent: @"Library/Caches/com.wsbsd.wallpaper"], *f = [dir stringByAppendingPathComponent: @"grid.plist"]; NSFileManager *fm = [NSFileManager defaultManager];
	NSImage *img = TFWallpaperImage(); NSBitmapImageRep *rep = nil; for (NSImageRep *r in [img representations]) if ([r isKindOfClass: [NSBitmapImageRep class]]) { rep = (NSBitmapImageRep *)r; break; }
	if (!rep || screen.width < 1) { [fm removeItemAtPath: f error: NULL]; return; }
	int gw = 64, gh = MAX(1, (int)lround(64.0 * screen.height / screen.width)); NSRect src = FillRect(NSMakeSize([rep pixelsWide], [rep pixelsHigh]), screen); NSMutableData *out = [NSMutableData dataWithLength: (NSUInteger)gw * gh * 3]; unsigned char *o = (unsigned char *)[out mutableBytes];
	for (int gy = 0; gy < gh; gy++) for (int gx = 0; gx < gw; gx++) {
		double sum[3] = { 0, 0, 0 }; int n = 0;
		for (int sy = 0; sy < 4; sy++) for (int sx = 0; sx < 4; sx++) {
			NSInteger px = (NSInteger)(src.origin.x + (gx + (sx + 0.5) / 4) / gw * src.size.width), py = (NSInteger)(src.origin.y + (gy + (sy + 0.5) / 4) / gh * src.size.height);
			px = MAX(0, MIN([rep pixelsWide] - 1, px)); py = MAX(0, MIN([rep pixelsHigh] - 1, py)); NSColor *c = [[rep colorAtX: px y: py] colorUsingColorSpaceName: NSCalibratedRGBColorSpace]; if (!c) continue;
			double a = [c alphaComponent]; sum[0] += [c redComponent] * 255 * a; sum[1] += [c greenComponent] * 255 * a; sum[2] += [c blueComponent] * 255 * a; n++;
		}
		for (int k = 0; k < 3; k++) o[(gy * gw + gx) * 3 + k] = n ? (unsigned char)(sum[k] / n + 0.5) : 0;
	}
	[fm createDirectoryAtPath: dir withIntermediateDirectories: YES attributes: nil error: NULL]; [@{ @"w": @(gw), @"h": @(gh), @"rgb": out } writeToFile: f atomically: YES];
}

@implementation TWallpaperView
- (BOOL)isFlipped { return NO; }
- (void)drawRect:(NSRect)dirty
{
	NSImage *img = TFWallpaperImage(); NSRect b = [self bounds]; if (getenv("FINDER_DEBUG")) NSLog(@"wallpaper draw %@ in %@ image %@", NSStringFromRect(dirty), NSStringFromRect(b), img);
	if (!img) { [[NSColor clearColor] set]; return; }
	[img drawInRect: b fromRect: FillRect([img size], b.size) operation: NSCompositeSourceOver fraction: 1];
}
@end
