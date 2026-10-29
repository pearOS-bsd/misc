#if __has_include(<AppKit/NSAppearance.h>)
#import <AppKit/NSAppearance.h>
#define WSD_HAVE_APPEARANCE 1
#endif
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSDisplayServer.h>
static IMP origMenuSize, origMenuTextColor, origMenuKeyEq, origMenuState, origTFDraw, origTFRect, origMakeFR, origKeyEqStr; static NSString *wsdKeyEqString(id self, SEL _cmd); static BOOL wsdMakeFirstResponder(id self, SEL _cmd, NSResponder *r); static void wsdTFDraw(id self, SEL _cmd, NSRect f, NSView *v); 
static void wsdTFRect(id self, SEL _cmd, NSRect r);
@interface GSDisplayServer (WsdBlur) - (void) wsdBackgroundBlur: (int)radius : (int)win; - (void) wsdMenuGlass: (int)win : (int)width : (int)height; @end
#include <stdlib.h>
#import <objc/runtime.h>
#include <math.h>
#include <string.h>
#import "wsd/WsdMacTheme.h"

/* WSD_APPEARANCE=light switches the palette; the measurements are of the dark appearance (the light one is typical macOS, not measured) */
static void wsdMenuSizeToFit(id self, SEL _cmd); static NSColor *wsdMenuTextColor(id self, SEL _cmd); static void wsdMenuDrawKeyEq(id self, SEL _cmd, NSRect f, NSView *v); static void wsdMenuDrawState(id self, SEL _cmd, NSRect f, NSView *v);
extern void WsdToggleFullscreen(NSWindow *w); extern void WsdShowTilePopover(NSWindow *w, NSRect r); extern BOOL WsdIsFullscreen(NSWindow *w);
extern void WsdInstallFilePanel(void); extern void WsdInstallDragDrop(void); extern void WsdInstallMenuBar(void); extern void WsdInstallPopover(void); extern void WsdInstallSheets(void);
extern NSColor *WsdTintedWindowBackground(NSWindow *w); extern BOOL WsdMenuBarPrepare(NSMenu *m); extern NSRect WsdBarItemRect(NSMenuView *mv, NSInteger i, NSRect r); extern void WsdDrawBarItem(NSMenuItemCell *cell, NSRect f, BOOL highlighted); extern NSColor *WsdBarTextColor(BOOL enabled); extern BOOL WsdIsPearItem(NSMenuItem *i); extern BOOL WsdAppearanceIsDark(void); extern void WsdInstallAppearanceWatch(void);
static BOOL isDark(void) { return WsdAppearanceIsDark(); }

static NSColor *rgb(int r, int g, int b, CGFloat a) { return [NSColor colorWithCalibratedRed: r / 255.0 green: g / 255.0 blue: b / 255.0 alpha: a]; }

/* the system colours: derived from the window background (WSD_WINDOW_BG=r,g,b overrides the neutral default; on macOS the dark window colour is tinted by the wallpaper, (27,36,43) on the machine the measurements come from) */
static void windowBG(int *r, int *g, int *b)
{
	*r = *g = *b = isDark() ? 30 : 255;
	const char *e = getenv("WSD_WINDOW_BG");
	if (e) { int x, y, z; if (sscanf(e, "%d,%d,%d", &x, &y, &z) == 3) { *r = x; *g = y; *b = z; } }
}
static int mix(int base, int top, double a) { return (int)(base * (1 - a) + top * a + 0.5); }

/* San Francisco is not redistributable: Inter (pkg inter-font) is the closest free face; the GNUstep font defaults are pointed at it when it is installed */
static void applyFonts(void)
{
	NSString *reg[] = { @"Inter-SemiBold", @"Inter-Medium", @"Inter-Regular", @"Inter" }, *bold[] = { @"Inter-Bold", @"Inter Bold", @"Inter-SemiBold", @"Inter SemiBold" };
	NSString *r = nil, *b = nil;
	NSArray *avail = [[NSFontManager sharedFontManager] availableFonts];
	for (int i = 0; i < 4 && !r; i++) if ([avail containsObject: reg[i]]) r = reg[i];      /* macOS draws the system font with a heavier rendering: Inter Medium is the closest weight */
	for (int i = 0; i < 4 && !b; i++) if ([avail containsObject: bold[i]]) b = bold[i];
	if (getenv("WSD_DEBUG")) {
		NSMutableArray *inter = [NSMutableArray array];
		for (NSString *n in [[NSFontManager sharedFontManager] availableFonts]) if ([n rangeOfString: @"Inter" options: NSCaseInsensitiveSearch].location != NSNotFound) [inter addObject: n];
		NSLog(@"wsd fonts: regular=%@ bold=%@ available=%lu inter=%@ first=%@", r, b, (unsigned long)[[[NSFontManager sharedFontManager] availableFonts] count], inter, [[[NSFontManager sharedFontManager] availableFonts] subarrayWithRange: NSMakeRange(0, MIN(6, [[[NSFontManager sharedFontManager] availableFonts] count]))]);
	}
	NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
	if (r) for (NSString *k in @[@"NSFont", @"NSUserFont", @"NSControlContentFont", @"NSLabelFont", @"NSMessageFont", @"NSMenuFont", @"NSPaletteFont", @"NSToolTipsFont"]) [d setObject: r forKey: k];
	if (b) for (NSString *k in @[@"NSBoldFont", @"NSTitleBarFont"]) [d setObject: b forKey: k];
	[d setObject: @"NSMacintoshInterfaceStyle" forKey: @"NSScrollViewInterfaceStyle"];
	[d setObject: @"NSMacintoshInterfaceStyle" forKey: @"NSMenuInterfaceStyle"];
	[d setObject: @"\u2318" forKey: @"GSCommandKeyString"]; [d setObject: @"\u2303" forKey: @"GSControlKeyString"]; [d setObject: @"\u2325" forKey: @"GSAlternateKeyString"]; [d setObject: @"\u21E7" forKey: @"GSShiftKeyString"];      /* the key equivalent symbols: command, control, option, shift */
	[d setBool: YES forKey: @"GSSuppressAppIcon"];                                           /* no application icon tile on the desktop (the Dock is not emulated) */                      /* the menu as a bar across the top of the screen */              /* the vertical scroller on the right */
	[d setBool: YES forKey: @"GSScrollViewNoInnerBorder"];              /* scroll views have no inner border on macOS */
}

/* radio buttons and check boxes: GNUstep draws them from the named images NSRadioButton / NSHighlightedRadioButton and NSSwitch / NSHighlightedSwitch; the images drawn here are the macOS ones
 * (16 pt controls, filled white at 10 % over the window when off, the accent blue with a white dot / check when on), with the 6 pt gap to the title built into the image */
static double segDist(double px, double py, double ax, double ay, double bx, double by)
{
	double dx = bx - ax, dy = by - ay, t = ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy);
	t = t < 0 ? 0 : t > 1 ? 1 : t;
	double cx = ax + t * dx - px, cy = ay + t * dy - py; return sqrt(cx * cx + cy * cy);
}

/* the pixels are computed here (coverage of a signed distance), not drawn with lockFocus: that does not depend on the display server being up */
static NSImage *controlImage(BOOL radio, BOOL on)
{
	int wr, wg, wb; windowBG(&wr, &wg, &wb); BOOL dark = isDark(); int fg = dark ? 255 : 0;
	const int W = 16, H = 16;                                    /* square: the cell scales the image into a square, a wider image would be squeezed */
	int fr = on ? 0 : mix(wr, fg, dark ? 0.10 : 0.06), fgc = on ? 122 : mix(wg, fg, dark ? 0.10 : 0.06), fb = on ? 255 : mix(wb, fg, dark ? 0.10 : 0.06);
	unsigned char *buf = calloc((size_t)W * H, 4);
	for (int y = 0; y < H; y++)
		for (int x = 0; x < W; x++) {
			double px = x + 0.5, py = y + 0.5, d;                                       /* y runs down the image */
			if (radio) d = sqrt((px - 8) * (px - 8) + (py - 8) * (py - 8)) - 8;
			else { double qx = fabs(px - 8) - 4, qy = fabs(py - 8) - 4, ox = qx > 0 ? qx : 0, oy = qy > 0 ? qy : 0, m = qx > qy ? qx : qy; d = sqrt(ox * ox + oy * oy) + (m < 0 ? m : 0) - 4; }      /* rounded square: half size 8, radius 4 */
			double cov = 0.5 - d; cov = cov < 0 ? 0 : cov > 1 ? 1 : cov;
			double r = fr, g = fgc, b = fb;
			if (on) {
				double m;
				if (radio) m = 0.5 - (sqrt((px - 8) * (px - 8) + (py - 8) * (py - 8)) - 3);
				else { double dd = segDist(px, py, 4, 7.8, 6.9, 11) < segDist(px, py, 6.9, 11, 12, 4.8) ? segDist(px, py, 4, 7.8, 6.9, 11) : segDist(px, py, 6.9, 11, 12, 4.8); m = 0.5 - (dd - 0.9); }
				m = m < 0 ? 0 : m > 1 ? 1 : m;
				r = r * (1 - m) + 255 * m; g = g * (1 - m) + 255 * m; b = b * (1 - m) + 255 * m;
			}
			unsigned char *o = buf + ((size_t)y * W + x) * 4;
			o[0] = (unsigned char)(r * cov + 0.5); o[1] = (unsigned char)(g * cov + 0.5); o[2] = (unsigned char)(b * cov + 0.5); o[3] = (unsigned char)(cov * 255 + 0.5);      /* premultiplied */
		}
	NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes: NULL pixelsWide: W pixelsHigh: H bitsPerSample: 8 samplesPerPixel: 4 hasAlpha: YES isPlanar: NO
		colorSpaceName: NSDeviceRGBColorSpace bytesPerRow: W * 4 bitsPerPixel: 32];
	memcpy([rep bitmapData], buf, (size_t)W * H * 4); free(buf);
	NSImage *img = [[NSImage alloc] initWithSize: NSMakeSize(W, H)];
	[img addRepresentation: rep]; [rep release];
	return img;
}

/* the combo box button's arrow: a small chevron pointing down (the stock image is a row of dots here) */
static NSImage *comboChevron(void)
{
	const int W = 12, H = 12; unsigned char *buf = calloc((size_t)W * H, 4); int c = isDark() ? 215 : 70;
	for (int y = 0; y < H; y++)
		for (int x = 0; x < W; x++) {
			double px = x + 0.5, py = y + 0.5;
			double d1 = segDist(px, py, 2.5, 4.2, 6.0, 7.8), d2 = segDist(px, py, 6.0, 7.8, 9.5, 4.2), d = d1 < d2 ? d1 : d2;
			double cov = 0.5 - (d - 0.8); cov = cov < 0 ? 0 : cov > 1 ? 1 : cov;
			unsigned char *o = buf + ((size_t)y * W + x) * 4; o[0] = (unsigned char)(c * cov + 0.5); o[1] = o[0]; o[2] = o[0]; o[3] = (unsigned char)(cov * 255 + 0.5);
		}
	NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes: NULL pixelsWide: W pixelsHigh: H bitsPerSample: 8 samplesPerPixel: 4 hasAlpha: YES isPlanar: NO colorSpaceName: NSDeviceRGBColorSpace bytesPerRow: W * 4 bitsPerPixel: 32];
	memcpy([rep bitmapData], buf, (size_t)W * H * 4); free(buf);
	NSImage *img = [[[NSImage alloc] initWithSize: NSMakeSize(W, H)] autorelease]; [img addRepresentation: rep]; [rep release];
	return img;
}

/* made when the first window exists (the images are drawn with lockFocus, which needs a working display server) */
extern void WsdInstallCGBridge(void);
static void installControlImages(void)
{
	static BOOL done; if (done) return; done = YES;
	@try {
		/* +imageNamed: maps the OpenStep names (NSRadioButton ...) to the library's real names before looking them up: take the stock image out under its real name and put ours in */
		NSString *keys[4] = { @"NSRadioButton", @"NSHighlightedRadioButton", @"NSSwitch", @"NSHighlightedSwitch" };
		BOOL radio[4] = { YES, YES, NO, NO }, on[4] = { NO, YES, NO, YES };
		for (int i = 0; i < 4; i++) {
			NSImage *old = [NSImage imageNamed: keys[i]]; NSString *real = old && [old name] ? [[old name] copy] : keys[i];
			if (old) [old setName: nil];
			NSImage *nu = controlImage(radio[i], on[i]);
			BOOL ok = [nu setName: real];
			if (getenv("WSD_DEBUG")) NSLog(@"wsd control image %@ -> %@ replaced=%d named=%d", keys[i], real, old != nil, ok);
		}
		{ NSImage *old = [NSImage imageNamed: @"NSComboArrow"]; NSString *real = old && [old name] ? [[old name] copy] : @"NSComboArrow"; if (old) [old setName: nil]; [comboChevron() setName: real]; }
		for (NSString *nm in @[@"common_Nibble", @"common_3DArrowDown", @"common_ret", @"common_retH", @"NSMenuArrow", @"NSHighlightedMenuArrow", @"common_3DArrowRight", @"common_3DArrowRightH"]) {              /* the stock pop-up arrows are blanked: the theme draws the chevrons */
			NSImage *old = [NSImage imageNamed: nm]; NSString *real = old && [old name] ? [[old name] copy] : nm; NSSize sz = old ? [old size] : NSMakeSize(8, 8);
			if (old) [old setName: nil];
			NSImage *blank = [[NSImage alloc] initWithSize: sz]; [blank setName: real];
		}
		const char *dump = getenv("WSD_DUMP_IMAGES");
		if (dump) {
			NSString *names[4] = { @"NSRadioButton", @"NSHighlightedRadioButton", @"NSSwitch", @"NSHighlightedSwitch" };
			for (int i = 0; i < 4; i++) {
				NSImage *im = [NSImage imageNamed: names[i]];
				NSData *t = [im TIFFRepresentation];
				NSLog(@"wsd image %@: size %@ tiff %lu bytes", names[i], NSStringFromSize([im size]), (unsigned long)[t length]);
				[t writeToFile: [NSString stringWithFormat: @"%s/wsd-%@.tiff", dump, names[i]] atomically: YES];
			}
		}
	} @catch (NSException *e) { NSLog(@"wsd theme: control images: %@", e); }
}

/* GNUstep's table views start with solid grid lines and 16 pt rows; Cocoa's have no grid and 24 pt rows */
static IMP origTableInit;
static void wsdTableInit(id self, SEL _cmd)
{
	((void (*)(id, SEL))origTableInit)(self, _cmd);
	[(NSTableView *)self setGridStyleMask: 0]; [(NSTableView *)self setRowHeight: 24.0]; [(NSTableView *)self setIntercellSpacing: NSMakeSize(11, 2)];                    /* the cell text starts ~6 pt in, as in Cocoa's cell padding */
}
/* GNUstep shows a pressed check box / radio button as the reversed state (NeXT); macOS keeps the state while the mouse is down: draw them as if not pressed */
static IMP origButtonInterior;
static void wsdButtonInterior(id self, SEL _cmd, NSRect f, NSView *v)
{
	NSButtonCell *c = self; BOOL hl = [c isHighlighted];
	BOOL toggle = hl && [c image] && ([c imagePosition] == NSImageLeft || [c imagePosition] == NSImageRight) && ![c isBordered] && [c alternateImage];
	if (toggle) [c setHighlighted: NO];
	if ([c image] && ([c imagePosition] == NSImageLeft || [c imagePosition] == NSImageRight) && ![c isBordered] && [c alternateImage]) f.origin.y += [v isFlipped] ? -1 : 1;   /* measured: check boxes and radios sit 1 pt higher on the Mac */
	((void (*)(id, SEL, NSRect, NSView *))origButtonInterior)(self, _cmd, f, v);
	if (toggle) [c setHighlighted: YES];
}

/* the generic application icon (a light rounded square with a faint grid), pixels computed like the control images: GNUstep's stock icon has hard black corners */
static NSImage *genericAppIcon(void)
{
	const int N = 64; unsigned char *buf = calloc((size_t)N * N, 4);
	for (int y = 0; y < N; y++)
		for (int x = 0; x < N; x++) {
			double px = x + 0.5, py = y + 0.5, qx = fabs(px - N / 2.0) - (N / 2.0 - 14), qy = fabs(py - N / 2.0) - (N / 2.0 - 14), ox = qx > 0 ? qx : 0, oy = qy > 0 ? qy : 0;
			double d = sqrt(ox * ox + oy * oy) + ((qx > qy ? qx : qy) < 0 ? (qx > qy ? qx : qy) : 0) - 14, cov = 0.5 - d; cov = cov < 0 ? 0 : cov > 1 ? 1 : cov;
			double t = py / N, r = 236 - 30 * t, g = 241 - 28 * t, b = 246 - 22 * t;
			int gx = (x % 16 == 0 || x % 16 == 1), gy = (y % 16 == 0 || y % 16 == 1);
			if ((gx || gy) && x > 6 && x < N - 6 && y > 6 && y < N - 6) { r += (255 - r) * 0.6; g += (255 - g) * 0.6; b += (255 - b) * 0.6; }
			unsigned char *o = buf + ((size_t)y * N + x) * 4;
			o[0] = (unsigned char)(r * cov + 0.5); o[1] = (unsigned char)(g * cov + 0.5); o[2] = (unsigned char)(b * cov + 0.5); o[3] = (unsigned char)(cov * 255 + 0.5);
		}
	NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes: NULL pixelsWide: N pixelsHigh: N bitsPerSample: 8 samplesPerPixel: 4 hasAlpha: YES isPlanar: NO colorSpaceName: NSDeviceRGBColorSpace bytesPerRow: N * 4 bitsPerPixel: 32];
	memcpy([rep bitmapData], buf, (size_t)N * N * 4); free(buf);
	NSImage *img = [[[NSImage alloc] initWithSize: NSMakeSize(N, N)] autorelease]; [img addRepresentation: rep]; [rep release];
	return img;
}
NSImage *WsdGenericAppIcon(void) { return genericAppIcon(); }
static void fillRound(NSRect r, CGFloat radius, NSColor *c);
/* ---- NSAlert as macOS draws it: no title bar, a rounded panel (radius 26), the icon, a bold title, the informative text and capsule buttons side by side (the first button, on the right, is the default one) ---- */
@interface WsdAlertBack : NSView @end
@implementation WsdAlertBack
- (BOOL) isFlipped { return YES; }
- (void) drawRect: (NSRect)r { [[NSColor clearColor] set]; NSRectFill(r); fillRound([self bounds], 26.0, isDark() ? rgb(31, 31, 31, 1) : rgb(236, 236, 236, 1)); }
@end
@interface WsdAlertTarget : NSObject { @public NSInteger code; } - (void) pressed: (id)b; @end
@implementation WsdAlertTarget - (void) pressed: (id)b { [NSApp stopModalWithCode: [b tag]]; } @end

/* a pop-up button: the title is left aligned 11 pt in, the chevrons are on the right (GNUstep centres the title of a menu item cell, which runs into the chevrons of a narrow button); measured on the Mac
 * with the pop-ups of the Finder's rename sheet (109 wide, the title starting 11 pt in) */
static IMP origPopupInterior;
static void wsdPopupInterior(NSPopUpButtonCell *self, SEL _cmd, NSRect f, NSView *v)
{
	NSString *t = [self titleOfSelectedItem]; if (![t length] && [self pullsDown]) t = [self title]; if (![t length]) { ((void (*)(id, SEL, NSRect, NSView *))origPopupInterior)(self, _cmd, f, v); return; }
	[[GSTheme theme] drawPopUpButtonCellInteriorWithFrame: f withCell: self inView: v];
	NSMutableParagraphStyle *ps = [[[NSMutableParagraphStyle alloc] init] autorelease]; [ps setLineBreakMode: NSLineBreakByTruncatingTail];
	NSDictionary *a = @{ NSFontAttributeName: [self font] ?: [NSFont systemFontOfSize: 13], NSForegroundColorAttributeName: [self isEnabled] ? [NSColor controlTextColor] : [NSColor disabledControlTextColor], NSParagraphStyleAttributeName: ps };
	NSSize z = [t sizeWithAttributes: a]; [t drawInRect: NSMakeRect(f.origin.x + 11, NSMidY(f) - z.height / 2, MAX(8, f.size.width - 11 - 18), z.height) withAttributes: a];
}
static IMP origAlertRun;
static NSInteger wsdAlertRun(id self, SEL _cmd)
{
	NSAlert *al = self; NSArray *btns = [al buttons]; if (![btns count]) return ((NSInteger (*)(id, SEL))origAlertRun)(self, _cmd);
	const CGFloat W = 260, M = 22, TW = W - 2 * M;
	NSString *title = [al messageText] ?: @"", *info = [al informativeText] ?: @"";
	NSFont *tf = [NSFont boldSystemFontOfSize: 13], *bf = [NSFont systemFontOfSize: 13];
	NSColor *fgc = [NSColor controlTextColor];
	NSDictionary *ta = @{ NSFontAttributeName: tf, NSForegroundColorAttributeName: fgc }, *ba = @{ NSFontAttributeName: bf, NSForegroundColorAttributeName: fgc };
	CGFloat th = 0, ih = 0;
	NSTextStorage *st = [[[NSTextStorage alloc] initWithString: title attributes: ta] autorelease]; NSLayoutManager *lm = [[[NSLayoutManager alloc] init] autorelease];
	NSTextContainer *tc = [[[NSTextContainer alloc] initWithContainerSize: NSMakeSize(TW, 10000)] autorelease]; [tc setLineFragmentPadding: 0]; [lm addTextContainer: tc]; [st addLayoutManager: lm];
	th = ceil([lm usedRectForTextContainer: tc].size.height);
	NSTextStorage *st2 = [[[NSTextStorage alloc] initWithString: info attributes: ba] autorelease]; NSLayoutManager *lm2 = [[[NSLayoutManager alloc] init] autorelease];
	NSTextContainer *tc2 = [[[NSTextContainer alloc] initWithContainerSize: NSMakeSize(TW, 10000)] autorelease]; [tc2 setLineFragmentPadding: 0]; [lm2 addTextContainer: tc2]; [st2 addLayoutManager: lm2];
	ih = [info length] ? ceil([lm2 usedRectForTextContainer: tc2].size.height) : 0;
	CGFloat y = 26, iconY = y; y += 52 + 20;
	CGFloat titleY = y; y += th + 11; CGFloat infoY = y; y += ih + (ih ? 11 : 4);
	CGFloat btnY = y, H = y + 28 + 16;
	NSPanel *p = [[NSPanel alloc] initWithContentRect: NSMakeRect(0, 0, W, H) styleMask: NSBorderlessWindowMask backing: NSBackingStoreBuffered defer: NO];
	[p setOpaque: NO]; [p setBackgroundColor: [NSColor clearColor]]; [p setHasShadow: YES]; [p setLevel: NSModalPanelWindowLevel];
	WsdAlertBack *back = [[[WsdAlertBack alloc] initWithFrame: NSMakeRect(0, 0, W, H)] autorelease]; [p setContentView: back];
	NSImage *ic = [al icon]; if (!ic || ic == [NSApp applicationIconImage] || [[ic name] isEqualToString: @"NSApplicationIcon"]) ic = genericAppIcon();
	if (ic) { NSImageView *iv = [[[NSImageView alloc] initWithFrame: NSMakeRect(26, iconY, 52, 52)] autorelease]; [iv setImage: ic]; [iv setImageScaling: NSImageScaleProportionallyUpOrDown]; [back addSubview: iv]; }
	NSTextField *(^label)(NSString *, NSDictionary *, NSRect) = ^NSTextField *(NSString *t, NSDictionary *a, NSRect f) {
		NSTextField *l = [[[NSTextField alloc] initWithFrame: f] autorelease]; [l setBezeled: NO]; [l setDrawsBackground: NO]; [l setEditable: NO]; [l setSelectable: NO];
		[l setAttributedStringValue: [[[NSAttributedString alloc] initWithString: t attributes: a] autorelease]]; return l; };
	[back addSubview: label(title, ta, NSMakeRect(M, titleY, TW, th))];
	if (ih) [back addSubview: label(info, ba, NSMakeRect(M, infoY, TW, ih))];
	WsdAlertTarget *tg = [[[WsdAlertTarget alloc] init] autorelease];
	NSUInteger n = [btns count]; CGFloat gap = 8, bw = n > 1 ? (W - 32 - gap * (n - 1)) / n : W - 32;
	for (NSUInteger i = 0; i < n; i++) {                                           /* the first button is the rightmost, as on macOS */
		NSButton *src = [btns objectAtIndex: i];
		NSButton *b = [[[NSButton alloc] initWithFrame: NSMakeRect(16 + (n - 1 - i) * (bw + gap), btnY, bw, 28)] autorelease];
		[b setTitle: [src title]]; [b setBezelStyle: NSRoundedBezelStyle]; [b setTag: NSAlertFirstButtonReturn + (NSInteger)i]; [b setTarget: tg]; [b setAction: @selector(pressed:)];
		if (i == 0) [b setKeyEquivalent: @"\r"]; else if (![[src keyEquivalent] length] && [[[src title] lowercaseString] isEqualToString: @"cancel"]) [b setKeyEquivalent: @"\033"];
		[back addSubview: b];
	}
	[p center]; [p makeKeyAndOrderFront: nil];
	NSInteger rc = [NSApp runModalForWindow: p];
	[p orderOut: nil]; [p release];
	return rc;
}
/* GNUstep centres a segment's label twice (it offsets the frame by half the free space, then centres inside that): left aligned inside the offset frame it lands in the middle, as on macOS */
static IMP origSegDraw;
static void wsdSegDraw(id self, SEL _cmd, NSInteger seg, NSRect f, NSView *v)
{
	[(NSSegmentedCell *)self setAlignment: NSLeftTextAlignment];
	((void (*)(id, SEL, NSInteger, NSRect, NSView *))origSegDraw)(self, _cmd, seg, f, v);
}
/* NSSegmentStyleCapsule: the segmented control of the toolbars of macOS 26 (a glass capsule, the selected segment a lit pill inside it). Measured on the Finder's toolbar (dark): 36 high, fill 60 lit to 68 at the top and
 * bottom edges, a dark ring (11) at the sides, a bright hairline (98) along the straight top and bottom edges; the selected segment 80, a pressed one white 8 %, the images 20 pt. */
static IMP origSegCellDraw;
void WsdDrawGlassCapsule(NSRect r, NSRect pressed)
{
	BOOL dk = isDark(); CGFloat rad = r.size.height / 2; NSGraphicsContext *g = [NSGraphicsContext currentContext]; NSBezierPath *body = [NSBezierPath bezierPathWithRoundedRect: r xRadius: rad yRadius: rad];
	[g saveGraphicsState]; [body addClip];
	NSColor *hi = dk ? [NSColor colorWithCalibratedWhite: 68 / 255.0 alpha: 1] : [NSColor whiteColor], *mid = dk ? [NSColor colorWithCalibratedWhite: 60 / 255.0 alpha: 1] : [NSColor colorWithCalibratedWhite: 246 / 255.0 alpha: 1];
	NSGradient *gr = [[[NSGradient alloc] initWithColorsAndLocations: hi, 0.0, mid, 0.2, mid, 0.8, hi, 1.0, nil] autorelease]; [gr drawInRect: r angle: 90];
	[g restoreGraphicsState];
	NSBezierPath *ring = [NSBezierPath bezierPathWithRoundedRect: NSInsetRect(r, 0.5, 0.5) xRadius: rad - 0.5 yRadius: rad - 0.5]; [ring setLineWidth: 1]; [(dk ? [NSColor colorWithCalibratedWhite: 0 alpha: 0.7] : [NSColor colorWithCalibratedWhite: 0 alpha: 0.14]) setStroke]; [ring stroke];
	[g saveGraphicsState]; [[NSBezierPath bezierPathWithRect: NSMakeRect(r.origin.x + rad, r.origin.y, r.size.width - rad * 2, r.size.height)] addClip];
	NSBezierPath *tb = [NSBezierPath bezierPath]; [tb moveToPoint: NSMakePoint(r.origin.x + rad, r.origin.y + 0.5)]; [tb lineToPoint: NSMakePoint(NSMaxX(r) - rad, r.origin.y + 0.5)]; [tb moveToPoint: NSMakePoint(r.origin.x + rad, NSMaxY(r) - 0.5)]; [tb lineToPoint: NSMakePoint(NSMaxX(r) - rad, NSMaxY(r) - 0.5)];
	[tb setLineWidth: 1]; [(dk ? [NSColor colorWithCalibratedWhite: 1 alpha: 0.2] : [NSColor colorWithCalibratedWhite: 1 alpha: 0.9]) setStroke]; [tb stroke]; [g restoreGraphicsState];
}
static void wsdSegCellDraw(id self, SEL _cmd, NSRect frame, NSView *v)
{
	NSSegmentedCell *c = self; if (![self isKindOfClass: [NSSegmentedCell class]] || (NSInteger)[c segmentStyle] != 5) { ((void (*)(id, SEL, NSRect, NSView *))origSegCellDraw)(self, _cmd, frame, v); return; }
	NSInteger n = [c segmentCount]; BOOL dk = isDark(); WsdDrawGlassCapsule(frame, NSZeroRect); CGFloat fixed = 0; NSInteger flex = 0; for (NSInteger i = 0; i < n; i++) { CGFloat w = [c widthForSegment: i]; if (w > 0) fixed += w; else flex++; }
	CGFloat fw = flex ? (frame.size.width - fixed) / flex : 0, x = frame.origin.x;
	for (NSInteger i = 0; i < n; i++) {
		CGFloat w = [c widthForSegment: i]; if (w <= 0) w = fw; if (!flex && fixed > 0) w = w * frame.size.width / fixed; NSRect sr = NSMakeRect(x, frame.origin.y, w, frame.size.height); x += w; { NSArray *its = [c valueForKey: @"_items"]; if (i < (NSInteger)[its count] && [its[i] respondsToSelector: @selector(setFrame:)]) { NSRect fr = sr; ((void (*)(id, SEL, NSRect))objc_msgSend)(its[i], @selector(setFrame:), fr); } }       /* the cell finds the segment of a click through the frames it stored while drawing */
		BOOL sel = [c isSelectedForSegment: i] && [c trackingMode] != NSSegmentSwitchTrackingMomentary; if (sel) { NSRect in = NSInsetRect(sr, 4, 4); [(dk ? [NSColor colorWithCalibratedWhite: 80 / 255.0 alpha: 1] : [NSColor colorWithCalibratedWhite: 0 alpha: 0.12]) setFill]; [[NSBezierPath bezierPathWithRoundedRect: in xRadius: 14 yRadius: 14] fill]; }
		{ NSInteger selIx = [c selectedSegment]; if ([c trackingMode] == NSSegmentSwitchTrackingMomentary) selIx = -9; if (i > 0 && i != selIx && i - 1 != selIx && ![[(NSControl *)v identifier] isEqual: @"nosep"]) { [(dk ? [NSColor colorWithCalibratedWhite: 1 alpha: 0.27] : [NSColor colorWithCalibratedWhite: 0 alpha: 0.2]) setFill]; NSRectFill(NSMakeRect(sr.origin.x, NSMidY(sr) - 10, 1, 20)); } }       /* the lines between the segments, none next to the selected one */
		NSImage *im = [c imageForSegment: i]; NSColor *tint = dk ? [NSColor colorWithCalibratedWhite: 1 alpha: 0.92] : [NSColor colorWithCalibratedWhite: 0.1 alpha: 0.9];
		if (im) { NSSize z = [im size]; if (z.width < 1) z = NSMakeSize(20, 20); CGFloat k = MIN(20 / z.width, 20 / z.height); NSRect ir = NSMakeRect(NSMidX(sr) - z.width * k / 2, NSMidY(sr) - z.height * k / 2, z.width * k, z.height * k); [im drawInRect: ir fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: [c isEnabledForSegment: i] ? 1.0 : 0.28]; (void)tint; }
	}
}
/* titles of push buttons: the text colour never changes while the button is pressed (GNUstep switches to the selection colour); the default button has white text */
static IMP origButtonTextColor;
static NSColor *wsdButtonTextColor(id self, SEL _cmd)
{
	NSButtonCell *c = self;
	if (![c isEnabled]) return [NSColor disabledControlTextColor];
	if ([[c keyEquivalent] isEqualToString: @"\r"] && [c bezelStyle] != 0) return [NSColor whiteColor];
	if ([c image] || [c isBordered] == NO) return ((NSColor *(*)(id, SEL))origButtonTextColor)(self, _cmd);
	return [NSColor controlTextColor];
}
/* the check box / radio image has the 6 pt gap built in on macOS, GNUstep leaves only ~2.5 pt between image and title: a three-per-em space (4.3 pt at 13 pt) in front of the title makes up the difference */
static IMP origAttrTitle;
static NSAttributedString *wsdAttrTitle(id self, SEL _cmd)
{
	NSAttributedString *t = ((NSAttributedString *(*)(id, SEL))origAttrTitle)(self, _cmd);
	NSButtonCell *c = self;
	if (!t || ![t length] || ![c image] || [c isBordered] || ([c imagePosition] != NSImageLeft)) return t;
	NSDictionary *a = [t attributesAtIndex: 0 effectiveRange: NULL];
	NSMutableAttributedString *m = [[[NSMutableAttributedString alloc] initWithString: @"\u2004" attributes: a] autorelease];
	[m appendAttributedString: t];
	return m;
}
/* table headers are 28 pt high on macOS (GNUstep: 22) */
static IMP origHeaderInit;
static id wsdHeaderInit(id self, SEL _cmd, NSRect f)
{
	if (f.size.height > 15 && f.size.height < 30) f.size.height = 28;
	return ((id (*)(id, SEL, NSRect))origHeaderInit)(self, _cmd, f);
}
/* a date picker's text stays on one line and is clipped (GNUstep wraps the time under the date) */
static IMP origDatePickerDraw; static BOOL gInDatePicker;
static IMP origComboDraw;
/* measured: the combo box's text and chevron sit 3 pt higher than GNUstep's interior frame puts them */
static void wsdComboDraw(id self, SEL _cmd, NSRect f, NSView *v)
{
	f.origin.y += [v isFlipped] ? -3 : 3;
	f.origin.x += 3; f.size.width -= 3;       /* measured on the Mac's UITest (combo box 132 x 28): the text starts 8 pt from the left edge of the field, GNUstep's 5 */
	((void (*)(id, SEL, NSRect, NSView *))origComboDraw)(self, _cmd, f, v);
}

static void wsdDatePickerDraw(id self, SEL _cmd, NSRect f, NSView *v)
{
	[(NSCell *)self setWraps: NO]; [(NSCell *)self setLineBreakMode: NSLineBreakByClipping];
	gInDatePicker = YES; ((void (*)(id, SEL, NSRect, NSView *))origDatePickerDraw)(self, _cmd, f, v); gInDatePicker = NO;
}
static IMP origDatePickerWith;
static void wsdDatePickerWith(id self, SEL _cmd, NSRect f, NSView *v)
{
	[(NSCell *)self setFont: [NSFont systemFontOfSize: 13]];
	gInDatePicker = YES; ((void (*)(id, SEL, NSRect, NSView *))origDatePickerWith)(self, _cmd, f, v); gInDatePicker = NO;
}
/* NSVisualEffectView (a stub in GNUstep): a translucent material tint; with behind-window blending the window turns non-opaque and the compositor blurs what is behind it */
static IMP origVEVDraw, origVEVMove;
static void wsdVEVDraw(id self, SEL _cmd, NSRect r)
{
	BOOL dark = isDark(); NSInteger m = (NSInteger)[self performSelector: @selector(material)];                  /* by selector: older GNUstep releases have no NSVisualEffectView header */
	/* what the real materials do to a flat backdrop, measured on the Mac (tools: a window with an NSVisualEffectView, behind-window, over uniform greys 0/64/128/192/255, both appearances): out = (1 - a) * backdrop + a * c, a and c per material; the fit's error is 5 levels at most. Raw values of NSVisualEffectMaterial. */
	static const struct { int m; double a[2]; int c[2][3]; } T[] = {                                               /* [0] dark, [1] light */
		{ 3,  { 0.811, 0.810 }, { { 57, 63, 68 },   { 237, 244, 249 } } },    /* titlebar */
		{ 5,  { 0.726, 0.769 }, { { 40, 47, 52 },   { 222, 229, 234 } } },    /* menu */
		{ 6,  { 0.634, 0.645 }, { { 40, 49, 55 },   { 220, 229, 234 } } },    /* popover */
		{ 7,  { 0.823, 0.898 }, { { 40, 47, 51 },   { 222, 228, 233 } } },    /* sidebar */
		{ 10, { 0.814, 0.801 }, { { 27, 38, 45 },   { 255, 255, 255 } } },    /* header view */
		{ 11, { 1.0,   1.0 },   { { 28, 39, 46 },   { 255, 255, 255 } } },    /* sheet: opaque */
		{ 12, { 1.0,   1.0 },   { { 27, 39, 46 },   { 255, 255, 255 } } },    /* window background: opaque */
		{ 13, { 0.441, 0.525 }, { { 40, 52, 61 },   { 216, 227, 234 } } },    /* HUD window */
		{ 14, { 0.88,  0.05 },  { { 20, 20, 20 },   { 0, 0, 0 } } },          /* full screen UI */
		{ 15, { 0.541, 0.525 }, { { 40, 51, 57 },   { 216, 227, 234 } } },    /* tool tip */
		{ 17, { 0.823, 0.898 }, { { 40, 47, 51 },   { 222, 228, 233 } } },    /* content background (the same as the sidebar's on the Mac) */
		{ 21, { 0.823, 0.898 }, { { 40, 47, 51 },   { 222, 228, 233 } } },    /* under window background */
	};
	int k = -1; for (int i = 0; i < (int)(sizeof T / sizeof T[0]); i++) if (T[i].m == m) k = i; if (k < 0) k = 1;                      /* unknown: as the menu */
	int d = dark ? 0 : 1; NSColor *tint = rgb(T[k].c[d][0], T[k].c[d][1], T[k].c[d][2], T[k].a[d]);
	[tint set]; NSRectFillUsingOperation(r, NSCompositeSourceOver);
}
static void wsdVEVMove(id self, SEL _cmd)
{
	NSWindow *w = [(NSView *)self window];
	if (w && (NSInteger)[self performSelector: @selector(blendingMode)] == 0 /* behind window */) {
		[w setOpaque: NO]; [w setBackgroundColor: [NSColor clearColor]];
		id srv = GSCurrentServer();
		if ([srv respondsToSelector: @selector(wsdBackgroundBlur::)]) [srv wsdBackgroundBlur: 31 : (int)[w windowNumber]];
	}
	if (origVEVMove) ((void (*)(id, SEL))origVEVMove)(self, _cmd);
}
/* macOS keeps a window's title bar below the menu bar but lets the bottom run off the screen; GNUstep shrinks the window to fit */
/* NSMenu key equivalents as the Mac matches them: Shift counts for every key (GNUstep ignores it for letters, so Command-K and Shift-Command-K both took the first "k" item: "Network" in the Finder's Go menu); an upper-case letter in the key equivalent means Shift */
static IMP origMenuKeyEq;
static NSMenuItem *wsdFindKeyItem(NSMenu *m, NSString *k, NSUInteger mods, NSMenu **owner, NSInteger *idx)
{
	NSUInteger rel = NSCommandKeyMask | NSAlternateKeyMask | NSControlKeyMask | NSShiftKeyMask; NSArray *items = [m itemArray];
	for (NSUInteger i = 0; i < [items count]; i++) {
		NSMenuItem *it = items[i];
		if ([it hasSubmenu]) { if ([it submenu] == [NSApp servicesMenu]) continue; NSMenuItem *r = wsdFindKeyItem([it submenu], k, mods, owner, idx); if (r) return r; continue; }
		NSString *ke = [it keyEquivalent]; if (![ke length]) continue; NSUInteger mask = [it keyEquivalentModifierMask];
		if ([ke length] == 1 && [[NSCharacterSet uppercaseLetterCharacterSet] characterIsMember: [ke characterAtIndex: 0]]) { mask |= NSShiftKeyMask; ke = [ke lowercaseString]; }
		if ([ke isEqualToString: k] && (mods & rel) == (mask & rel)) { *owner = m; *idx = (NSInteger)i; return it; }
		if ([ke isEqualToString: @"+"] && [k isEqualToString: @"="] && ((mods & ~NSShiftKeyMask) & rel) == (mask & rel)) { *owner = m; *idx = (NSInteger)i; return it; }       /* command-plus is command-shift-equals on a PC keyboard (the Mac types + on the key of =) */
	}
	return nil;
}
static BOOL wsdMenuKeyEquivalent(NSMenu *self, SEL _cmd, NSEvent *e)
{
	if (([e type] != NSKeyDown && [e type] != NSKeyUp) || ![[e charactersIgnoringModifiers] length]) return NO;
	unichar c = [[e charactersIgnoringModifiers] characterAtIndex: 0]; if (c != '=' && (c < 'A' || c > 'z' || (c > 'Z' && c < 'a'))) { @try { return ((BOOL (*)(id, SEL, id))origMenuKeyEq)(self, _cmd, e); } @catch (NSException *x) { return NO; } }   /* only letters differ; GNUstep throws NSRangeException for a key such as the space bar on a menu whose items changed (the key was lost: now it goes on to the window) */
	NSString *k = [[e charactersIgnoringModifiers] lowercaseString]; NSMenu *owner = nil; NSInteger idx = -1;
	NSMenuItem *it = wsdFindKeyItem(self, k, [e modifierFlags], &owner, &idx); if (getenv("WSD_KEY_DEBUG")) NSLog(@"menu key %@ mods %lx -> %@", k, (unsigned long)[e modifierFlags], it ? [it title] : @"none"); if (!it) return NO;
	[owner update];                                          /* the items are validated against the window that is key now, not the one that was key when the menu was last updated */
	if (getenv("WSD_KEY_DEBUG")) NSLog(@"menu key: enabled %d target %@ action %@ key window %@ autoenable %d found %@ firstResp %@", (int)[it isEnabled], [it target], NSStringFromSelector([it action]), [NSApp keyWindow], (int)[owner autoenablesItems], [NSApp targetForAction: [it action]], [[NSApp keyWindow] firstResponder]);
	if ([it isEnabled]) [owner performActionForItemAtIndex: idx];
	return YES;
}
/* NSSwitch (the switch of macOS 10.15 on): GNUstep draws it through GSTheme drawSwitchInRect:forState:enabled:; here a pill in the accent colour with a white knob when it is on, a grey pill with the knob at the left when it is off
 * (proportions of the switches of the Control Center, measured: 54 x 24, the knob 20 in the pill with 2 around it; the standard NSSwitch of the Mac is 38 x 22) */
static IMP origDrawSwitch;
static void wsdDrawSwitch(id self, SEL _cmd, NSRect r, NSControlStateValue st, BOOL enabled)
{
	BOOL on = st == NSControlStateValueOn; CGFloat h = r.size.height, kd = h - 4, a = enabled ? 1.0 : 0.5; NSBezierPath *pill = [NSBezierPath bezierPathWithRoundedRect: r xRadius: h / 2 yRadius: h / 2];
	double ar, ag, ab; WsdAccentRGB(isDark(), &ar, &ag, &ab); NSColor *accent = [NSColor colorWithCalibratedRed: ar green: ag blue: ab alpha: a], *off = isDark() ? [NSColor colorWithCalibratedWhite: 1 alpha: 0.18 * a] : [NSColor colorWithCalibratedWhite: 0 alpha: 0.12 * a];
	[(on ? accent : off) setFill]; [pill fill];
	NSRect k = NSMakeRect(on ? NSMaxX(r) - kd - 2 : r.origin.x + 2, r.origin.y + 2, kd, kd); [[NSColor colorWithCalibratedWhite: 1 alpha: a] setFill]; [[NSBezierPath bezierPathWithOvalInRect: k] fill];
}
static IMP origConstrain;
static NSRect wsdConstrain(id self, SEL _cmd, NSRect f, NSScreen *scr)
{
	NSRect sf = scr ? [scr frame] : NSMakeRect(0, 0, 1280, 800);
	CGFloat top = NSMaxY(sf) - 30.0;
	if (![(NSWindow *)self isVisible]) {                                       /* a window that is about to appear is put entirely on the screen (below the menu bar) when it fits, shrunk to it when it does not, as the Mac does: GrandPerspective's result window came up 1168 wide at x 260 on a 1280 screen */
		if (f.size.width > sf.size.width) f.size.width = sf.size.width; if (f.size.height > top - sf.origin.y) f.size.height = top - sf.origin.y;
		if (NSMaxX(f) > NSMaxX(sf)) f.origin.x = NSMaxX(sf) - f.size.width; if (f.origin.x < sf.origin.x) f.origin.x = sf.origin.x;
		if (NSMaxY(f) > top) f.origin.y = top - f.size.height; if (f.origin.y < sf.origin.y) f.origin.y = sf.origin.y;
		return f;
	}
	if (NSMaxY(f) > top) f.origin.y -= NSMaxY(f) - top;
	if (f.size.width > sf.size.width) f.size.width = sf.size.width;             /* wider than the screen: shrunk to it; otherwise moved back onto it */
	/* as on the Mac a window may be moved partly off the screen: at least 80 pt of it (and its title bar) stay on it, so that it can be taken back */
	CGFloat keep = MIN(80.0, f.size.width);
	if (f.origin.x > NSMaxX(sf) - keep) f.origin.x = NSMaxX(sf) - keep;
	if (NSMaxX(f) < sf.origin.x + keep) f.origin.x = sf.origin.x + keep - f.size.width;
	if (NSMaxY(f) < sf.origin.y + 40.0) f.origin.y = sf.origin.y + 40.0 - f.size.height;
	return f;
}
/* a toolbar item's view sits at the origin of the item (a view loaded from a nib keeps the position it had in its old superview, which puts it outside the item here) */
/* a nib names a segment's image from the system catalogue by a string ("plus"): it becomes the symbol image the first time it is asked for */
static IMP origSegImage, origSegSetImage;
static id wsdSegImage(id self, SEL _cmd, NSInteger seg)
{
	id im = ((id (*)(id, SEL, NSInteger))origSegImage)(self, _cmd, seg);
	if ([im isKindOfClass: [NSString class]]) {
		NSImage *sym = [NSImage imageWithSystemSymbolName: im accessibilityDescription: nil];
		if (!sym) sym = [NSImage imageNamed: im];
		((void (*)(id, SEL, id, NSInteger))origSegSetImage)(self, @selector(setImage:forSegment:), sym, seg);
		im = sym;
	}
	return im;
}
static IMP origItemSetView;
static void wsdItemSetView(id self, SEL _cmd, NSView *v)
{
	if (v && [v superview]) { [[v retain] autorelease]; [v removeFromSuperview]; }   /* the toolbar only adopts a view without a superview (GSToolbarBackView -layout) */
	if (v) [v setFrameOrigin: NSZeroPoint];
	((void (*)(id, SEL, NSView *))origItemSetView)(self, _cmd, v);
}
static void swizzleTableDefaults(void)
{
	{ Class sc = [NSSegmentedCell class]; Method mi = class_getInstanceMethod(sc, @selector(imageForSegment:)), ms = class_getInstanceMethod(sc, @selector(setImage:forSegment:));
	  if (mi && ms && !origSegImage) { origSegSetImage = method_getImplementation(ms); origSegImage = method_getImplementation(mi); class_replaceMethod(sc, @selector(imageForSegment:), (IMP)wsdSegImage, method_getTypeEncoding(mi)); } }
	{ Method mv = class_getInstanceMethod([NSToolbarItem class], @selector(setView:)); if (mv && !origItemSetView) origItemSetView = method_setImplementation(mv, (IMP)wsdItemSetView); }
	Method mt = class_getInstanceMethod([NSTableView class], @selector(_initDefaults));
	if (mt && !origTableInit) origTableInit = method_setImplementation(mt, (IMP)wsdTableInit);
	Method mb = class_getInstanceMethod([NSButtonCell class], @selector(drawInteriorWithFrame:inView:));
	{ Class cc = NSClassFromString(@"NSComboBoxCell"); Method mcb = cc ? class_getInstanceMethod(cc, @selector(drawInteriorWithFrame:inView:)) : NULL; if (mcb && !origComboDraw) { origComboDraw = method_getImplementation(mcb); class_replaceMethod(cc, @selector(drawInteriorWithFrame:inView:), (IMP)wsdComboDraw, method_getTypeEncoding(mcb)); } }
	if (NSClassFromString(@"NSDatePickerCell")) { Method mdp = class_getInstanceMethod(NSClassFromString(@"NSDatePickerCell"), @selector(drawInteriorWithFrame:inView:)); if (mdp && !origDatePickerDraw) origDatePickerDraw = method_setImplementation(mdp, (IMP)wsdDatePickerDraw); }
	if (NSClassFromString(@"NSDatePickerCell") && !origDatePickerWith) { Class dc = NSClassFromString(@"NSDatePickerCell"); Method mw = class_getInstanceMethod(dc, @selector(drawWithFrame:inView:)); if (mw) { origDatePickerWith = method_getImplementation(mw); class_replaceMethod(dc, @selector(drawWithFrame:inView:), (IMP)wsdDatePickerWith, method_getTypeEncoding(mw)); } }
	if (NSClassFromString(@"NSVisualEffectView")) {
		Class vc = NSClassFromString(@"NSVisualEffectView");
		Method md = class_getInstanceMethod(vc, @selector(drawRect:)); if (md && !origVEVDraw) { origVEVDraw = method_getImplementation(md); class_replaceMethod(vc, @selector(drawRect:), (IMP)wsdVEVDraw, method_getTypeEncoding(md)); }
		Method mm = class_getInstanceMethod(vc, @selector(viewDidMoveToWindow)); if (mm && !origVEVMove) { origVEVMove = method_getImplementation(mm); class_replaceMethod(vc, @selector(viewDidMoveToWindow), (IMP)wsdVEVMove, method_getTypeEncoding(mm)); }
	}
	{ Method ms = class_getInstanceMethod([GSTheme class], @selector(drawSwitchInRect:forState:enabled:)); if (ms && !origDrawSwitch) origDrawSwitch = method_setImplementation(ms, (IMP)wsdDrawSwitch); }
	{ Method mk = class_getInstanceMethod([NSMenu class], @selector(performKeyEquivalent:)); if (mk && !origMenuKeyEq) origMenuKeyEq = method_setImplementation(mk, (IMP)wsdMenuKeyEquivalent); }
	{ Method mc = class_getInstanceMethod([NSWindow class], @selector(constrainFrameRect:toScreen:)); if (mc && !origConstrain) origConstrain = method_setImplementation(mc, (IMP)wsdConstrain); }
	Method mth = class_getInstanceMethod([NSTableHeaderView class], @selector(initWithFrame:));
	if (mth && !origHeaderInit) origHeaderInit = method_setImplementation(mth, (IMP)wsdHeaderInit);
	Method mat = class_getInstanceMethod([NSButtonCell class], @selector(attributedTitle));
	if (mat && !origAttrTitle) origAttrTitle = method_setImplementation(mat, (IMP)wsdAttrTitle);
	Method mtc = class_getInstanceMethod([NSButtonCell class], @selector(textColor));
	if (mtc && !origButtonTextColor) origButtonTextColor = method_setImplementation(mtc, (IMP)wsdButtonTextColor);
	{ Method mk = class_getInstanceMethod([NSMenuItemCell class], @selector(_keyEquivalentString)); if (mk && !origKeyEqStr) origKeyEqStr = method_setImplementation(mk, (IMP)wsdKeyEqString); }
	WsdInstallFilePanel(); WsdInstallAppearanceWatch(); WsdInstallDragDrop(); WsdInstallMenuBar(); WsdInstallPopover();
	{ Method m1 = class_getInstanceMethod([NSMenuView class], @selector(sizeToFit)); if (m1 && !origMenuSize) origMenuSize = method_setImplementation(m1, (IMP)wsdMenuSizeToFit); }
	{ Method m2 = class_getInstanceMethod([NSMenuItemCell class], @selector(textColor)); if (m2 && !origMenuTextColor) origMenuTextColor = method_setImplementation(m2, (IMP)wsdMenuTextColor); }
	{ Method m3 = class_getInstanceMethod([NSMenuItemCell class], @selector(drawKeyEquivalentWithFrame:inView:)); if (m3 && !origMenuKeyEq) origMenuKeyEq = method_setImplementation(m3, (IMP)wsdMenuDrawKeyEq); }
	{ Method m4 = class_getInstanceMethod([NSMenuItemCell class], @selector(drawStateImageWithFrame:inView:)); if (m4 && !origMenuState) origMenuState = method_setImplementation(m4, (IMP)wsdMenuDrawState); }
	{ Method mf = class_getInstanceMethod([NSWindow class], @selector(makeFirstResponder:)); if (mf && !origMakeFR) origMakeFR = method_setImplementation(mf, (IMP)wsdMakeFirstResponder); }
	{ Method mr = class_getInstanceMethod([NSTextField class], @selector(drawRect:)); if (mr && !origTFRect) origTFRect = method_setImplementation(mr, (IMP)wsdTFRect); }
	Method mtf = class_getInstanceMethod([NSTextFieldCell class], @selector(drawInteriorWithFrame:inView:));
	if (mtf && !origTFDraw) origTFDraw = method_setImplementation(mtf, (IMP)wsdTFDraw);
	Method msg = class_getInstanceMethod([NSSegmentedCell class], @selector(drawSegment:inFrame:withView:));
	if (msg && !origSegDraw) origSegDraw = method_setImplementation(msg, (IMP)wsdSegDraw);
	{ Class sc = [NSSegmentedCell class]; SEL sel = @selector(drawWithFrame:inView:); Method mw = class_getInstanceMethod(sc, sel), up = class_getInstanceMethod(class_getSuperclass(sc), sel);       /* NSSegmentedCell may only inherit the method from NSCell: replacing that one would hit every cell, so the method is added to the subclass then */
		if (mw && !origSegCellDraw) { if (mw == up) { origSegCellDraw = method_getImplementation(mw); class_addMethod(sc, sel, (IMP)wsdSegCellDraw, method_getTypeEncoding(mw)); } else origSegCellDraw = method_setImplementation(mw, (IMP)wsdSegCellDraw); } }
	Method ma = class_getInstanceMethod([NSAlert class], @selector(runModal));
	if (ma && !origAlertRun && !getenv("WSD_NO_MACALERT")) origAlertRun = method_setImplementation(ma, (IMP)wsdAlertRun);
	if (mb && !origButtonInterior) origButtonInterior = method_setImplementation(mb, (IMP)wsdButtonInterior);
	{ Method mp = class_getInstanceMethod([NSPopUpButtonCell class], @selector(drawInteriorWithFrame:inView:)); if (mp && !origPopupInterior) origPopupInterior = method_setImplementation(mp, (IMP)wsdPopupInterior); }
	if (!getenv("WSD_NO_MACALERT")) WsdInstallSheets();                          /* after the alert above: sheets and alerts as the Mac has them replace it */
}

void WsdApplyMacPalette(void)
{
	swizzleTableDefaults();
	@try { applyFonts(); } @catch (NSException *e) { NSLog(@"wsd theme: fonts: %@", e); }
	int r, g, b; windowBG(&r, &g, &b); BOOL dark = isDark(); int fg = dark ? 255 : 0;
	NSColorList *l = [NSColorList colorListNamed: @"System"];
	if (!l) return;
	NSColor *label = rgb(mix(r, fg, 0.85), mix(g, fg, 0.85), mix(b, fg, 0.85), 1);
	NSColor *sec = rgb(mix(r, fg, 0.55), mix(g, fg, 0.55), mix(b, fg, 0.55), 1);
	[l setColor: rgb(r, g, b, 1) forKey: @"windowBackgroundColor"];
	[l setColor: rgb(r, g, b, 1) forKey: @"controlBackgroundColor"];
	[l setColor: rgb(mix(r, fg, dark ? 0.07 : 0.0), mix(g, fg, dark ? 0.07 : 0.0), mix(b, fg, dark ? 0.07 : 0.0), 1) forKey: @"controlColor"];
	[l setColor: label forKey: @"labelColor"];
	[l setColor: label forKey: @"controlTextColor"]; [l setColor: label forKey: @"textColor"]; [l setColor: label forKey: @"windowFrameTextColor"];
	[l setColor: rgb(0, 122, 255, 1) forKey: @"selectedMenuItemColor"];
	[l setColor: dark ? rgb(72, 72, 72, 1) : rgb(210, 210, 212, 1) forKey: @"selectedControlColor"];      /* selected table rows (the unemphasised selection of a window without focus) */
	[l setColor: rgb(255, 255, 255, 1) forKey: @"selectedControlTextColor"]; [l setColor: rgb(255, 255, 255, 1) forKey: @"selectedMenuItemTextColor"];
	[l setColor: dark ? rgb(63, 96, 130, 1) : rgb(176, 215, 255, 1) forKey: @"selectedTextBackgroundColor"]; [l setColor: label forKey: @"selectedTextColor"];
	{ double da = dark ? 0.20 : 0.23; [l setColor: rgb(mix(r, fg, da), mix(g, fg, da), mix(b, fg, da), 1) forKey: @"disabledControlTextColor"]; } [l setColor: sec forKey: @"secondaryLabelColor"];
	{ double ta = dark ? 0.35 : 0.30; [l setColor: rgb(mix(r, fg, ta), mix(g, fg, ta), mix(b, fg, ta), 1) forKey: @"tertiaryLabelColor"]; ta = dark ? 0.20 : 0.16; [l setColor: rgb(mix(r, fg, ta), mix(g, fg, ta), mix(b, fg, ta), 1) forKey: @"quaternaryLabelColor"]; }
	[l setColor: dark ? rgb(23, 24, 25, 1) : rgb(255, 255, 255, 1) forKey: @"textBackgroundColor"];
	/* alternating table / list rows (what controlAlternatingRowBackgroundColors names) */
	[l setColor: dark ? rgb(30, 30, 30, 1) : rgb(255, 255, 255, 1) forKey: @"rowBackgroundColor"];
	[l setColor: dark ? rgb(38, 38, 38, 1) : rgb(244, 245, 245, 1) forKey: @"alternateRowBackgroundColor"];
	/* the appearance applications ask for (NSAppearance.currentAppearance, effectiveAppearance): the dark one when the desktop is dark */
#ifdef WSD_HAVE_APPEARANCE
	if (dark && NSClassFromString(@"NSAppearance")) [NSAppearance setCurrentAppearance: [NSAppearance appearanceNamed: NSAppearanceNameDarkAqua]];
#endif      /* the field fill measured on macOS: neutral, darker than the (wallpaper tinted) window */
}


/* ---- animation of controls: a value that moves towards its target over `dur` seconds, kept per view (and key); every draw advances it and asks for another one while it is moving ---- */
@interface NSView (WsdAnimation)
- (void) wsdAnimationTick;
@end
@implementation NSView (WsdAnimation)
- (void) wsdAnimationTick { [self setNeedsDisplay: YES]; }
@end
static double WsdAnim(NSView *view, int key, double target, double dur, BOOL startAtTarget)
{
	static NSMutableDictionary *st;                                           /* "ptr:key" -> @[value, last time] */
	if (!st) st = [[NSMutableDictionary alloc] init];
	NSString *k = [NSString stringWithFormat: @"%p:%d", view, key]; NSArray *a = [st objectForKey: k]; double now = [[NSDate date] timeIntervalSinceReferenceDate], v, last;
	if (!a || now - [[a objectAtIndex: 1] doubleValue] > 2.5) { v = startAtTarget ? target : (target > 0.5 ? 0.0 : 1.0); last = now; }      /* not drawn for a while: the animation starts again */
	else { v = [[a objectAtIndex: 0] doubleValue]; last = [[a objectAtIndex: 1] doubleValue]; }
	double step = (now - last) / dur; if (v < target) { v += step; if (v > target) v = target; } else if (v > target) { v -= step; if (v < target) v = target; }
	[st setObject: [NSArray arrayWithObjects: [NSNumber numberWithDouble: v], [NSNumber numberWithDouble: now], nil] forKey: k];
	if (v != target) [view performSelector: @selector(wsdAnimationTick) withObject: nil afterDelay: 1.0 / 60 inModes: [NSArray arrayWithObjects: NSDefaultRunLoopMode, NSEventTrackingRunLoopMode, nil]];
	return v;
}
static double EaseOut(double t) { return 1 - (1 - t) * (1 - t) * (1 - t); }

/* the focus ring of a text field: it grows in and fades in over a quarter of a second, in the accent colour (as on the Mac) */
static void WsdFocusRing(NSView *view)
{
	double e = EaseOut(WsdAnim(view, 1, 1.0, 0.25, NO));
	NSBezierPath *p = [NSBezierPath bezierPathWithRoundedRect: NSInsetRect([view bounds], 1.5, 1.5) xRadius: 6 yRadius: 6];
	[p setLineWidth: 1.0 + 2.0 * e]; [[NSColor colorWithCalibratedRed: 0.0 green: 122 / 255.0 blue: 1.0 alpha: 0.15 + 0.4 * e] set]; [p stroke];
}
static NSView *WsdControlOfEditor(id r)
{
	if (![r isKindOfClass: [NSText class]]) return nil;
	id dl = [(NSText *)r delegate]; if ([dl isKindOfClass: [NSCell class]]) dl = [(NSCell *)dl controlView];
	return [dl isKindOfClass: [NSTextField class]] ? dl : nil;
}
static BOOL wsdMakeFirstResponder(id self, SEL _cmd, NSResponder *r)
{
	NSView *oldc = WsdControlOfEditor([(NSWindow *)self firstResponder]);
	BOOL ok = ((BOOL (*)(id, SEL, NSResponder *))origMakeFR)(self, _cmd, r);
	NSView *newc = WsdControlOfEditor([(NSWindow *)self firstResponder]);
	[oldc setNeedsDisplay: YES]; [newc setNeedsDisplay: YES];          /* a text field is drawn again when it gains or loses the editing focus: that is when its ring appears or goes */
	return ok;
}
static NSString *wsdKeyEqString(id self, SEL _cmd)
{
	/* the key equivalent as the Mac shows it: the modifiers as symbols in the order control, option, shift, command (GNUstep prints ^ + / # for them) and the key in capitals */
	NSMenuItem *it = [(NSMenuItemCell *)self menuItem]; NSString *key = [it keyEquivalent]; if (![key length]) return key;
	unichar u = [key characterAtIndex: 0]; NSUInteger m = [it keyEquivalentModifierMask];
	NSString *k;
	if (u >= 0xF700) { switch (u) { case 0xF700: k = @"↑"; break; case 0xF701: k = @"↓"; break; case 0xF702: k = @"←"; break; case 0xF703: k = @"→"; break; case 0xF728: k = @"⌦"; break; case 0xF729: k = @"↖"; break; case 0xF72B: k = @"↘"; break; case 0xF72C: k = @"⇞"; break; case 0xF72D: k = @"⇟"; break;
		default: if (u >= 0xF704 && u <= 0xF70F) k = [NSString stringWithFormat: @"F%d", (int)(u - 0xF704 + 1)]; else return ((NSString *(*)(id, SEL))origKeyEqStr)(self, _cmd); } }
	else if (u == 0x0d || u == 0x03) k = @"↩"; else if (u == 0x1b) k = @"⎋"; else if (u == 0x7f || u == 0x08) k = @"⌫"; else if (u == 0x09) k = @"⇥"; else if (u == 0x20) k = @"Space"; else k = [key uppercaseString];
	BOOL shift = (m & NSShiftKeyMask) || (u >= 'A' && u <= 'Z');
	return [NSString stringWithFormat: @"%@%@%@%@%@", (m & NSControlKeyMask) ? @"⌃" : @"", (m & NSAlternateKeyMask) ? @"⌥" : @"", shift ? @"⇧" : @"", (m & NSCommandKeyMask) ? @"⌘" : @"", k];
}
static void wsdTFRect(id self, SEL _cmd, NSRect r)
{
	((void (*)(id, SEL, NSRect))origTFRect)(self, _cmd, r);
	if (![self isKindOfClass: [NSTextField class]]) return;
	id fr = [[self window] firstResponder];
	if (([fr isKindOfClass: [NSText class]] && ([(NSText *)fr delegate] == self || [(NSText *)fr delegate] == [(NSControl *)self cell])) || fr == self) WsdFocusRing(self);   /* the field editor's delegate is the cell */
}
static void wsdTFDraw(id self, SEL _cmd, NSRect f, NSView *v)
{
	((void (*)(id, SEL, NSRect, NSView *))origTFDraw)(self, _cmd, f, v);
	/* while editing the field editor is the first responder, which is why AppKit draws no ring */
	if ([v isKindOfClass: [NSTextField class]]) { id fr = [[v window] firstResponder]; if (([fr isKindOfClass: [NSText class]] && ([(NSText *)fr delegate] == v || [(NSText *)fr delegate] == [(NSControl *)v cell])) || fr == v) WsdFocusRing(v); }
}


/* ---- menus as measured on the Mac: 16 pt left of the title (30 with a column of check marks), 16 on the right, 31 more for a submenu's arrow, key equivalents 24.5 pt after the title, width rounded up */
static float *wsdMenuIvar(id mv, const char *name) { Ivar iv = class_getInstanceVariable([NSMenuView class], name); return iv ? (float *)((char *)mv + ivar_getOffset(iv)) : NULL; }
static void wsdMenuSizeToFit(id self, SEL _cmd)
{
	if ([(NSMenuView *)self isHorizontal]) {                                                                                  /* the menu bar */
		if ([self menu] == [NSApp mainMenu] && WsdMenuBarPrepare([self menu]) && [self respondsToSelector: @selector(update)]) [(NSMenuView *)self update]; [(NSMenuView *)self setHorizontalEdgePadding: 11];
		((void (*)(id, SEL))origMenuSize)(self, _cmd); if ([self menu] == [NSApp mainMenu]) [(NSView *)self setFrameSize: NSMakeSize([(NSView *)self frame].size.width + 14 + 2, [(NSView *)self frame].size.height)]; return;
	}
	((void (*)(id, SEL))origMenuSize)(self, _cmd);
	Ivar ic = class_getInstanceVariable([NSMenuView class], "_itemCells"); NSArray *cells = ic ? *(NSArray **)((char *)self + ivar_getOffset(ic)) : nil; if (![cells count]) return;
	BOOL hasCheck = NO, hasSub = NO, hasIcon = NO; double maxTitle = 0, maxKey = 0;
	for (NSMenuItemCell *c in cells) {
		NSMenuItem *it = [c menuItem]; if ([it isSeparatorItem] || [it isHidden]) continue;
		if ([it state] != NSOffState) hasCheck = YES; 
		if ([it hasSubmenu]) hasSub = YES; else maxKey = fmax(maxKey, [c keyEquivalentWidth]);
		maxTitle = fmax(maxTitle, [c titleWidth] + ([[it toolTip] hasPrefix: @"sym:"] ? 25 : 0));              /* a row with an icon has its title 25 pt further in */
	}
	double W = maxTitle + 32 + (hasCheck ? 14 : 0) + (hasSub ? 31 : 0);
	if (maxKey > 0) W = fmax(W, 16 + (hasCheck ? 14 : 0) + maxTitle + 24.5 + maxKey + 16);
	W = ceil(W);
	float *so = wsdMenuIvar(self, "_stateImageOffset"), *sw = wsdMenuIvar(self, "_stateImageWidth"), *io = wsdMenuIvar(self, "_imageAndTitleOffset"), *iw = wsdMenuIvar(self, "_imageAndTitleWidth"), *ko = wsdMenuIvar(self, "_keyEqOffset"), *kw = wsdMenuIvar(self, "_keyEqWidth");
	Ivar cs = class_getInstanceVariable([NSMenuView class], "_cellSize"), lb = class_getInstanceVariable([NSMenuView class], "_leftBorderOffset");
	if (!so || !sw || !io || !iw || !ko || !kw || !cs || !lb) return;
	*so = 12; *sw = 14; *io = 16 + (hasCheck ? 14 : 0); *iw = (float)maxTitle; *kw = (float)(maxKey > 0 ? maxKey : 10); *ko = (float)(W - 16 - *kw);
	*(int *)((char *)self + ivar_getOffset(lb)) = 0;                                                                        /* no left border: the cells start at the menu's edge */
	id menu = [(NSMenuView *)self menu]; if ([menu respondsToSelector: @selector(minimumWidth)]) { double mw = ((double (*)(id, SEL))objc_msgSend)(menu, @selector(minimumWidth)); if (mw > W) W = mw; }             /* NSMenu.minimumWidth */
	NSSize *cell = (NSSize *)((char *)self + ivar_getOffset(cs)); cell->width = W;
	[(NSView *)self setFrameSize: NSMakeSize(W, [(NSView *)self frame].size.height)];
}
static NSColor *wsdMenuTextColor(id self, SEL _cmd)
{
	NSMenuView *mv = [(NSMenuItemCell *)self menuView];
	if (mv && [mv isHorizontal]) return WsdBarTextColor([[(NSMenuItemCell *)self menuItem] isEnabled]);
	if (!mv) return ((NSColor *(*)(id, SEL))origMenuTextColor)(self, _cmd);
	if ([(NSMenuItemCell *)self isHighlighted]) return [NSColor whiteColor];
	BOOL en = [[(NSMenuItemCell *)self menuItem] isEnabled];
	return isDark() ? [NSColor colorWithCalibratedWhite: 1 alpha: en ? 0.85 : 0.25] : [NSColor colorWithCalibratedWhite: 0 alpha: en ? 0.85 : 0.25];
}
static void wsdMenuDrawKeyEq(id self, SEL _cmd, NSRect f, NSView *v)
{
	NSMenuItemCell *c = self;
	if (![[c menuItem] hasSubmenu] || [[c menuView] isHorizontal]) { ((void (*)(id, SEL, NSRect, NSView *))origMenuKeyEq)(self, _cmd, f, v); return; }
	double cx = f.origin.x + [(NSView *)[c menuView] frame].size.width - 26, cy = NSMidY(f);                                  /* the arrow: 5 wide, 9 high, 22 from the right edge */
	NSBezierPath *p = [NSBezierPath bezierPath]; [p setLineWidth: 1.6]; [p setLineCapStyle: NSRoundLineCapStyle]; [p setLineJoinStyle: NSRoundLineJoinStyle];
	[p moveToPoint: NSMakePoint(cx, cy + 4.5)]; [p lineToPoint: NSMakePoint(cx + 4.5, cy)]; [p lineToPoint: NSMakePoint(cx, cy - 4.5)];
	[[c isHighlighted] ? [NSColor whiteColor] : (isDark() ? [NSColor colorWithCalibratedWhite: 1 alpha: 0.85] : [NSColor colorWithCalibratedWhite: 0 alpha: 0.85]) setStroke]; [p stroke];
}
static void wsdMenuDrawState(id self, SEL _cmd, NSRect f, NSView *v)
{
	NSMenuItemCell *c = self;
	if ([[c menuView] isHorizontal]) { ((void (*)(id, SEL, NSRect, NSView *))origMenuState)(self, _cmd, f, v); return; }
	if ([[c menuItem] state] == NSOffState) return;
	NSString *g = [[c menuItem] state] == NSMixedState ? @"−" : @"✓"; NSFont *font = [NSFont systemFontOfSize: 13];
	NSSize ts = [g sizeWithAttributes: @{ NSFontAttributeName: font }];
	[g drawAtPoint: NSMakePoint(f.origin.x + 12, NSMidY(f) - ts.height / 2) withAttributes: @{ NSFontAttributeName: font, NSForegroundColorAttributeName: [c textColor] }];
}

@implementation WsdMacTheme

/* GSTheme's defaultsDidChange: swaps back to the stock theme whenever a user default changes and the active theme's name is not "GNUstep" (we change the font defaults): claim that name */
- (NSString *) name { return @"GNUstep"; }


/* the dotted focus rectangle is not part of the macOS look (the focus ring only appears for keyboard navigation) */
- (void) drawFocusFrame: (NSRect)frame view: (NSView *)view
{
	/* the focus ring is drawn inside the view: the real one is 3 pt wide round the control, which a view cannot draw outside of its bounds here */
	if (![view isKindOfClass: [NSTextField class]] && ![view isKindOfClass: [NSTextView class]]) return;
	WsdFocusRing(view);
}

/* a default button on macOS carries no return-arrow image (GNUstep adds one) */
- (void) setKeyEquivalent: (NSString *)key forButtonCell: (NSButtonCell *)cell { }

/* push buttons: a rounded rectangle (radius 5) 24 pt high centred in the cell frame (the frame is 32 pt: the extra space is the focus ring margin), filled white at 8 % over the window, the accent blue (0,122,255) when it is the default button */
- (void) drawButton: (NSRect)frame in: (NSCell *)cell view: (NSView *)view style: (int)style state: (GSThemeControlState)state
{
	BOOL popup = [cell isKindOfClass: [NSPopUpButtonCell class]];
	if (!popup && (style == 5 /* disclosure */ || style == 7 /* circular */ || style == 9 /* help */ || style == 13 /* recessed */ || style == 15 /* inline */)) {      /* styles that keep the stock drawing (the default style 0 is a plain push button) */
		[super drawButton: frame in: cell view: view style: style state: state];
		return;
	}
	BOOL alertBtn = [[view window] isKindOfClass: [NSPanel class]] && [[view window] styleMask] == NSBorderlessWindowMask;                  /* the alert panel's buttons are 28 pt capsules */
	NSRect r = frame; r.size.height = r.size.height > (alertBtn ? 28 : 24) ? (alertBtn ? 28 : 24) : r.size.height; r.origin.y = frame.origin.y + (frame.size.height - r.size.height) / 2.0;
	BOOL isDefault = [cell isKindOfClass: [NSButtonCell class]] && [[(NSButtonCell *)cell keyEquivalent] isEqualToString: @"\r"];
	BOOL enabled = [cell isEnabled], pressed = (state == GSThemeHighlightedState || state == GSThemeHighlightedFirstResponderState || state == GSThemeSelectedState || state == GSThemeSelectedFirstResponderState);
	int wr, wg, wb; windowBG(&wr, &wg, &wb); BOOL dark = isDark(); int fg = dark ? 255 : 0;
	if (alertBtn) { wr = wg = wb = dark ? 31 : 236; }
	NSColor *fill;
	if (isDefault && enabled) fill = pressed ? (dark ? rgb(25, 135, 255, 1) : rgb(0, 110, 230, 1)) : rgb(0, 122, 255, 1);
	else { double a = dark ? (pressed ? 0.17 : 0.08) : (pressed ? 0.165 : 0.075); if (!enabled) a *= 0.5; fill = rgb(mix(wr, fg, a), mix(wg, fg, a), mix(wb, fg, a), 1); }
	[fill set];
	[[NSBezierPath bezierPathWithRoundedRect: r xRadius: alertBtn ? r.size.height / 2.0 : 5.0 yRadius: alertBtn ? r.size.height / 2.0 : 5.0] fill];                        /* measured on the real button: a rounded rectangle, radius 5 pt (not a capsule) */
}
- (id<GSWindowDecorator>) windowDecorator { return (id<GSWindowDecorator>)[WsdMacDecorationView class]; }
- (float) titlebarHeight { return 32.0; }
- (float) resizebarHeight { return 6.0; }                         /* an invisible strip along the bottom edge that still resizes */
@end

/* ---- text fields, sliders, progress bars, steppers, segmented controls, pop-up buttons: measured on the real controls (dark appearance, docs/UI-MAC.md) ---- */
static NSColor *onBG(double a) { int r, g, b; windowBG(&r, &g, &b); int fg = isDark() ? 255 : 0; return rgb(mix(r, fg, a), mix(g, fg, a), mix(b, fg, a), 1); }
static NSColor *accent(void) { return rgb(0, 122, 255, 1); }
static void fillRound(NSRect r, CGFloat radius, NSColor *c) { [c set]; [[NSBezierPath bezierPathWithRoundedRect: r xRadius: radius yRadius: radius] fill]; }

@implementation WsdMacTheme (Controls)

/* text field bezel: 1 px border (the window colour lightened by 5 %) round a field filled with the text background (23,24,25 in the dark appearance), corner radius 6 */
- (NSRect) drawWhiteBezel: (NSRect)frame withClip: (NSRect)clip
{
	if (gInDatePicker) { NSRect fr = frame; if (fr.size.height > 20) { fr.origin.y += (fr.size.height - 20) / 2 - 3; fr.size.height = 20; } fillRound(fr, 6.0, isDark() ? rgb(23, 24, 25, 1) : rgb(255, 255, 255, 1)); return NSInsetRect(fr, 4, 1); }          /* the date picker field: no ring */
	fillRound(frame, 6.0, onBG(0.05));
	fillRound(NSInsetRect(frame, 1, 1), 5.0, isDark() ? rgb(23, 24, 25, 1) : rgb(255, 255, 255, 1));
	return NSInsetRect(frame, 2, 2);                                /* the content rectangle, as the stock method returns it */
}

/* the bezel of scroll views and tables: a 1 px hairline */
- (NSRect) drawGrayBezel: (NSRect)frame withClip: (NSRect)clip
{
	[onBG(0.08) set]; NSFrameRect(frame);
	return NSInsetRect(frame, 1, 1);
}

- (void) drawSliderBorderAndBackground: (NSBorderType)aType frame: (NSRect)cellFrame inCell: (NSCell *)cell isHorizontal: (BOOL)horizontal { }

/* the track: 6 pt thick capsule centred on the bar, the part before the knob in the accent colour */
- (void) drawBarInside: (NSRect)rect inCell: (NSCell *)cell flipped: (BOOL)flipped
{
	NSSliderCell *sc = (NSSliderCell *)cell;
	BOOL horizontal = rect.size.width > rect.size.height;
	if (!horizontal) { [super drawBarInside: rect inCell: cell flipped: flipped]; return; }
	CGFloat cy = NSMidY(rect), th = 6.0; NSRect track = NSMakeRect(rect.origin.x, cy - th / 2, rect.size.width, th);
	BOOL en = [cell isEnabled];
	fillRound(track, th / 2, onBG(0.12));
	double mn = [sc minValue], mx = [sc maxValue], f = mx > mn ? ([sc doubleValue] - mn) / (mx - mn) : 0;
	CGFloat kr = 10.0, x = track.origin.x + kr + f * (track.size.width - 2 * kr);
	NSRect fill = NSMakeRect(track.origin.x, track.origin.y, x - track.origin.x, th);
	fillRound(fill, th / 2, en ? accent() : onBG(0.28));
}

- (void) drawKnobInCell: (NSCell *)cell
{
	NSSliderCell *sc = (NSSliderCell *)cell; NSView *v = [cell controlView];
	NSRect kr = [sc knobRectFlipped: [v isFlipped]];
	double press = EaseOut(WsdAnim(v, 2, [cell isHighlighted] ? 1.0 : 0.0, 0.12, YES));       /* the handle swells a little while it is held */
	double hs = 20 + 2.0 * press; NSRect c = NSMakeRect(NSMidX(kr) - hs / 2, NSMidY(kr) - hs / 2, hs, hs);
	NSColor *knob = rgb(218 + 8 * press, 220 + 8 * press, 222 + 8 * press, 1);
	[rgb(0, 0, 0, 0.25) set]; [[NSBezierPath bezierPathWithOvalInRect: NSOffsetRect(NSInsetRect(c, 1, 1), 0, -1)] fill];
	[([cell isEnabled] ? knob : rgb(150, 152, 154, 1)) set]; [[NSBezierPath bezierPathWithOvalInRect: NSInsetRect(c, 1, 1)] fill];
}

/* determinate progress bars: an 8 pt capsule, the done part in the accent colour on the track colour (46,53,60) */
- (NSRect) drawProgressIndicatorBezel: (NSRect)bounds withClip: (NSRect)rect { return bounds; }
- (void) drawProgressIndicator: (NSProgressIndicator *)progress withBounds: (NSRect)bounds withClip: (NSRect)rect atCount: (int)count forValue: (double)val
{
	if ([progress style] == NSProgressIndicatorSpinningStyle || [progress isIndeterminate] || [progress isVertical]) {
		[super drawProgressIndicator: progress withBounds: bounds withClip: rect atCount: count forValue: val];
		return;
	}
	CGFloat h = bounds.size.height > 8 ? 8 : bounds.size.height; NSRect t = NSMakeRect(bounds.origin.x, NSMidY(bounds) - h / 2, bounds.size.width, h);
	fillRound(t, h / 2, onBG(0.10));
	if (val > 0) { NSRect d = t; d.size.width = t.size.width * (val > 1 ? 1 : val); if (d.size.width < h) d.size.width = h; fillRound(d, h / 2, accent()); }
}

/* steppers: a rounded rect filled white at 8 % with the two chevrons round a hairline (measured: 20 x 24, chevrons 5.3 pt from the middle) */
- (void) drawStepperCell: (NSCell *)cell withFrame: (NSRect)cellFrame inView: (NSView *)controlView highlightUp: (BOOL)hu highlightDown: (BOOL)hd
{
	NSRect r = NSMakeRect(cellFrame.origin.x, cellFrame.origin.y + (cellFrame.size.height - 24) / 2, cellFrame.size.width > 20 ? 20 : cellFrame.size.width, 24);
	BOOL dp = gInDatePicker;                                           /* in a date picker the stepper is just the two chevrons */
	if (!dp) { fillRound(r, 6.0, onBG(hu || hd ? 0.14 : 0.08)); [onBG(0.16) set]; NSRectFill(NSMakeRect(r.origin.x + 2, NSMidY(r) - 0.5, r.size.width - 4, 1)); }
	[dp ? [[NSColor controlTextColor] colorWithAlphaComponent: 0.65] : [NSColor controlTextColor] set];
	CGFloat cx = NSMidX(r);
	for (int k = 0; k < 2; k++) {
		CGFloat cy = k == 0 ? NSMidY(r) + 5.3 : NSMidY(r) - 5.3, d = k == 0 ? -1 : 1;
		NSBezierPath *p = [NSBezierPath bezierPath]; [p setLineWidth: 1.8]; [p setLineCapStyle: NSRoundLineCapStyle]; [p setLineJoinStyle: NSRoundLineJoinStyle];
		[p moveToPoint: NSMakePoint(cx - 4.2, cy + d * 1.6)]; [p lineToPoint: NSMakePoint(cx, cy - d * 1.6)]; [p lineToPoint: NSMakePoint(cx + 4.2, cy + d * 1.6)]; [p stroke];
	}
}

/* segmented controls: a capsule (white 8 %), the selected segment in the accent colour */
- (void) drawSegmentedControlSegment: (NSCell *)cell withFrame: (NSRect)cellFrame inView: (NSView *)controlView style: (NSSegmentStyle)style state: (GSThemeControlState)state roundedLeft: (BOOL)rl roundedRight: (BOOL)rr
{
	BOOL sel = (state == GSThemeSelectedState || state == GSThemeSelectedFirstResponderState);
	NSRect r = cellFrame; if (r.size.height > 24) { r.origin.y += (r.size.height - 24) / 2; r.size.height = 24; }
	NSColor *c = sel ? accent() : onBG(0.08);
	CGFloat rad = 6.0;
	if (sel) { fillRound(NSInsetRect(r, 0, 0), 6.0, c); return; }                       /* the selected segment is a rounded rectangle of its own */
	NSBezierPath *p = [NSBezierPath bezierPathWithRect: r];
	if (rl || rr) {
		NSBezierPath *rounded = [NSBezierPath bezierPathWithRoundedRect: r xRadius: rad yRadius: rad];
		[c set]; [rounded fill];
		if (!rl) { [c set]; NSRectFill(NSMakeRect(r.origin.x, r.origin.y, rad, r.size.height)); }
		if (!rr) { [c set]; NSRectFill(NSMakeRect(NSMaxX(r) - rad, r.origin.y, rad, r.size.height)); }
		return;
	}
	[c set]; [p fill];
}

/* pop-up buttons: the cell draws the title; the stock arrow image is replaced by a blank one and the two chevrons are drawn here at the right */
- (void) drawPopUpButtonCellInteriorWithFrame: (NSRect)cellFrame withCell: (NSCell *)cell inView: (NSView *)controlView
{
	NSColor *tc = [cell isEnabled] ? [NSColor controlTextColor] : [NSColor disabledControlTextColor];
	[tc set]; CGFloat cx = NSMaxX(cellFrame) - 14;
	for (int k = 0; k < 2; k++) {
		CGFloat cy = k == 0 ? NSMidY(cellFrame) + 3.5 : NSMidY(cellFrame) - 3.5, d = k == 0 ? -1 : 1;
		NSBezierPath *p = [NSBezierPath bezierPath]; [p setLineWidth: 1.4]; [p setLineCapStyle: NSRoundLineCapStyle]; [p setLineJoinStyle: NSRoundLineJoinStyle];
		[p moveToPoint: NSMakePoint(cx - 3, cy + d * 1.5)]; [p lineToPoint: NSMakePoint(cx, cy - d * 1.5)]; [p lineToPoint: NSMakePoint(cx + 3, cy + d * 1.5)]; [p stroke];
	}
}


/* tab views: a rounded content box under a capsule of tabs (the selected one lighter), the tabs centred at the top */
- (void) drawTabViewRect: (NSRect)rect inView: (NSView *)view withItems: (NSArray *)items selectedItem: (NSTabViewItem *)selected
{
	NSTabView *tv = (NSTabView *)view; const NSTabViewType type = [tv tabViewType]; NSRect bounds = [view bounds];
	if (type != NSTopTabsBezelBorder) { [super drawTabViewRect: rect inView: view withItems: items selectedItem: selected]; return; }
	NSRect box = [self tabViewBackgroundRectForBounds: bounds tabViewType: type];
	box = NSInsetRect(box, 1, 1);
	fillRound(box, 8.0, onBG(0.12)); fillRound(NSInsetRect(box, 1, 1), 7.0, onBG(0.035));
	const CGFloat th = 24.0, pad = 12.0; const BOOL trunc = [tv allowsTruncatedLabels]; BOOL flipped = [view isFlipped];
	CGFloat total = 0; NSUInteger n = [items count];
	for (NSUInteger i = 0; i < n; i++) total += [[items objectAtIndex: i] sizeOfLabel: trunc].width + 2 * pad;
	CGFloat x = bounds.origin.x + (bounds.size.width - total) / 2, y = flipped ? bounds.origin.y + 4 : NSMaxY(bounds) - 4 - th;
	fillRound(NSMakeRect(x, y, total, th), th / 2, onBG(0.08));
	for (NSUInteger i = 0; i < n; i++) {
		NSTabViewItem *it = [items objectAtIndex: i]; CGFloat w = [it sizeOfLabel: trunc].width + 2 * pad; NSRect r = NSMakeRect(x, y, w, th);
		if ([it tabState] == NSSelectedTab) fillRound(NSInsetRect(r, 2, 2), (th - 4) / 2, onBG(0.20));
		[it drawLabel: trunc inRect: r];
		x += w;
	}
}

/* scroller slots (the disabled scroller) are not drawn */

/* group boxes: a rounded panel (the window colour lightened by 3 %) with the title above it at the left, as on macOS */
- (void) drawBoxInClipRect: (NSRect)clipRect boxType: (NSBoxType)boxType borderType: (NSBorderType)borderType inView: (NSBox *)box
{
	if (boxType == NSBoxSeparator) { [onBG(0.10) set]; NSRectFill([box borderRect]); return; }
	if (boxType == NSBoxCustom || boxType == NSBoxOldStyle) { [super drawBoxInClipRect: clipRect boxType: boxType borderType: borderType inView: box]; return; }
	NSRect b = [box bounds]; CGFloat th = [box titlePosition] == NSNoTitle ? 0 : [box titleRect].size.height - 3.5;          /* measured: the panel starts 3.5 pt below the title top, the title sits at the very top */
	NSRect panel = NSMakeRect(b.origin.x, b.origin.y, b.size.width, b.size.height - th);
	fillRound(panel, 8.0, onBG(0.035));
	if ([box titlePosition] != NSNoTitle) { NSRect tr = [box titleRect]; tr.origin.x = b.origin.x + 8; tr.origin.y = NSMaxY(b) - tr.size.height; [[box titleCell] drawWithFrame: tr inView: box]; }
}


/* menus: a rounded panel (corner radius 10, the window colour lightened by 18 %, 1 px lighter border), accent highlight with radius 6, hairline separators; the menu bar across the top is darker */
- (BOOL) drawsBorderForMenuItemCell: (NSMenuItemCell *)cell state: (GSThemeControlState)state isHorizontal: (BOOL)horizontal { return NO; }
- (CGFloat) menuBorderRadius { return 12.0; }
- (CGFloat) menuBarHeight { return 30.0; }                    /* measured on the Mac: the bar is 30 pt, near black (1,1,15) */
- (CGFloat) menuItemHeight { return 24.0; }                  /* measured on the Mac (NSMenu popped up in a test program): rows are 24 pt, a separator row 11 pt, 5 pt above and below */
- (CGFloat) menuSeparatorHeight { return 11.0; }
- (NSEdgeInsets) menuItemAreaInsets { return (NSEdgeInsets){ 5, 0, 5, 0 }; }
- (NSColor *) menuBackgroundColor { return onBG(0.18); }
- (NSColor *) menuBorderColor { return onBG(0.30); }
- (CGFloat) menuItemBackgroundRadius { return 8.0; }
- (NSColor *) menuSeparatorColor { return [NSColor colorWithCalibratedWhite: 1 alpha: 0.14]; }
- (CGFloat) menuSeparatorInset { return 16.0; }
- (void) drawBackgroundForMenuView: (NSMenuView *)menuView withFrame: (NSRect)bounds dirtyRect: (NSRect)dirtyRect horizontal: (BOOL)horizontal
{
	if (horizontal) { NSWindow *bw = [menuView window]; if (bw) { [bw setOpaque: NO]; [bw setBackgroundColor: [NSColor clearColor]]; } [[NSColor clearColor] set]; NSRectFillUsingOperation(bounds, NSCompositeCopy); return; }
	NSWindow *w = [menuView window];                                  /* a pop-up menu: the compositor draws the material (glass mode 5: the context menu as measured on the Mac) under the transparent window */
	if (w) {
		[w setOpaque: NO]; [w setBackgroundColor: [NSColor clearColor]];
		id srv = GSCurrentServer();
		if ([srv respondsToSelector: @selector(wsdMenuGlass:::)]) [srv wsdMenuGlass: (int)[w windowNumber] : (int)bounds.size.width : (int)bounds.size.height];
	}
	[[NSColor clearColor] set]; NSRectFillUsingOperation(bounds, NSCompositeCopy);
}
- (NSImage *) branchImage { static NSImage *b; if (!b) b = [[NSImage alloc] initWithSize: NSMakeSize(8, 8)]; return b; }
- (NSImage *) highlightedBranchImage { return [self branchImage]; }
/* the highlighted row: the accent blue, 5 pt in from the sides, corner radius 8 */
- (void) drawBorderAndBackgroundForMenuItemCell: (NSMenuItemCell *)cell withFrame: (NSRect)cellFrame inView: (NSView *)controlView state: (GSThemeControlState)state isHorizontal: (BOOL)horizontal
{
	if (horizontal) { WsdDrawBarItem(cell, cellFrame, state == GSThemeHighlightedState || [cell isHighlighted]); return; }
	BOOL hot = state == GSThemeHighlightedState || [cell isHighlighted]; if ([[cell menuItem] isSeparatorItem]) return;
	if (hot && ![[cell menuItem] view]) fillRound(NSInsetRect(cellFrame, 5, 0), 8.0, rgb(0, 122, 255, 1));       /* a row that holds a view (the Finder's tag colours) is not highlighted as a whole */
	if ([[cell menuItem] hasSubmenu]) {       /* the submenu arrow of macOS: a chevron (GNUstep's branch image is a flag-shaped bitmap, blanked below) */
		extern BOOL WsdSymbolDraw(NSString *name, NSRect cell, CGFloat pt, int weight, NSColor *tint); extern int WsdSymbolFlip; BOOL en = [[cell menuItem] isEnabled];
		WsdSymbolFlip = 0; WsdSymbolDraw(@"chevron.right", NSMakeRect(NSMaxX(cellFrame) - 26, NSMidY(cellFrame) - 8, 16, 16), 9, 6, hot ? [NSColor whiteColor] : (isDark() ? [NSColor colorWithCalibratedWhite: 1 alpha: en ? 0.6 : 0.25] : [NSColor colorWithCalibratedWhite: 0 alpha: en ? 0.55 : 0.25])); WsdSymbolFlip = -1;
	}
	NSString *tip = [[cell menuItem] toolTip]; if ([tip hasPrefix: @"sym:"]) {                                       /* the icon of the row: a symbol named in the tool tip, 16 pt, 17 pt in from the edge of the row */
		extern BOOL WsdSymbolDraw(NSString *name, NSRect cell, CGFloat pt, int weight, NSColor *tint); BOOL en = [[cell menuItem] isEnabled];
		extern int WsdSymbolFlip; WsdSymbolFlip = 0;       /* the menu rows are drawn in unflipped coordinates */
		WsdSymbolDraw([tip substringFromIndex: 4], NSMakeRect(cellFrame.origin.x + 16, NSMidY(cellFrame) - 9, 18, 18), 13, 4, hot ? [NSColor whiteColor] : (isDark() ? [NSColor colorWithCalibratedWhite: 1 alpha: en ? 0.85 : 0.25] : [NSColor colorWithCalibratedWhite: 0 alpha: en ? 0.85 : 0.25]));
		WsdSymbolFlip = -1;
	}
}
- (void) drawSeparatorItemForMenuItemCell: (NSMenuItemCell *)cell withFrame: (NSRect)cellFrame inView: (NSView *)controlView isHorizontal: (BOOL)horizontal
{
	if (horizontal) { [super drawSeparatorItemForMenuItemCell: cell withFrame: cellFrame inView: controlView isHorizontal: horizontal]; return; }
	[[NSColor colorWithCalibratedWhite: 1 alpha: 0.14] set];
	NSRectFillUsingOperation(NSMakeRect(cellFrame.origin.x + 16, NSMidY(cellFrame) - 0.5, cellFrame.size.width - 31, 1), NSCompositeSourceOver);
}


/* named colours the stock drawing asks the theme for */
- (NSColor *) colorNamed: (NSString *)aName state: (GSThemeControlState)elementState
{
	if ([aName isEqualToString: @"highlightedTableRowBackgroundColor"]) return isDark() ? rgb(72, 72, 72, 1) : rgb(210, 210, 212, 1);
	if ([aName isEqualToString: @"highlightedTableRowTextColor"]) return [NSColor controlTextColor];
	return [super colorNamed: aName state: elementState];
}


/* colour wells: a capsule round the colour */
- (NSRect) drawColorWellBorder: (NSColorWell *)well withBounds: (NSRect)bounds withClip: (NSRect)clipRect
{
	if (![well isBordered]) return bounds;
	fillRound(bounds, bounds.size.height / 2, onBG(0.10));
	NSRect in = NSInsetRect(bounds, 4, 4);
	[[NSBezierPath bezierPathWithRoundedRect: in xRadius: in.size.height / 2 yRadius: in.size.height / 2] addClip];                  /* the swatch is a capsule too */
	return in;
}

/* table headers: no bezel, a 1 px hairline under the header (the title is drawn by the cell) */
- (void) drawTableHeaderCell: (NSTableHeaderCell *)cell withFrame: (NSRect)cellFrame inView: (NSView *)controlView state: (GSThemeControlState)state
{
	if (isDark()) { int r, g, b; windowBG(&r, &g, &b); [rgb(mix(r, 255, 0.035), mix(g, 255, 0.035), mix(b, 255, 0.035), 1) set]; NSRectFill(cellFrame); }          /* dark: the header strip is a little lighter than the rows; light: none */
	[cell setAlignment: NSLeftTextAlignment]; [cell setFont: [NSFont systemFontOfSize: 13]];
	[onBG(0.08) set]; NSRectFill(NSMakeRect(cellFrame.origin.x, [controlView isFlipped] ? NSMaxY(cellFrame) - 1 : cellFrame.origin.y, cellFrame.size.width, 1));
}

- (void) drawTableCornerView: (NSView *)cornerView withClip: (NSRect)aRect { }

/* scrollers: only the knob, a slim capsule (no arrows, no slot) */
- (float) defaultScrollerWidth { return 15.0; }
- (void) drawScrollerRect: (NSRect)rect inView: (NSView *)view hitPart: (NSScrollerPart)hitPart isHorizontal: (BOOL)isHorizontal
{
	/* legacy ("always") scrollers as measured: an 11 pt wide track (window colour + 5 % foreground) with an 11 pt knob, (158,160,164) dark / (122,122,122) light */
	NSScroller *sc = (NSScroller *)view; NSRect k = [sc rectForPart: NSScrollerKnob];
	NSRect bar = [sc bounds];
	NSRect tr = isHorizontal ? NSInsetRect(bar, 2, (bar.size.height - 11) / 2) : NSInsetRect(bar, (bar.size.width - 11) / 2, 2);
	if (NSIntersectsRect(rect, tr)) fillRound(tr, 5.5, onBG(isDark() ? 0.05 : 0.047));
	if (NSIsEmptyRect(k) || !NSIntersectsRect(rect, k)) return;
	NSRect c = isHorizontal ? NSInsetRect(k, 1, (k.size.height - 11) / 2) : NSInsetRect(k, (k.size.width - 11) / 2, 1);
	fillRound(c, 5.5, isDark() ? rgb(158, 160, 164, 1) : rgb(122, 122, 122, 1));
}
@end

@interface NSScroller (WsdSlot)
@end
@implementation NSScroller (WsdSlot)
- (void) drawKnobSlotInRect: (NSRect)slotRect highlight: (BOOL)flag { }          /* macOS draws no scroller track */
@end

/* search fields: a capsule round the whole field with the magnifier and the clear button inside it */
@interface NSSearchFieldCell (WsdMac)
@end
@implementation NSSearchFieldCell (WsdMac)
- (NSRect) searchButtonRectForBounds: (NSRect)r { return NSMakeRect(r.origin.x + 8, NSMidY(r) - 7, 14, 14); }
- (NSRect) cancelButtonRectForBounds: (NSRect)r { return NSMakeRect(NSMaxX(r) - 8 - 14, NSMidY(r) - 7, 14, 14); }
- (NSRect) searchTextRectForBounds: (NSRect)r { return NSMakeRect(r.origin.x + 19, r.origin.y, r.size.width - 45, r.size.height); }
- (void) drawWithFrame: (NSRect)f inView: (NSView *)v
{
	fillRound(f, f.size.height / 2, onBG(0.05));
	fillRound(NSInsetRect(f, 1, 1), (f.size.height - 2) / 2, isDark() ? rgb(23, 24, 25, 1) : rgb(255, 255, 255, 1));
	NSRect sb = [self searchButtonRectForBounds: f]; NSColor *tc = [[NSColor controlTextColor] colorWithAlphaComponent: 0.6];
	[tc set];
	[NSGraphicsContext saveGraphicsState];
	if ([v isFlipped]) { NSAffineTransform *ft = [NSAffineTransform transform]; [ft translateXBy: 0 yBy: 2 * NSMidY(sb)]; [ft scaleXBy: 1 yBy: -1]; [ft concat]; }          /* the drawing below assumes y up */
	NSBezierPath *ring = [NSBezierPath bezierPathWithOvalInRect: NSMakeRect(sb.origin.x + 1.5, sb.origin.y + 3.5, 8, 8)]; [ring setLineWidth: 1.4]; [ring stroke];
	NSBezierPath *h = [NSBezierPath bezierPath]; [h setLineWidth: 1.6]; [h setLineCapStyle: NSRoundLineCapStyle]; [h moveToPoint: NSMakePoint(sb.origin.x + 9.4, sb.origin.y + 4.6)]; [h lineToPoint: NSMakePoint(sb.origin.x + 12.6, sb.origin.y + 1.4)]; [h stroke];
	[NSGraphicsContext restoreGraphicsState];
	[self drawInteriorWithFrame: [self searchTextRectForBounds: f] inView: v];
	if ([[self stringValue] length] > 0) {
		NSRect cb = [self cancelButtonRectForBounds: f];
		fillRound(NSInsetRect(cb, 0.5, 0.5), 6.5, rgb(160, 160, 163, 1));
		[rgb(40, 40, 42, 1) set]; NSBezierPath *x = [NSBezierPath bezierPath]; [x setLineWidth: 1.4]; [x setLineCapStyle: NSRoundLineCapStyle];
		[x moveToPoint: NSMakePoint(NSMidX(cb) - 2.5, NSMidY(cb) - 2.5)]; [x lineToPoint: NSMakePoint(NSMidX(cb) + 2.5, NSMidY(cb) + 2.5)]; [x moveToPoint: NSMakePoint(NSMidX(cb) - 2.5, NSMidY(cb) + 2.5)]; [x lineToPoint: NSMakePoint(NSMidX(cb) + 2.5, NSMidY(cb) - 2.5)]; [x stroke];
	}
}
@end

/* level indicators: separate rounded segments, green when filled (Apple's capacity style) */
@interface NSLevelIndicatorCell (WsdMac)
@end
@implementation NSLevelIndicatorCell (WsdMac)
- (void) drawInteriorWithFrame: (NSRect)f inView: (NSView *)v
{
	double mn = [self minValue], mx = [self maxValue], val = [self doubleValue];
	int n = (int)(mx - mn + 0.5); if (n < 1) n = 1; if (n > 50) n = 50;
	int filled = (int)((val - mn) / (mx - mn > 0 ? mx - mn : 1) * n + 0.5);
	/* measured: 10 separate rounded cells (radius 3.5, 1 pt apart), each with a 1 px darker rim, 16 pt high */
	CGFloat w = f.size.width / n, h = f.size.height > 16 ? 16 : f.size.height, y = NSMidY(f) - h / 2 + ([v isFlipped] ? -2 : 2);   /* measured: the cells sit at the top of the 18 pt frame, GNUstep's origin is a point lower */ BOOL dark = isDark();
	NSColor *fillOn = dark ? rgb(48, 209, 88, 1) : rgb(52, 199, 89, 1), *edgeOn = dark ? rgb(42, 182, 77, 1) : rgb(45, 173, 78, 1), *fillOff = onBG(0.07), *edgeOff = onBG(0.19);
	for (int i = 0; i < n; i++) {
		NSRect r = NSMakeRect(f.origin.x + i * w, y, w - 1, h); BOOL on = i < filled;
		fillRound(r, 3.5, on ? edgeOn : edgeOff);
		fillRound(NSInsetRect(r, 1, 1), 2.5, on ? fillOn : fillOff);
	}
}
@end

#define TB 32.0
CGFloat WsdTabBarHeight(NSWindow *w);                                                   /* WsdTabbing.m */
void WsdDrawTabBar(NSWindow *w, NSRect bar, BOOL dark, BOOL key);
BOOL WsdTabBarMouseDown(NSWindow *w, NSRect bar, NSPoint p, NSEvent *e);

@interface GSStandardWindowDecorationView (WsdPrivate)
- (NSPoint) mouseLocationOnScreenOutsideOfEventStream;
@end

@interface NSWindow (WsdPrivate)
- (void) _captureMouse: (id)sender;
- (void) _releaseMouse: (id)sender;
@end

/* San Francisco is not redistributable: the closest free face is Inter (pkg inter-font), else the system bold */
static NSFont *titleFont(void)
{
	static NSFont *f; static BOOL done;
	if (!done) {
		done = YES;
		NSString *names[] = { @"Inter SemiBold", @"Inter-SemiBold", @"Inter Semi Bold", @"Inter Bold", @"Inter-Bold" };
		for (int i = 0; i < 5 && !f; i++) f = [NSFont fontWithName: names[i] size: 13.0];
		if (!f) f = [NSFont boldSystemFontOfSize: 13.0];
		[f retain];
	}
	return f;
}

@interface NSObject (WsdCursorShape)
- (void) wsdSetCursorShape: (int)shape;
@end

/* A cursor the window server draws itself: the diagonal and edge resize shapes GNUstep has no standard cursor for */
@interface WsdShapeCursor : NSCursor { int shape; }
+ (WsdShapeCursor *) cursorWithShape: (int)s;
@end
@implementation WsdShapeCursor
+ (WsdShapeCursor *) cursorWithShape: (int)s
{
	static NSMutableDictionary *cache;
	if (!cache) cache = [NSMutableDictionary new];
	WsdShapeCursor *c = [cache objectForKey: [NSNumber numberWithInt: s]];
	if (!c) {
		NSImage *img = [[[NSImage alloc] initWithSize: NSMakeSize(1, 1)] autorelease];
		c = [[WsdShapeCursor alloc] initWithImage: img hotSpot: NSZeroPoint];
		c->shape = s; [cache setObject: c forKey: [NSNumber numberWithInt: s]];
	}
	return c;
}
- (void) mouseEntered: (NSEvent *)e { if (getenv("WSD_DEBUG")) NSLog(@"wsd-back: cursor entered shape %d key %d", shape, (int)[[NSApp keyWindow] isKeyWindow]); [super mouseEntered: e]; }
- (void) set { [super set]; id srv = GSCurrentServer(); if ([srv respondsToSelector: @selector(wsdSetCursorShape:)]) [srv wsdSetCursorShape: shape]; }
@end

extern NSImage *WsdWindowButtonImage(int kind, int state, BOOL dark);
extern void WsdDrawWindowButton(NSImage *im, NSRect r, BOOL held, NSPoint pull);
static NSMutableSet *gDecoViews; static double wsdRelF;
@interface WsdMacDecorationView (WsdOverlay) - (void) wsdDrawTrafficLights; - (NSRect) wsdGroupRect; - (BOOL) wsdPointInButtons: (NSPoint)p; @end
@class WsdMacDecorationView;
/* the title bar's buttons of a window whose content runs under it (full-size content view, the Finder): a transparent view over the content that draws them and takes the presses on them */
@interface WsdTrafficOverlay : NSView { @public WsdMacDecorationView *deco; } @end
@implementation WsdMacDecorationView

+ (void) offsets: (float *)l : (float *)r : (float *)t : (float *)b forStyleMask: (NSUInteger)style
{
	*l = *r = *t = *b = 0.0;
	if ((style & (NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask)) && !(style & NSFullSizeContentViewWindowMask)) *t = TB;       /* full-size content: the content runs under the title bar (the Finder's toolbar) */
}

+ (CGFloat) minFrameWidthWithTitle: (NSString *)aTitle styleMask: (NSUInteger)aStyle { return 96.0; }

- (id) initWithFrame: (NSRect)frame window: (NSWindow *)w
{
	installControlImages();
	WsdInstallCGBridge();                                        /* [NSGraphicsContext graphicsPort] for programs that draw with CoreGraphics */
	self = [super initWithFrame: frame window: w];
	if (self == nil) return nil;
	/* the circles are drawn here: no NSButton subviews. The buttons stay alive: GSStandardWindowDecorationView keeps using the ivars
	 * (setDocumentEdited: messages closeButton), and removing a subview releases it, which left a dangling pointer and crashed on the first edit */
	[closeButton retain]; [closeButton removeFromSuperview];
	[miniaturizeButton retain]; [miniaturizeButton removeFromSuperview];
	[self updateRects];
	if (!gDecoViews) { gDecoViews = [[NSMutableSet alloc] init]; [NSTimer scheduledTimerWithTimeInterval: 0.05 target: [WsdMacDecorationView class] selector: @selector(wsdPollHover:) userInfo: nil repeats: YES]; }
	[gDecoViews addObject: [NSValue valueWithNonretainedObject: self]]; wsdBtnPressed = -1;
	if ([w styleMask] & NSFullSizeContentViewWindowMask) { WsdTrafficOverlay *ov = [[WsdTrafficOverlay alloc] initWithFrame: [self bounds]]; ov->deco = self; [ov setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable]; [self addSubview: ov positioned: NSWindowAbove relativeTo: nil]; [ov release]; }
	return self;
}
- (void) dealloc { [gDecoViews removeObject: [NSValue valueWithNonretainedObject: self]]; [super dealloc]; }
- (void) didAddSubview: (NSView *)v
{
	[super didAddSubview: v]; Class oc = NSClassFromString(@"WsdTrafficOverlay"); if ([v isKindOfClass: oc]) return;
	for (NSView *o in [[self subviews] copy]) if ([o isKindOfClass: oc]) { [o retain]; [o removeFromSuperview]; [self addSubview: o]; [o release]; break; }       /* the content view is set after the frame view is made: the overlay stays on top */
}
/* the overlay of a full-size window draws the buttons: whatever redraws the frame view redraws it */
- (void) setNeedsDisplay: (BOOL)f { [super setNeedsDisplay: f]; for (NSView *v in [self subviews]) if ([v isKindOfClass: NSClassFromString(@"WsdTrafficOverlay")]) [v setNeedsDisplay: f]; }
- (void) setNeedsDisplayInRect: (NSRect)r { [super setNeedsDisplayInRect: r]; for (NSView *v in [self subviews]) if ([v isKindOfClass: NSClassFromString(@"WsdTrafficOverlay")]) [v setNeedsDisplayInRect: r]; }

- (void) updateRects
{
	NSRect b = [self bounds];
	if (hasTitleBar) titleBarRect = NSMakeRect(0, b.size.height - TB, b.size.width, TB);
	resizeBarRect = NSZeroRect;                                  /* every edge resizes: handled in mouseDown: below */
	closeButtonRect = miniaturizeButtonRect = NSZeroRect;
}

/* the content view gives room to the tab bar (the window's frame does not change: the content gets shorter, as on macOS) */
- (void) wsdApplyTabInset
{
	NSView *cv = [window contentView]; if (!cv) return;
	NSRect b = [self bounds]; CGFloat th = WsdTabBarHeight(window), top = hasTitleBar ? TB : 0;
	NSRect f = NSMakeRect(0, 0, b.size.width, b.size.height - top - th);
	if (!NSEqualRects(f, [cv frame])) [cv setFrame: f];
}
- (void) resizeSubviewsWithOldSize: (NSSize)old { [super resizeSubviewsWithOldSize: old]; if (WsdTabBarHeight(window) > 0) [self wsdApplyTabInset]; }

- (NSRect) circleRect: (int)i
{
	NSRect b = [self bounds];
	if ([window styleMask] & NSFullSizeContentViewWindowMask) return NSMakeRect(18.0 + 23.0 * i, b.size.height - 18.0 - 16.0, 16.0, 16.0);       /* the buttons of a window with a toolbar (measured on the Mac with AX: x 18, 41, 64, 18 from the top) */
	return NSMakeRect(8.0 + 23.0 * i, b.size.height - TB + 8.0, 16.0, 16.0);      /* measured on the Mac (AX): 16 x 16 at x 8, 31, 54, 8 from the top */
}

- (NSRect) wsdGroupRect { NSRect a = [self circleRect: 0], z = [self circleRect: 2]; return NSInsetRect(NSUnionRect(a, z), -4.0, -4.0); }
- (void) wsdSetHover: (BOOL)h { if (h == wsdBtnHover) return; wsdBtnHover = h; [self setNeedsDisplayInRect: [self wsdGroupRect]]; }
/* the glyphs of the three buttons show while the pointer is over the group (the window server sends no mouse-moved events to a window that does not ask for them: the pointer is looked at 20 times a second) */
+ (void) wsdPollHover: (NSTimer *)t
{
	NSPoint sp = [NSEvent mouseLocation];
	for (NSValue *v in [gDecoViews allObjects]) { WsdMacDecorationView *d = [v nonretainedObjectValue]; NSWindow *w = [d window]; if (!w || ![w isVisible]) { [d wsdSetHover: NO]; continue; }
		NSPoint lp = [d convertPoint: [w convertScreenToBase: sp] fromView: nil]; [d wsdSetHover: NSPointInRect(lp, [d wsdGroupRect]) && NSPointInRect(lp, [d bounds])];
		static NSWindow *dwellWin; static NSTimeInterval dwellT0; NSRect zr = NSInsetRect([d circleRect: 2], -3, -3);
		if (NSPointInRect(lp, zr) && [w isKeyWindow] && ([w styleMask] & NSResizableWindowMask)) { if (dwellWin != w) { dwellWin = w; dwellT0 = [NSDate timeIntervalSinceReferenceDate]; } else if (dwellT0 > 0 && [NSDate timeIntervalSinceReferenceDate] - dwellT0 > 0.7) { dwellT0 = 0; WsdShowTilePopover(w, [d convertRect: zr toView: nil]); } }
		else if (dwellWin == w) dwellWin = nil; }
}
static NSGradient *grad(int r0, int g0, int b0, int r1, int g1, int b1, int r2, int g2, int b2)
{
	NSColor *c[3] = { rgb(r0, g0, b0, 1), rgb(r1, g1, b1, 1), rgb(r2, g2, b2, 1) };
	CGFloat loc[3] = { 0.0, 0.45, 1.0 };
	return [[[NSGradient alloc] initWithColors: [NSArray arrayWithObjects: c[0], c[1], c[2], nil]
		atLocations: loc colorSpace: [NSColorSpace genericRGBColorSpace]] autorelease];
}

/* a button as the Mac's catalogue has it (Aqua.car): colour disc with no glyph at rest, the glyph while the pointer is over the group, darker while pressed; a window that is not key shows grey discs until the pointer comes over them; a button the window lacks stays grey */
- (void) drawButton: (int)i key: (BOOL)key enabled: (BOOL)en dark: (BOOL)dark
{
	BOOL pressed = wsdBtnPressed == i;                                       /* held: the disc swells to 1.14 times (on the Mac its coloured part grows from 14 to 16 px while the button is down, wherever the pointer is: measured from a capture of a press and drag) */
	if (en && (key || wsdBtnHover || pressed)) {
		int kind = (i == 0 && [window isDocumentEdited]) ? 3 : i, state = pressed ? 2 : (wsdBtnHover ? 1 : 0);
		NSImage *im = WsdWindowButtonImage(kind, state, dark);
		if (im) { NSRect r = [self circleRect: i]; BOOL rel = wsdRelBtn == i && wsdRelTimer; WsdDrawWindowButton(im, r, pressed || rel, pressed ? wsdPull : rel ? NSMakePoint(wsdRelPull.x * wsdRelF, wsdRelPull.y * wsdRelF) : NSZeroPoint); return; }
	}
	[self drawCircle: i key: key && en dark: dark];
}

- (void) drawCircle: (int)i key: (BOOL)key dark: (BOOL)dark
{
	NSRect r = [self circleRect: i];
	NSBezierPath *p = [NSBezierPath bezierPathWithOvalInRect: NSInsetRect(r, 0.5, 0.5)];
	NSGradient *g;
	/* the vertical gradient (top is drawn first: GNUstep's gradient angle 270 runs top to bottom) */
	if (!key) g = dark ? grad(76, 76, 76, 71, 71, 71, 67, 67, 67) : grad(223, 223, 223, 214, 214, 214, 205, 205, 205);
	else if (i == 0) g = grad(247, 94, 85, 244, 83, 70, 239, 104, 97);
	else if (i == 1) g = grad(251, 180, 1, 253, 193, 1, 254, 207, 48);
	else g = grad(51, 194, 1, 0, 188, 0, 78, 194, 58);
	[g drawInBezierPath: p angle: 270.0];
	/* the rim measured on the real buttons: darker at the sides, bright caps on the top and bottom edges */
	[rgb(0, 0, 0, key ? 0.10 : 0.06) set]; [p setLineWidth: 1.0]; [p stroke];
	NSPoint c = NSMakePoint(NSMidX(r), NSMidY(r));
	[(key ? rgb(255, 255, 255, 0.55) : rgb(255, 255, 255, dark ? 0.35 : 0.25)) set];
	NSBezierPath *cap = [NSBezierPath bezierPath]; [cap setLineWidth: 1.0];
	[cap appendBezierPathWithArcWithCenter: c radius: 6.5 startAngle: 55 endAngle: 125]; [cap stroke];
	cap = [NSBezierPath bezierPath]; [cap setLineWidth: 1.0];
	[cap appendBezierPathWithArcWithCenter: c radius: 6.5 startAngle: 235 endAngle: 305]; [cap stroke];
}

- (void) drawRect: (NSRect)rect
{
	NSRect b = [self bounds];
	BOOL dark = isDark(), key = (inputState == 0);
	{ NSWindow *wn = [self window]; NSColor *wbg = (wn && ![wn isOpaque]) ? [wn backgroundColor] : [NSColor windowBackgroundColor]; if ([wn isOpaque] || !wn) { NSColor *tinted = WsdTintedWindowBackground(wn); if (tinted) wbg = tinted; }          /* non-opaque windows (behind-window materials) keep their own, usually clear, background */
	  [wbg set]; NSRectFillUsingOperation(b, ([wn isOpaque] || !wn) ? NSCompositeSourceOver : NSCompositeCopy); }               /* the window background (the backing store starts transparent) */
	if (hasTitleBar && !([window styleMask] & NSFullSizeContentViewWindowMask)) {
		int wr, wg, wb; windowBG(&wr, &wg, &wb);
		NSColor *bg = dark ? (key ? rgb(mix(wr, 255, 0.035), mix(wg, 255, 0.035), mix(wb, 255, 0.035), 1) : rgb(wr + 4, wg + 4, wb + 4, 1)) : (key ? rgb(mix(wr, 255, 0.5), mix(wg, 255, 0.5), mix(wb, 255, 0.5), 1) : rgb(246, 246, 246, 1));
		[bg set];
		NSRectFill(titleBarRect);
		if (isTitled && [window title]) {
			NSMutableParagraphStyle *ps = [[[NSMutableParagraphStyle alloc] init] autorelease];
			[ps setLineBreakMode: NSLineBreakByTruncatingTail];
			NSColor *tc = dark ? (key ? rgb(160, 160, 160, 1) : rgb(110, 110, 110, 1)) : (key ? rgb(0, 0, 0, 0.78) : rgb(0, 0, 0, 0.40));
			NSDictionary *at = [NSDictionary dictionaryWithObjectsAndKeys:
				titleFont(), NSFontAttributeName, tc, NSForegroundColorAttributeName, ps, NSParagraphStyleAttributeName, nil];
			CGFloat x = 82.0;
			NSString *rep = [window representedFilename]; BOOL dirIcon = NO;
			if ([rep length] && [[NSFileManager defaultManager] fileExistsAtPath: rep isDirectory: &dirIcon]) {       /* the proxy icon of the document or folder the window stands for, before the title */
				Class fs = NSClassFromString(@"WsdFinderSupport"); NSRect ir = NSMakeRect(x, b.size.height - TB + 8.0, 16, 16);
				if ([fs respondsToSelector: @selector(drawIconOfName:directory:inRect:)]) { { [NSGraphicsContext saveGraphicsState]; NSAffineTransform *fl = [NSAffineTransform transform]; [fl translateXBy: 0 yBy: NSMidY(ir) * 2]; [fl scaleXBy: 1 yBy: -1]; [fl concat]; [fs drawIconOfName: dirIcon ? rep : [rep lastPathComponent] directory: dirIcon inRect: ir]; [NSGraphicsContext restoreGraphicsState]; } x += 20.0; }       /* the icon recipes are written for flipped views: mirrored here (the title bar is not flipped) */
			}
			[[window title] drawInRect: NSMakeRect(x, b.size.height - TB + 8.0, b.size.width - x - 16.0, 16.0) withAttributes: at];
		}
		{ CGFloat th = WsdTabBarHeight(window); if (th > 0) { NSRect bar = NSMakeRect(0, b.size.height - TB - th, b.size.width, th); [bg set]; NSRectFill(bar); WsdDrawTabBar(window, bar, dark, key); } }       /* the tab bar of a tabbed window */
		if (isTitled) {                                                                  /* a button the window lacks is drawn disabled (grey), as on macOS */
			[self wsdDrawButtonsKey: key dark: dark];                    /* the held button goes first: the others are drawn over it, as on the Mac (the stretched yellow runs under the green) */
		}
	}
}

/* bit 1 left, 2 right, 4 bottom, 8 top: the 5 px edge zones, 12 px at the corners */
- (int) edgesAtPoint: (NSPoint)p
{
	NSRect b = [self bounds]; int m = 0; const CGFloat e = 5.0, c = 12.0;
	if (p.x < e) m |= 1; if (p.x > b.size.width - e) m |= 2; if (p.y < e) m |= 4; if (p.y > b.size.height - e) m |= 8;
	if (!m) {
		BOOL nl = p.x < c, nr = p.x > b.size.width - c, nb = p.y < c, nt = p.y > b.size.height - c;
		if ((nl || nr) && (nb || nt)) { /* inside a corner square but off the edge strips: no resize */ }
	} else if (m == 1 || m == 2) { if (p.y < c) m |= 4; else if (p.y > b.size.height - c) m |= 8; }
	else if (m == 4 || m == 8) { if (p.x < c) m |= 1; else if (p.x > b.size.width - c) m |= 2; }
	return m;
}

/* the edge strips lie over the content view: claim them before the subviews see the click */
- (NSView *) hitTest: (NSPoint)aPoint
{
	if (hasResizeBar) {
		NSPoint p = [self convertPoint: aPoint fromView: [self superview]];
		if (NSPointInRect(p, [self bounds]) && [self edgesAtPoint: p]) return self;
	}
	return [super hitTest: aPoint];
}

- (void) resizeWindowWithEdges: (int)m event: (NSEvent *)event
{
	NSRect frame = [window frame]; NSSize mn = [window minSize], mx = [window maxSize];
	NSPoint start = [window convertBaseToScreen: [event locationInWindow]];     /* where the press happened, not where the pointer is by now */
	NSEvent *e = event;
	[window _captureMouse: nil];
	while ([e type] != NSLeftMouseUp) {
		e = [[self window] nextEventMatchingMask: NSLeftMouseDraggedMask | NSLeftMouseUpMask untilDate: [NSDate distantFuture] inMode: NSEventTrackingRunLoopMode dequeue: YES];
		NSPoint now = [self mouseLocationOnScreenOutsideOfEventStream];
		CGFloat dx = now.x - start.x, dy = now.y - start.y;
		NSRect nf = frame;
		if (m & 2) nf.size.width = frame.size.width + dx;
		if (m & 1) { nf.size.width = frame.size.width - dx; nf.origin.x = frame.origin.x + dx; }
		if (m & 8) nf.size.height = frame.size.height + dy;
		if (m & 4) { nf.size.height = frame.size.height - dy; nf.origin.y = frame.origin.y + dy; }
		if (nf.size.width < mn.width) { if (m & 1) nf.origin.x = NSMaxX(frame) - mn.width; nf.size.width = mn.width; }
		if (nf.size.height < mn.height) { if (m & 4) nf.origin.y = NSMaxY(frame) - mn.height; nf.size.height = mn.height; }
		if (mx.width > 0 && nf.size.width > mx.width) { if (m & 1) nf.origin.x = NSMaxX(frame) - mx.width; nf.size.width = mx.width; }
		if (mx.height > 0 && nf.size.height > mx.height) { if (m & 4) nf.origin.y = NSMaxY(frame) - mx.height; nf.size.height = mx.height; }
		if (!NSEqualRects(nf, [window frame])) [window setFrame: nf display: YES];
	}
	[window _releaseMouse: nil];
}

/* the resize cursors over the edge strips (the same zones as edgesAtPoint:) */
- (void) resetCursorRects
{
	[super resetCursorRects];
	if (getenv("WSD_DEBUG")) NSLog(@"wsd-back: decoration resetCursorRects resize %d key %d", (int)hasResizeBar, (int)[window isKeyWindow]);
	if (!hasResizeBar) return;
	NSRect b = [self bounds]; const CGFloat e = 5.0, c = 12.0;
	NSCursor *lr = [WsdShapeCursor cursorWithShape: 4], *ud = [WsdShapeCursor cursorWithShape: 5], *nwse = [WsdShapeCursor cursorWithShape: 6], *nesw = [WsdShapeCursor cursorWithShape: 7];
	CGFloat W = b.size.width, H = b.size.height, x0 = b.origin.x, y0 = b.origin.y;
	[self addCursorRect: NSMakeRect(x0 + c, y0, W - 2 * c, e) cursor: ud];
	[self addCursorRect: NSMakeRect(x0 + c, y0 + H - e, W - 2 * c, e) cursor: ud];
	[self addCursorRect: NSMakeRect(x0, y0 + c, e, H - 2 * c) cursor: lr];
	[self addCursorRect: NSMakeRect(x0 + W - e, y0 + c, e, H - 2 * c) cursor: lr];
	/* corners: the 12 px along each edge (bottom left / top right are NE-SW in unflipped coordinates) */
	[self addCursorRect: NSMakeRect(x0, y0, c, e) cursor: nesw]; [self addCursorRect: NSMakeRect(x0, y0, e, c) cursor: nesw];
	[self addCursorRect: NSMakeRect(x0 + W - c, y0 + H - e, c, e) cursor: nesw]; [self addCursorRect: NSMakeRect(x0 + W - e, y0 + H - c, e, c) cursor: nesw];
	[self addCursorRect: NSMakeRect(x0 + W - c, y0, c, e) cursor: nwse]; [self addCursorRect: NSMakeRect(x0 + W - e, y0, e, c) cursor: nwse];
	[self addCursorRect: NSMakeRect(x0, y0 + H - e, c, e) cursor: nwse]; [self addCursorRect: NSMakeRect(x0, y0 + H - c, e, c) cursor: nwse];
}

- (BOOL) wsdButtonEnabled: (int)i { return (i == 0 && hasCloseButton) || (i == 1 && hasMiniaturizeButton) || (i == 2 && isTitled && hasResizeBar); }
- (int) wsdButtonAt: (NSPoint)p { for (int i = 0; i < 3; i++) if ([self wsdButtonEnabled: i] && NSPointInRect(p, NSInsetRect([self circleRect: i], -2, -2))) return i; return -1; }
- (void) mouseDown: (NSEvent *)event
{
	NSPoint p = [self convertPoint: [event locationInWindow] fromView: nil];
	if (hasTitleBar && (NSPointInRect(p, titleBarRect) || ([window styleMask] & NSFullSizeContentViewWindowMask))) {
		int i = [self wsdButtonAt: p];
		if (i >= 0) { wsdBtnPressed = i; wsdBtnInside = YES; wsdBtnHover = YES; [self setNeedsDisplayInRect: [self wsdGroupRect]]; return; }      /* the action runs when the button is released over it (mouseDragged: / mouseUp:) */
	}
	{ CGFloat th = WsdTabBarHeight(window); if (th > 0 && WsdTabBarMouseDown(window, NSMakeRect(0, [self bounds].size.height - TB - th, [self bounds].size.width, th), p, event)) return; }
	if (hasResizeBar) { int m = [self edgesAtPoint: p]; if (m) { [self resizeWindowWithEdges: m event: event]; return; } }
	[super mouseDown: event];
}
- (void) wsdRelease: (NSTimer *)t { wsdRelT += 1.0 / 60; wsdRelF = exp(-wsdRelT * 11.0) * cos(wsdRelT * 26.0); if (wsdRelT > 0.4) { [wsdRelTimer invalidate]; wsdRelTimer = nil; wsdRelBtn = -1; wsdRelF = 0; } [self setNeedsDisplay: YES]; }
- (void) mouseDragged: (NSEvent *)event
{
	if (wsdBtnPressed < 0) { [super mouseDragged: event]; return; }
	NSPoint p = [self convertPoint: [event locationInWindow] fromView: nil]; NSRect cr = [self circleRect: wsdBtnPressed]; BOOL in = NSPointInRect(p, NSInsetRect(cr, -2, -2));
	wsdPull = NSMakePoint(p.x - NSMidX(cr), p.y - NSMidY(cr)); [self setNeedsDisplay: YES];
	if (in != wsdBtnInside) wsdBtnInside = in;          /* it lets go of the disc when the pointer leaves it and takes it again when it comes back */
}
- (void) mouseUp: (NSEvent *)event
{
	if (wsdBtnPressed < 0) { [super mouseUp: event]; return; }
	int i = wsdBtnPressed; BOOL fire = wsdBtnInside; wsdBtnPressed = -1; wsdBtnInside = NO;
	if (hypot(wsdPull.x, wsdPull.y) > 3) { wsdRelBtn = i; wsdRelPull = wsdPull; wsdRelT = 0; wsdRelF = 1; [wsdRelTimer invalidate]; wsdRelTimer = [NSTimer scheduledTimerWithTimeInterval: 1.0 / 60 target: self selector: @selector(wsdRelease:) userInfo: nil repeats: YES]; }       /* the rubber springs back */
	wsdPull = NSZeroPoint; [self setNeedsDisplay: YES];
	if (fire) { if (i == 0) [window performClose: self]; else if (i == 1) [window performMiniaturize: self]; else WsdToggleFullscreen(window); }
}
@end

@implementation WsdMacDecorationView (WsdOverlay)
- (void) wsdDrawTrafficLights
{
	BOOL dark = isDark(), key = (inputState == 0);
	[self wsdDrawButtonsKey: key dark: dark];
}
- (void) wsdDrawButtonsKey: (BOOL)key dark: (BOOL)dark
{
	int first = wsdBtnPressed >= 0 && wsdBtnPressed < 3 ? (int)wsdBtnPressed : (wsdRelTimer && wsdRelBtn >= 0 && wsdRelBtn < 3 ? (int)wsdRelBtn : -1); BOOL en[3] = { hasCloseButton, hasMiniaturizeButton, hasResizeBar };
	if (first >= 0) [self drawButton: first key: key enabled: en[first] dark: dark];
	for (int i = 0; i < 3; i++) if (i != first) [self drawButton: i key: key enabled: en[i] dark: dark];
}
- (BOOL) wsdPointInButtons: (NSPoint)p { return NSPointInRect(p, [self wsdGroupRect]); }
@end
@implementation WsdTrafficOverlay
- (BOOL) isFlipped { return NO; } - (BOOL) isOpaque { return NO; } - (BOOL) acceptsFirstMouse: (NSEvent *)e { return YES; }
- (NSView *) hitTest: (NSPoint)p { NSPoint q = [self convertPoint: p fromView: [self superview]]; return [deco wsdPointInButtons: q] ? self : nil; }
- (void) drawRect: (NSRect)r { [deco wsdDrawTrafficLights]; }
- (void) mouseDown: (NSEvent *)e { [deco mouseDown: e]; }
- (void) mouseDragged: (NSEvent *)e { [deco mouseDragged: e]; }
- (void) mouseUp: (NSEvent *)e { [deco mouseUp: e]; }
@end

