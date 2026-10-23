/* The desktop picture: drawn under the icons by the desktop window (as the Mac's wallpaper agent does) and reduced to a coarse grid of colours that the windows of every program use to tint
 * their background (WsdAppearance.m, "Tint window background with wallpaper color"). The picture is the preference DesktopPicture (a path), or FINDER_WALLPAPER. */
#import "TFinderViews.h"

/* the picture: the one chosen (preference DesktopPicture or FINDER_WALLPAPER), else the default one of the system for the appearance, in the folder where the Mac keeps its desktop pictures */
NSString *TFWallpaperPath(void)
{
	NSFileManager *fm = [NSFileManager defaultManager]; const char *e = getenv("FINDER_WALLPAPER"); NSString *p = e ? [NSString stringWithUTF8String: e] : TFPref(@"DesktopPicture", nil);
	if ([p length] && [fm fileExistsAtPath: p]) return p;
	NSString *d = [TFDark() ? @"dark-mode" : @"light-mode" stringByAppendingPathExtension: @"jpg"]; for (NSString *dir in @[ @"/System/Library/Desktop Pictures", [NSHomeDirectory() stringByAppendingPathComponent: @"Library/Desktop Pictures"] ]) { NSString *f = [dir stringByAppendingPathComponent: d]; if ([fm fileExistsAtPath: f]) return f; }
	return nil;
}
static NSImage *gPicture, *gSource; static NSString *gPicturePath;
static NSRect FillRect(NSSize img, NSSize dst);
/* the picture as loaded (the grid of colours is read from it) and the picture ready to draw: a large one is scaled once to the screen (a 4480 x 3088 jpeg drawn at every refresh would be slow) */
NSImage *TFWallpaperSource(void) { TFWallpaperImage(); return gSource; }
NSImage *TFWallpaperImage(void)
{
	NSString *p = TFWallpaperPath(); if (!p) { gPicture = gSource = nil; gPicturePath = nil; return nil; }
	if (![p isEqual: gPicturePath]) {
		gSource = [[NSImage alloc] initWithContentsOfFile: p]; gPicturePath = p; gPicture = nil; if (!gSource || [gSource size].width < 1) { gSource = nil; return nil; }
		NSSize sc = [[NSScreen mainScreen] frame].size; CGFloat k = [[NSScreen mainScreen] respondsToSelector: @selector(backingScaleFactor)] ? [[NSScreen mainScreen] backingScaleFactor] : 1; NSSize want = NSMakeSize(sc.width * k, sc.height * k), src = [gSource size];
		if (src.width > want.width * 1.3 && want.width > 1) { NSImage *o = [[NSImage alloc] initWithSize: want]; [o lockFocus]; [gSource drawInRect: NSMakeRect(0, 0, want.width, want.height) fromRect: FillRect(src, want) operation: NSCompositeCopy fraction: 1]; [o unlockFocus]; gPicture = o; } else gPicture = gSource;
	}
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
	NSImage *img = TFWallpaperSource(); NSBitmapImageRep *rep = nil; for (NSImageRep *r in [img representations]) if ([r isKindOfClass: [NSBitmapImageRep class]]) { rep = (NSBitmapImageRep *)r; break; }
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
