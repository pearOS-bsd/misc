#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#import "wsd/WsdMacTheme.h"

/* WSD_APPEARANCE=light switches the palette; the measurements are of the dark appearance (the light one is typical macOS, not measured) */
static BOOL isDark(void) { const char *e = getenv("WSD_APPEARANCE"); return !(e && !strcmp(e, "light")); }

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
	NSString *reg[] = { @"Inter-Medium", @"Inter-Regular", @"Inter" }, *bold[] = { @"Inter-Bold", @"Inter Bold", @"Inter-SemiBold", @"Inter SemiBold" };
	NSString *r = nil, *b = nil;
	NSArray *avail = [[NSFontManager sharedFontManager] availableFonts];
	for (int i = 0; i < 3 && !r; i++) if ([avail containsObject: reg[i]]) r = reg[i];      /* macOS draws the system font with a heavier rendering: Inter Medium is the closest weight */
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

/* made when the first window exists (the images are drawn with lockFocus, which needs a working display server) */
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
		for (NSString *nm in @[@"common_Nibble", @"common_3DArrowDown"]) {              /* the stock pop-up arrows are blanked: the theme draws the chevrons */
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

void WsdApplyMacPalette(void)
{
	@try { applyFonts(); } @catch (NSException *e) { NSLog(@"wsd theme: fonts: %@", e); }
	int r, g, b; windowBG(&r, &g, &b); BOOL dark = isDark(); int fg = dark ? 255 : 0;
	NSColorList *l = [NSColorList colorListNamed: @"System"];
	if (!l) return;
	NSColor *label = rgb(mix(r, fg, 0.85), mix(g, fg, 0.85), mix(b, fg, 0.85), 1);
	NSColor *sec = rgb(mix(r, fg, 0.55), mix(g, fg, 0.55), mix(b, fg, 0.55), 1);
	[l setColor: rgb(r, g, b, 1) forKey: @"windowBackgroundColor"];
	[l setColor: rgb(r, g, b, 1) forKey: @"controlBackgroundColor"];
	[l setColor: rgb(mix(r, fg, dark ? 0.07 : 0.0), mix(g, fg, dark ? 0.07 : 0.0), mix(b, fg, dark ? 0.07 : 0.0), 1) forKey: @"controlColor"];
	[l setColor: label forKey: @"controlTextColor"]; [l setColor: label forKey: @"textColor"]; [l setColor: label forKey: @"windowFrameTextColor"];
	[l setColor: rgb(255, 255, 255, 1) forKey: @"selectedControlTextColor"]; [l setColor: rgb(255, 255, 255, 1) forKey: @"selectedMenuItemTextColor"];
	[l setColor: dark ? rgb(63, 96, 130, 1) : rgb(176, 215, 255, 1) forKey: @"selectedTextBackgroundColor"]; [l setColor: label forKey: @"selectedTextColor"];
	[l setColor: sec forKey: @"disabledControlTextColor"]; [l setColor: sec forKey: @"secondaryLabelColor"];
	[l setColor: dark ? rgb(23, 24, 25, 1) : rgb(255, 255, 255, 1) forKey: @"textBackgroundColor"];      /* the field fill measured on macOS: neutral, darker than the (wallpaper tinted) window */
}

@implementation WsdMacTheme

/* GSTheme's defaultsDidChange: swaps back to the stock theme whenever a user default changes and the active theme's name is not "GNUstep" (we change the font defaults): claim that name */
- (NSString *) name { return @"GNUstep"; }

/* the dotted focus rectangle is not part of the macOS look (the focus ring only appears for keyboard navigation) */
- (void) drawFocusFrame: (NSRect)frame view: (NSView *)view
{
	/* the focus ring is drawn inside the view: the real one is 3 pt wide round the control, which a view cannot draw outside of its bounds here */
	if (![view isKindOfClass: [NSTextField class]] && ![view isKindOfClass: [NSTextView class]]) return;
	NSBezierPath *p = [NSBezierPath bezierPathWithRoundedRect: NSInsetRect([view bounds], 1.5, 1.5) xRadius: 6 yRadius: 6];
	[p setLineWidth: 3.0]; [rgb(28, 98, 155, 1) set]; [p stroke];
}

/* a default button on macOS carries no return-arrow image (GNUstep adds one) */
- (void) setKeyEquivalent: (NSString *)key forButtonCell: (NSButtonCell *)cell { }

/* push buttons: a capsule 24 pt high centred in the cell frame (the frame is 32 pt: the extra space is the focus ring margin), filled white at 8 % over the window, the accent blue (0,122,255) when it is the default button */
- (void) drawButton: (NSRect)frame in: (NSCell *)cell view: (NSView *)view style: (int)style state: (GSThemeControlState)state
{
	BOOL popup = [cell isKindOfClass: [NSPopUpButtonCell class]];
	if (!popup && style != NSRoundedBezelStyle && style != NSRegularSquareBezelStyle && style != NSRoundRectBezelStyle && style != NSTexturedRoundedBezelStyle) {
		[super drawButton: frame in: cell view: view style: style state: state];
		return;
	}
	NSRect r = frame; r.size.height = r.size.height > 24 ? 24 : r.size.height; r.origin.y = frame.origin.y + (frame.size.height - r.size.height) / 2.0;
	BOOL isDefault = [cell isKindOfClass: [NSButtonCell class]] && [[(NSButtonCell *)cell keyEquivalent] isEqualToString: @"\r"];
	BOOL enabled = [cell isEnabled], pressed = (state == GSThemeHighlightedState || state == GSThemeHighlightedFirstResponderState);
	int wr, wg, wb; windowBG(&wr, &wg, &wb); BOOL dark = isDark(); int fg = dark ? 255 : 0;
	NSColor *fill;
	if (isDefault && enabled) fill = pressed ? rgb(30, 138, 255, 1) : rgb(0, 122, 255, 1);
	else { double a = dark ? (pressed ? 0.21 : 0.08) : (pressed ? 0.12 : 0.05); if (!enabled) a *= 0.5; fill = rgb(mix(wr, fg, a), mix(wg, fg, a), mix(wb, fg, a), 1); }
	[fill set];
	[[NSBezierPath bezierPathWithRoundedRect: r xRadius: r.size.height / 2.0 yRadius: r.size.height / 2.0] fill];
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
	NSRect kr = [sc knobRectFlipped: [v isFlipped]]; NSRect c = NSMakeRect(NSMidX(kr) - 10, NSMidY(kr) - 10, 20, 20);
	NSColor *knob = rgb(218, 220, 222, 1);
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
	fillRound(r, 6.0, onBG(hu || hd ? 0.14 : 0.08));
	[onBG(0.16) set]; NSRectFill(NSMakeRect(r.origin.x + 2, NSMidY(r) - 0.5, r.size.width - 4, 1));
	[[NSColor controlTextColor] set];
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
	NSRect b = [box bounds]; CGFloat th = [box titlePosition] == NSNoTitle ? 0 : [box titleRect].size.height + 2;
	NSRect panel = NSMakeRect(b.origin.x, b.origin.y, b.size.width, b.size.height - th);
	fillRound(panel, 8.0, onBG(0.035));
	if ([box titlePosition] != NSNoTitle) { NSRect tr = [box titleRect]; tr.origin.x = b.origin.x + 8; tr.origin.y = NSMaxY(b) - th; [[box titleCell] drawWithFrame: tr inView: box]; }
}

/* table headers: no bezel, a 1 px hairline under the header (the title is drawn by the cell) */
- (void) drawTableHeaderCell: (NSTableHeaderCell *)cell withFrame: (NSRect)cellFrame inView: (NSView *)controlView state: (GSThemeControlState)state
{
	[cell setAlignment: NSLeftTextAlignment]; [cell setFont: [NSFont systemFontOfSize: 13]];
	[onBG(0.08) set]; NSRectFill(NSMakeRect(cellFrame.origin.x, [controlView isFlipped] ? NSMaxY(cellFrame) - 1 : cellFrame.origin.y, cellFrame.size.width, 1));
}

- (void) drawTableCornerView: (NSView *)cornerView withClip: (NSRect)aRect { }

/* scrollers: only the knob, a slim capsule (no arrows, no slot) */
- (float) defaultScrollerWidth { return 15.0; }
- (void) drawScrollerRect: (NSRect)rect inView: (NSView *)view hitPart: (NSScrollerPart)hitPart isHorizontal: (BOOL)isHorizontal
{
	NSScroller *sc = (NSScroller *)view; NSRect k = [sc rectForPart: NSScrollerKnob];
	if (NSIsEmptyRect(k) || !NSIntersectsRect(rect, k)) return;
	NSRect c = isHorizontal ? NSInsetRect(k, 1, (k.size.height - 7) / 2) : NSInsetRect(k, (k.size.width - 7) / 2, 1);
	fillRound(c, 3.5, rgb(mix(0, 255, 0.45), mix(0, 255, 0.46), mix(0, 255, 0.48), 1));
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
- (NSRect) searchTextRectForBounds: (NSRect)r { return NSMakeRect(r.origin.x + 26, r.origin.y, r.size.width - 52, r.size.height); }
- (void) drawWithFrame: (NSRect)f inView: (NSView *)v
{
	fillRound(f, f.size.height / 2, onBG(0.05));
	fillRound(NSInsetRect(f, 1, 1), (f.size.height - 2) / 2, isDark() ? rgb(23, 24, 25, 1) : rgb(255, 255, 255, 1));
	NSRect sb = [self searchButtonRectForBounds: f]; NSColor *tc = [[NSColor controlTextColor] colorWithAlphaComponent: 0.6];
	[tc set];
	NSBezierPath *ring = [NSBezierPath bezierPathWithOvalInRect: NSMakeRect(sb.origin.x + 1.5, sb.origin.y + 3.5, 8, 8)]; [ring setLineWidth: 1.4]; [ring stroke];
	NSBezierPath *h = [NSBezierPath bezierPath]; [h setLineWidth: 1.6]; [h setLineCapStyle: NSRoundLineCapStyle]; [h moveToPoint: NSMakePoint(sb.origin.x + 9.4, sb.origin.y + 4.6)]; [h lineToPoint: NSMakePoint(sb.origin.x + 12.6, sb.origin.y + 1.4)]; [h stroke];
	[self drawInteriorWithFrame: [self searchTextRectForBounds: f] inView: v];
	if ([[self stringValue] length] > 0) {
		NSRect cb = [self cancelButtonRectForBounds: f];
		fillRound(NSInsetRect(cb, 0.5, 0.5), 6.5, rgb(160, 160, 163, 1));
		[rgb(40, 40, 42, 1) set]; NSBezierPath *x = [NSBezierPath bezierPath]; [x setLineWidth: 1.4]; [x setLineCapStyle: NSRoundLineCapStyle];
		[x moveToPoint: NSMakePoint(NSMidX(cb) - 2.5, NSMidY(cb) - 2.5)]; [x lineToPoint: NSMakePoint(NSMidX(cb) + 2.5, NSMidY(cb) + 2.5)]; [x moveToPoint: NSMakePoint(NSMidX(cb) - 2.5, NSMidY(cb) + 2.5)]; [x lineToPoint: NSMakePoint(NSMidX(cb) + 2.5, NSMidY(cb) - 2.5)]; [x stroke];
	}
}
@end

#define TB 32.0

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

@implementation WsdMacDecorationView

+ (void) offsets: (float *)l : (float *)r : (float *)t : (float *)b forStyleMask: (NSUInteger)style
{
	*l = *r = *t = *b = 0.0;
	if (style & (NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask)) *t = TB;
}

+ (CGFloat) minFrameWidthWithTitle: (NSString *)aTitle styleMask: (NSUInteger)aStyle { return 96.0; }

- (id) initWithFrame: (NSRect)frame window: (NSWindow *)w
{
	installControlImages();
	self = [super initWithFrame: frame window: w];
	if (self == nil) return nil;
	[closeButton removeFromSuperview];                           /* the circles are drawn here: no NSButton subviews */
	[miniaturizeButton removeFromSuperview];
	[self updateRects];
	return self;
}

- (void) updateRects
{
	NSRect b = [self bounds];
	if (hasTitleBar) titleBarRect = NSMakeRect(0, b.size.height - TB, b.size.width, TB);
	resizeBarRect = NSZeroRect;                                  /* every edge resizes: handled in mouseDown: below */
	closeButtonRect = miniaturizeButtonRect = NSZeroRect;
}

- (NSRect) circleRect: (int)i
{
	NSRect b = [self bounds];
	return NSMakeRect(9.0 + 23.0 * i, b.size.height - TB + 9.0, 14.0, 14.0);
}

static NSGradient *grad(int r0, int g0, int b0, int r1, int g1, int b1, int r2, int g2, int b2)
{
	NSColor *c[3] = { rgb(r0, g0, b0, 1), rgb(r1, g1, b1, 1), rgb(r2, g2, b2, 1) };
	CGFloat loc[3] = { 0.0, 0.45, 1.0 };
	return [[[NSGradient alloc] initWithColors: [NSArray arrayWithObjects: c[0], c[1], c[2], nil]
		atLocations: loc colorSpace: [NSColorSpace genericRGBColorSpace]] autorelease];
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
	[[NSColor windowBackgroundColor] set]; NSRectFill(b);                               /* the window background (the backing store starts transparent) */
	if (hasTitleBar) {
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
			[[window title] drawInRect: NSMakeRect(x, b.size.height - TB + 8.0, b.size.width - x - 16.0, 16.0) withAttributes: at];
		}
		if (isTitled) {                                                                  /* a button the window lacks is drawn disabled (grey), as on macOS */
			[self drawCircle: 0 key: key && hasCloseButton dark: dark];
			[self drawCircle: 1 key: key && hasMiniaturizeButton dark: dark];
			[self drawCircle: 2 key: key && hasResizeBar dark: dark];                    /* the zoom button */
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
	NSPoint start = [self mouseLocationOnScreenOutsideOfEventStream];
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

- (void) mouseDown: (NSEvent *)event
{
	NSPoint p = [self convertPoint: [event locationInWindow] fromView: nil];
	if (hasTitleBar && NSPointInRect(p, titleBarRect)) {
		for (int i = 0; i < 3; i++) {
			if (!((i == 0 && hasCloseButton) || (i == 1 && hasMiniaturizeButton) || (i == 2 && isTitled && hasResizeBar))) continue;
			NSRect r = [self circleRect: i];
			if (!NSPointInRect(p, NSInsetRect(r, -2, -2))) continue;
			/* track: the action runs when the button is released over it */
			NSEvent *e = event;
			while ([e type] != NSLeftMouseUp)
				e = [[self window] nextEventMatchingMask: NSLeftMouseDraggedMask | NSLeftMouseUpMask untilDate: [NSDate distantFuture] inMode: NSEventTrackingRunLoopMode dequeue: YES];
			NSPoint q = [self convertPoint: [e locationInWindow] fromView: nil];
			if (NSPointInRect(q, NSInsetRect(r, -2, -2))) {
				if (i == 0) [window performClose: self]; else if (i == 1) [window performMiniaturize: self]; else [window performZoom: self];
			}
			return;
		}
	}
	if (hasResizeBar) { int m = [self edgesAtPoint: p]; if (m) { [self resizeWindowWithEdges: m event: event]; return; } }
	[super mouseDown: event];
}
@end
