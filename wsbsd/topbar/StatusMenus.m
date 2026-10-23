/* The battery panel of the status area. Rows from the accessibility tree of the real Control Center (the panel is 304 wide, text from 10 pt in; from the top of the panel at y 31: "Battery" 13 pt bold
 * at y 13, "Power Source: ..." at 38 and the state at 56 (dimmed), a heading "Energy Mode" at 87, the Low Power switch row 280 x 32 at 106, a heading "Using Significant Energy" at 152 and its application
 * rows 280 x 22 from 171, "Battery Settings…" 280 x 22 at 204; the panel is 233 high, its right edge 24 pt right of the item's centre). The section of the applications using energy is left out when
 * there are none here (there is no such list on this system; unmeasured on the Mac). The Low Power switch is drawn only: nothing sets it. The material is the window server's menu glass. */
#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSDisplayServer.h>
#include <sys/sysctl.h>
@interface NSObject (SMSymbols) + (BOOL)drawSymbol:(NSString *)name inRect:(NSRect)cell size:(CGFloat)pt weight:(int)weight color:(NSColor *)c; @end
@interface NSObject (SMGlass) - (void)wsdMenuGlass:(int)win :(int)w :(int)h; @end

static int Sys(const char *name, int def) { int v = def; size_t n = sizeof v; if (sysctlbyname(name, &v, &n, NULL, 0)) return def; return v; }
@interface BatteryView : NSView { NSInteger hot; BOOL lowPower; }
@end
@implementation BatteryView
- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstMouse:(NSEvent *)e { return YES; }
- (NSArray *)rows { return @[ @[ @"low", @(106), @(32) ], @[ @"settings", @(204), @(22) ] ]; }
- (void)drawRect:(NSRect)dirty
{
	NSColor *white = [NSColor colorWithCalibratedWhite: 1 alpha: 0.95], *dim = [NSColor colorWithCalibratedWhite: 1 alpha: 0.5];
	NSDictionary *bold = @{ NSFontAttributeName: [NSFont boldSystemFontOfSize: 13], NSForegroundColorAttributeName: white }, *norm = @{ NSFontAttributeName: [NSFont systemFontOfSize: 13], NSForegroundColorAttributeName: white }, *soft = @{ NSFontAttributeName: [NSFont systemFontOfSize: 13], NSForegroundColorAttributeName: dim };
	int pct = Sys("hw.acpi.battery.life", 100), state = Sys("hw.acpi.battery.state", 0), ac = Sys("hw.acpi.acline", 1), mins = Sys("hw.acpi.battery.time", -1);
	[@"Battery" drawAtPoint: NSMakePoint(10, 13) withAttributes: bold]; [[NSString stringWithFormat: @"Power Source: %@", ac ? @"Power Adapter" : @"Battery"] drawAtPoint: NSMakePoint(10, 38) withAttributes: soft];
	NSString *st = (state & 2) ? [NSString stringWithFormat: @"Charging, %d%%", pct] : (pct >= 100 ? @"Fully Charged" : (mins > 0 ? [NSString stringWithFormat: @"%d:%02d remaining", mins / 60, mins % 60] : [NSString stringWithFormat: @"%d%%", pct])); [st drawAtPoint: NSMakePoint(10, 56) withAttributes: soft];
	[[NSColor colorWithCalibratedWhite: 1 alpha: 0.14] setFill]; NSRectFill(NSMakeRect(10, 79, 284, 1)); [@"Energy Mode" drawAtPoint: NSMakePoint(10, 87) withAttributes: soft];
	NSRect lp = NSMakeRect(10, 106, 280, 32); if (hot == 0) { [[NSColor colorWithCalibratedWhite: 1 alpha: 0.12] setFill]; [[NSBezierPath bezierPathWithRoundedRect: lp xRadius: 8 yRadius: 8] fill]; }
	[[NSColor colorWithCalibratedWhite: 1 alpha: lowPower ? 0.95 : 0.2] setFill]; NSRect ic = NSMakeRect(14, 110, 24, 24); [[NSBezierPath bezierPathWithRoundedRect: ic xRadius: 12 yRadius: 12] fill]; [NSClassFromString(@"WsdFinderSupport") drawSymbol: @"battery.25percent" inRect: NSInsetRect(ic, 4, 6) size: 12 weight: 5 color: lowPower ? [NSColor blackColor] : white];
	[@"Low Power" drawAtPoint: NSMakePoint(46, 106 + (32 - 16) / 2) withAttributes: norm];
	[[NSColor colorWithCalibratedWhite: 1 alpha: 0.14] setFill]; NSRectFill(NSMakeRect(10, 196, 284, 1));
	NSRect sr = NSMakeRect(10, 204, 280, 22); if (hot == 1) { [[NSColor colorWithCalibratedRed: 0 green: 0.48 blue: 1 alpha: 1] setFill]; [[NSBezierPath bezierPathWithRoundedRect: sr xRadius: 6 yRadius: 6] fill]; }
	[@"Battery Settings…" drawAtPoint: NSMakePoint(20, 204 + 3) withAttributes: norm];
}
- (NSInteger)rowAt:(NSPoint)p { NSArray *r = [self rows]; for (NSUInteger i = 0; i < [r count]; i++) { double y = [r[i][1] doubleValue], h = [r[i][2] doubleValue]; if (p.y >= y && p.y < y + h && p.x >= 10 && p.x < 290) return (NSInteger)i; } return -1; }
- (void)mouseMoved:(NSEvent *)e { NSInteger h = [self rowAt: [self convertPoint: [e locationInWindow] fromView: nil]]; if (h != hot) { hot = h; [self setNeedsDisplay: YES]; } }
- (void)mouseDown:(NSEvent *)e
{
	NSInteger r = [self rowAt: [self convertPoint: [e locationInWindow] fromView: nil]]; if (r == 0) { lowPower = !lowPower; [self setNeedsDisplay: YES]; }
	else if (r == 1) { for (NSString *a in @[ @"/System/Applications/System Settings.app", @"/Applications/System Settings.app" ]) if ([[NSFileManager defaultManager] fileExistsAtPath: a]) { [[NSWorkspace sharedWorkspace] launchApplication: a]; break; } [[self window] orderOut: nil]; }
}
- (void)updateTrackingAreas { [super updateTrackingAreas]; [self addTrackingRect: [self bounds] owner: self userData: NULL assumeInside: NO]; }
@end
@interface BatteryWindow : NSWindow @end
@implementation BatteryWindow
- (BOOL)canBecomeKeyWindow { return YES; }
- (void)resignKeyWindow { [super resignKeyWindow]; [self orderOut: nil]; }
- (void)keyDown:(NSEvent *)e { if ([[e characters] isEqual: @"\x1b"]) [self orderOut: nil]; else [super keyDown: e]; }
@end

/* rightEdge: the right edge of the panel in the screen's coordinates counted from its left edge */
void ShowBatteryMenu(NSView *bar, double rightEdge)
{
	static BatteryWindow *w; NSRect scr = [[NSScreen mainScreen] frame]; double W = 304, H = 233;
	if (w && [w isVisible]) { [w orderOut: nil]; return; }
	NSRect f = NSMakeRect(rightEdge - W, scr.size.height - 31 - H, W, H);
	if (!w) { w = [[BatteryWindow alloc] initWithContentRect: f styleMask: NSBorderlessWindowMask backing: NSBackingStoreBuffered defer: NO]; [w setOpaque: NO]; [w setBackgroundColor: [NSColor clearColor]]; [w setHasShadow: NO]; [w setLevel: 22]; [w setHidesOnDeactivate: NO]; [w setAcceptsMouseMovedEvents: YES]; [w setContentView: [[BatteryView alloc] initWithFrame: NSMakeRect(0, 0, W, H)]]; }
	else { [w setFrame: f display: YES]; [[w contentView] setNeedsDisplay: YES]; }
	[NSApp activateIgnoringOtherApps: YES]; [w makeKeyAndOrderFront: nil];
	id srv = GSCurrentServer(); if ([srv respondsToSelector: @selector(wsdMenuGlass:::)]) [srv wsdMenuGlass: (int)[w windowNumber] : (int)W : (int)H];
}
