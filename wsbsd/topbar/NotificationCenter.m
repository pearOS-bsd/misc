/* The panel of the clock (Notification Center): measured on the Mac, 344 wide with its right edge 14 pt from the screen's, cards of dark glass with corners of 20 pt, 13 pt apart, the first one
 * 13 pt under the menu bar; the title of a card 13 pt bold, its text 13 pt dimmed. There is no notification service here yet: the panel shows only the "Edit Widgets" pill (the cards and the widgets of the Mac are not recreated). */
#import <AppKit/AppKit.h>
#include <time.h>

#define NW 344.0
@interface NCView : NSView @end
@implementation NCView
- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstMouse:(NSEvent *)e { return YES; }
static void Card(NSRect r) { NSBezierPath *p = [NSBezierPath bezierPathWithRoundedRect: r xRadius: 20 yRadius: 20]; [[NSColor colorWithCalibratedRed: 0.11 green: 0.11 blue: 0.12 alpha: 0.9] setFill]; [p fill]; NSBezierPath *rim = [NSBezierPath bezierPathWithRoundedRect: NSInsetRect(r, 0.5, 0.5) xRadius: 20 yRadius: 20]; [[NSColor colorWithCalibratedWhite: 1 alpha: 0.14] setStroke]; [rim stroke]; }
/* only what was seen on the Mac: the stack of notification cards (none here: there is no notification service) and the "Edit Widgets" pill under it, 13 pt from the bar */
- (void)drawRect:(NSRect)dirty
{
	NSDictionary *small = @{ NSFontAttributeName: [NSFont systemFontOfSize: 11], NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite: 1 alpha: 0.95] };
	NSRect ec = NSMakeRect(NW - 94 - 31, 13, 94, 23); NSBezierPath *p = [NSBezierPath bezierPathWithRoundedRect: ec xRadius: 11.5 yRadius: 11.5]; [[NSColor colorWithCalibratedRed: 0.11 green: 0.11 blue: 0.12 alpha: 0.9] setFill]; [p fill];
	[[NSColor colorWithCalibratedWhite: 1 alpha: 0.14] setStroke]; [[NSBezierPath bezierPathWithRoundedRect: NSInsetRect(ec, 0.5, 0.5) xRadius: 11.5 yRadius: 11.5] stroke];
	NSSize z = [@"Edit Widgets" sizeWithAttributes: small]; [@"Edit Widgets" drawAtPoint: NSMakePoint(NSMidX(ec) - z.width / 2, NSMidY(ec) - z.height / 2) withAttributes: small];
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
	if (!w) { double h = 60; w = [[NCWindow alloc] initWithContentRect: NSMakeRect(scr.size.width - 14 - NW, scr.size.height - 30 - h, NW, h) styleMask: NSBorderlessWindowMask backing: NSBackingStoreBuffered defer: NO];
		[w setOpaque: NO]; [w setBackgroundColor: [NSColor clearColor]]; [w setHasShadow: NO]; [w setLevel: 22]; [w setHidesOnDeactivate: NO]; [w setContentView: [[NCView alloc] initWithFrame: NSMakeRect(0, 0, NW, h)]]; }
	else [[w contentView] setNeedsDisplay: YES];
	[NSApp activateIgnoringOtherApps: YES]; [w makeKeyAndOrderFront: nil];
}
