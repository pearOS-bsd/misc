#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#include <stdlib.h>
#include <string.h>
#import "wsd/WsdMacTheme.h"

/* WSD_APPEARANCE=light switches the palette; the measurements are of the dark appearance (the light one is typical macOS, not measured) */
static BOOL isDark(void) { const char *e = getenv("WSD_APPEARANCE"); return !(e && !strcmp(e, "light")); }

static NSColor *rgb(int r, int g, int b, CGFloat a) { return [NSColor colorWithCalibratedRed: r / 255.0 green: g / 255.0 blue: b / 255.0 alpha: a]; }

@implementation WsdMacTheme
- (id<GSWindowDecorator>) windowDecorator { return (id<GSWindowDecorator>)[WsdMacDecorationView class]; }
- (float) titlebarHeight { return 32.0; }
- (float) resizebarHeight { return 6.0; }                         /* an invisible strip along the bottom edge that still resizes */
@end

#define TB 32.0

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
	if (hasResizeBar) resizeBarRect = NSMakeRect(0, 0, b.size.width, 6.0);
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
	if (hasTitleBar) {
		NSColor *bg = dark ? (key ? rgb(35, 35, 36, 1) : rgb(34, 34, 34, 1)) : (key ? rgb(236, 236, 238, 1) : rgb(246, 246, 246, 1));
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
		if (hasCloseButton) [self drawCircle: 0 key: key dark: dark];
		if (hasMiniaturizeButton) [self drawCircle: 1 key: key dark: dark];
		if (isTitled && hasResizeBar) [self drawCircle: 2 key: key dark: dark];      /* the zoom button */
	}
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
	[super mouseDown: event];
}
@end
