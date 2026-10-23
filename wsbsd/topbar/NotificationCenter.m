/* The panel of the clock (Notification Center): measured on the Mac, 344 wide with its right edge 14 pt from the screen's, cards of dark glass with corners of 20 pt, 13 pt apart, the first one
 * 13 pt under the menu bar; the title of a card 13 pt bold, its text 13 pt dimmed. There is no notification service here yet: the panel shows "No Notifications" and the calendar of the month. */
#import <AppKit/AppKit.h>
#include <time.h>

#define NW 344.0
@interface NCView : NSView @end
@implementation NCView
- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstMouse:(NSEvent *)e { return YES; }
static void Card(NSRect r) { NSBezierPath *p = [NSBezierPath bezierPathWithRoundedRect: r xRadius: 20 yRadius: 20]; [[NSColor colorWithCalibratedRed: 0.11 green: 0.11 blue: 0.12 alpha: 0.9] setFill]; [p fill]; NSBezierPath *rim = [NSBezierPath bezierPathWithRoundedRect: NSInsetRect(r, 0.5, 0.5) xRadius: 20 yRadius: 20]; [[NSColor colorWithCalibratedWhite: 1 alpha: 0.14] setStroke]; [rim stroke]; }
- (void)drawRect:(NSRect)dirty
{
	NSColor *white = [NSColor colorWithCalibratedWhite: 1 alpha: 0.95], *dim = [NSColor colorWithCalibratedWhite: 1 alpha: 0.5]; NSDictionary *bold = @{ NSFontAttributeName: [NSFont boldSystemFontOfSize: 13], NSForegroundColorAttributeName: white }, *norm = @{ NSFontAttributeName: [NSFont systemFontOfSize: 13], NSForegroundColorAttributeName: white }, *small = @{ NSFontAttributeName: [NSFont systemFontOfSize: 11], NSForegroundColorAttributeName: dim };
	NSRect n = NSMakeRect(0, 13, NW, 74); Card(n); NSString *none = @"No Notifications"; NSSize ns = [none sizeWithAttributes: bold]; [none drawAtPoint: NSMakePoint(NSMidX(n) - ns.width / 2, NSMidY(n) - ns.height / 2) withAttributes: @{ NSFontAttributeName: [NSFont boldSystemFontOfSize: 13], NSForegroundColorAttributeName: dim }];
	NSRect cal = NSMakeRect(0, 100, NW, 250); Card(cal);
	time_t now = time(NULL); struct tm t; localtime_r(&now, &t); char head[48]; strftime(head, sizeof head, "%B %Y", &t); [[NSString stringWithUTF8String: head] drawAtPoint: NSMakePoint(18, 114) withAttributes: @{ NSFontAttributeName: [NSFont boldSystemFontOfSize: 15], NSForegroundColorAttributeName: white }];
	NSArray *days = @[ @"M", @"T", @"W", @"T", @"F", @"S", @"S" ]; double cw = (NW - 36) / 7; for (int i = 0; i < 7; i++) { NSSize z = [days[i] sizeWithAttributes: small]; [days[i] drawAtPoint: NSMakePoint(18 + i * cw + cw / 2 - z.width / 2, 144) withAttributes: small]; }
	struct tm f = t; f.tm_mday = 1; mktime(&f); int lead = (f.tm_wday + 6) % 7; int dim_ = 31; { struct tm e = t; e.tm_mday = 32; mktime(&e); dim_ = 32 - e.tm_mday; }
	for (int d = 1; d <= dim_; d++) { int cell = lead + d - 1, col = cell % 7, row = cell / 7; NSRect r = NSMakeRect(18 + col * cw, 164 + row * 28, cw, 28); NSString *s = [NSString stringWithFormat: @"%d", d]; NSSize z = [s sizeWithAttributes: norm];
		if (d == t.tm_mday) { [[NSColor colorWithCalibratedRed: 1 green: 0.27 blue: 0.23 alpha: 1] setFill]; [[NSBezierPath bezierPathWithOvalInRect: NSMakeRect(NSMidX(r) - 12, NSMidY(r) - 12, 24, 24)] fill]; }
		[s drawAtPoint: NSMakePoint(NSMidX(r) - z.width / 2, NSMidY(r) - z.height / 2) withAttributes: norm]; }
}
@end

@interface NCWindow : NSWindow @end
@implementation NCWindow
- (BOOL)canBecomeKeyWindow { return YES; }
- (void)resignKeyWindow { [super resignKeyWindow]; [self orderOut: nil]; }
- (void)keyDown:(NSEvent *)e { if ([[e characters] isEqual: @"\x1b"]) [self orderOut: nil]; else [super keyDown: e]; }
@end

void ToggleNotificationCenter(void)
{
	static NCWindow *w; NSRect scr = [[NSScreen mainScreen] frame];
	if (w && [w isVisible]) { [w orderOut: nil]; return; }
	if (!w) { double h = 365; w = [[NCWindow alloc] initWithContentRect: NSMakeRect(scr.size.width - 14 - NW, scr.size.height - 30 - h, NW, h) styleMask: NSBorderlessWindowMask backing: NSBackingStoreBuffered defer: NO];
		[w setOpaque: NO]; [w setBackgroundColor: [NSColor clearColor]]; [w setHasShadow: NO]; [w setLevel: 22]; [w setHidesOnDeactivate: NO]; [w setContentView: [[NCView alloc] initWithFrame: NSMakeRect(0, 0, NW, h)]]; }
	else [[w contentView] setNeedsDisplay: YES];
	[NSApp activateIgnoringOtherApps: YES]; [w makeKeyAndOrderFront: nil];
}
