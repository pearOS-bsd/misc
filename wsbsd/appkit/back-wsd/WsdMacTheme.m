#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#include <stdlib.h>
#include <string.h>
#import "wsd/WsdMacTheme.h"

/* WSD_APPEARANCE=light switches the palette; the measurements are of the dark appearance (the light one is typical macOS, not measured) */
static BOOL isDark(void) { const char *e = getenv("WSD_APPEARANCE"); return !(e && !strcmp(e, "light")); }

static NSColor *rgb(int r, int g, int b, CGFloat a) { return [NSColor colorWithCalibratedRed: r / 255.0 green: g / 255.0 blue: b / 255.0 alpha: a]; }

/* the system colours: derived from the window background (WSD_WINDOW_BG=r,g,b overrides the neutral default; on macOS the dark window colour is tinted by the wallpaper, (27,36,43) on the machine the measurements come from) */
static void windowBG(int *r, int *g, int *b)
{
	*r = *g = *b = isDark() ? 30 : 236;
	const char *e = getenv("WSD_WINDOW_BG");
	if (e) { int x, y, z; if (sscanf(e, "%d,%d,%d", &x, &y, &z) == 3) { *r = x; *g = y; *b = z; } }
}
static int mix(int base, int top, double a) { return (int)(base * (1 - a) + top * a + 0.5); }

/* San Francisco is not redistributable: Inter (pkg inter-font) is the closest free face; the GNUstep font defaults are pointed at it when it is installed */
static void applyFonts(void)
{
	NSString *reg[] = { @"Inter-Regular", @"Inter", @"Inter Regular" }, *bold[] = { @"Inter-Bold", @"Inter Bold", @"Inter-SemiBold", @"Inter SemiBold" };
	NSString *r = nil, *b = nil;
	NSArray *avail = [[NSFontManager sharedFontManager] availableFonts];
	for (int i = 0; i < 3 && !r; i++) if ([avail containsObject: reg[i]]) r = reg[i];
	for (int i = 0; i < 4 && !b; i++) if ([avail containsObject: bold[i]]) b = bold[i];
	if (getenv("WSD_DEBUG")) {
		NSMutableArray *inter = [NSMutableArray array];
		for (NSString *n in [[NSFontManager sharedFontManager] availableFonts]) if ([n rangeOfString: @"Inter" options: NSCaseInsensitiveSearch].location != NSNotFound) [inter addObject: n];
		NSLog(@"wsd fonts: regular=%@ bold=%@ available=%lu inter=%@ first=%@", r, b, (unsigned long)[[[NSFontManager sharedFontManager] availableFonts] count], inter, [[[NSFontManager sharedFontManager] availableFonts] subarrayWithRange: NSMakeRange(0, MIN(6, [[[NSFontManager sharedFontManager] availableFonts] count]))]);
	}
	NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
	if (r) for (NSString *k in @[@"NSFont", @"NSUserFont", @"NSControlContentFont", @"NSLabelFont", @"NSMessageFont", @"NSMenuFont", @"NSPaletteFont", @"NSToolTipsFont"]) [d setObject: r forKey: k];
	if (b) for (NSString *k in @[@"NSBoldFont", @"NSTitleBarFont"]) [d setObject: b forKey: k];
}

/* radio buttons and check boxes: GNUstep draws them from the named images NSRadioButton / NSHighlightedRadioButton and NSSwitch / NSHighlightedSwitch; the images drawn here are the macOS ones
 * (16 pt controls, filled white at 10 % over the window when off, the accent blue with a white dot / check when on), with the 6 pt gap to the title built into the image */
static NSImage *controlImage(BOOL radio, BOOL on)
{
	int wr, wg, wb; windowBG(&wr, &wg, &wb); BOOL dark = isDark(); int fg = dark ? 255 : 0;
	NSImage *img = [[NSImage alloc] initWithSize: NSMakeSize(22, 16)];
	[img lockFocus];
	NSRect r = NSMakeRect(0, 0, 16, 16);
	NSBezierPath *shape = radio ? [NSBezierPath bezierPathWithOvalInRect: r] : [NSBezierPath bezierPathWithRoundedRect: r xRadius: 4 yRadius: 4];
	if (on) [rgb(0, 122, 255, 1) set]; else [rgb(mix(wr, fg, dark ? 0.10 : 0.06), mix(wg, fg, dark ? 0.10 : 0.06), mix(wb, fg, dark ? 0.10 : 0.06), 1) set];
	[shape fill];
	if (on) {
		[rgb(255, 255, 255, 1) set];
		if (radio) [[NSBezierPath bezierPathWithOvalInRect: NSMakeRect(5, 5, 6, 6)] fill];
		else { NSBezierPath *c = [NSBezierPath bezierPath]; [c setLineWidth: 1.8]; [c moveToPoint: NSMakePoint(4, 8.2)]; [c lineToPoint: NSMakePoint(6.9, 5)]; [c lineToPoint: NSMakePoint(12, 11.2)]; [c stroke]; }
	}
	[img unlockFocus];
	return img;
}

void WsdApplyMacPalette(void)
{
	applyFonts();
	{
		BOOL a = [controlImage(YES, NO) setName: @"NSRadioButton"], b = [controlImage(YES, YES) setName: @"NSHighlightedRadioButton"];
		BOOL c = [controlImage(NO, NO) setName: @"NSSwitch"], d = [controlImage(NO, YES) setName: @"NSHighlightedSwitch"];
		if (getenv("WSD_DEBUG")) NSLog(@"wsd control images named: %d %d %d %d", a, b, c, d);
	}
	int r, g, b; windowBG(&r, &g, &b); BOOL dark = isDark(); int fg = dark ? 255 : 0;
	NSColorList *l = [NSColorList colorListNamed: @"System"];
	if (!l) return;
	NSColor *label = rgb(mix(r, fg, 0.85), mix(g, fg, 0.85), mix(b, fg, 0.85), 1);
	NSColor *sec = rgb(mix(r, fg, 0.55), mix(g, fg, 0.55), mix(b, fg, 0.55), 1);
	[l setColor: rgb(r, g, b, 1) forKey: @"windowBackgroundColor"];
	[l setColor: rgb(r, g, b, 1) forKey: @"controlBackgroundColor"];
	[l setColor: rgb(mix(r, fg, dark ? 0.07 : 0.0), mix(g, fg, dark ? 0.07 : 0.0), mix(b, fg, dark ? 0.07 : 0.0), 1) forKey: @"controlColor"];
	[l setColor: label forKey: @"controlTextColor"]; [l setColor: label forKey: @"textColor"]; [l setColor: label forKey: @"windowFrameTextColor"];
	[l setColor: sec forKey: @"disabledControlTextColor"]; [l setColor: sec forKey: @"secondaryLabelColor"];
	[l setColor: rgb(mix(r, fg, dark ? 0.04 : 0.0), mix(g, fg, dark ? 0.04 : 0.0), mix(b, fg, dark ? 0.04 : 0.0), 1) forKey: @"textBackgroundColor"];
}

@implementation WsdMacTheme

/* GSTheme's defaultsDidChange: swaps back to the stock theme whenever a user default changes and the active theme's name is not "GNUstep" (we change the font defaults): claim that name */
- (NSString *) name { return @"GNUstep"; }

/* the dotted focus rectangle is not part of the macOS look (the focus ring only appears for keyboard navigation) */
- (void) drawFocusFrame: (NSRect)frame view: (NSView *)view { }

/* a default button on macOS carries no return-arrow image (GNUstep adds one) */
- (void) setKeyEquivalent: (NSString *)key forButtonCell: (NSButtonCell *)cell { }

/* push buttons: a capsule 24 pt high centred in the cell frame (the frame is 32 pt: the extra space is the focus ring margin), filled white at 8 % over the window, the accent blue (0,122,255) when it is the default button */
- (void) drawButton: (NSRect)frame in: (NSCell *)cell view: (NSView *)view style: (int)style state: (GSThemeControlState)state
{
	if (style != NSRoundedBezelStyle && style != NSRegularSquareBezelStyle && style != NSRoundRectBezelStyle && style != NSTexturedRoundedBezelStyle) {
		[super drawButton: frame in: cell view: view style: style state: state];
		return;
	}
	NSRect r = frame; r.size.height = r.size.height > 24 ? 24 : r.size.height; r.origin.y = frame.origin.y + (frame.size.height - r.size.height) / 2.0;
	BOOL isDefault = [cell isKindOfClass: [NSButtonCell class]] && [[(NSButtonCell *)cell keyEquivalent] isEqualToString: @"\r"];
	BOOL enabled = [cell isEnabled], pressed = (state == GSThemeHighlightedState || state == GSThemeHighlightedFirstResponderState);
	int wr, wg, wb; windowBG(&wr, &wg, &wb); BOOL dark = isDark(); int fg = dark ? 255 : 0;
	NSColor *fill;
	if (isDefault && enabled) fill = pressed ? rgb(0, 100, 220, 1) : rgb(0, 122, 255, 1);
	else { double a = dark ? (pressed ? 0.16 : 0.08) : (pressed ? 0.12 : 0.05); if (!enabled) a *= 0.5; fill = rgb(mix(wr, fg, a), mix(wg, fg, a), mix(wb, fg, a), 1); }
	[fill set];
	[[NSBezierPath bezierPathWithRoundedRect: r xRadius: r.size.height / 2.0 yRadius: r.size.height / 2.0] fill];
}
- (id<GSWindowDecorator>) windowDecorator { return (id<GSWindowDecorator>)[WsdMacDecorationView class]; }
- (float) titlebarHeight { return 32.0; }
- (float) resizebarHeight { return 6.0; }                         /* an invisible strip along the bottom edge that still resizes */
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
