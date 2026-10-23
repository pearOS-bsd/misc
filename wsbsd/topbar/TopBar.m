/* TopBar: the status area of the menu bar, the right side (the left side, the logo item and the menus of the program, is drawn by the program itself: appkit/back-wsd/WsdMenuBar.m).
 * Measured on the Mac (3440 x 1440, 1 pt = 1 px, bar 30 pt, no background of its own): the clock text ends 25 px from the right edge ("Fri 23 Oct  12:21", the date and the time with two spaces
 * between them, text cap height 10 px from y = 9), then to the left the icons on a pitch of 37 px with their centres at 149 (Siri), 186 (Control Center), 223 (Spotlight) and, when the machine has a
 * battery, 260 (a white capsule 25 x 12 with the percentage cut out) px from the right edge; symbols 13 pt. The colour of the text follows the wallpaper under the bar like the menus. */
#import <AppKit/AppKit.h>
#include <math.h>
#include <string.h>
#include <dlfcn.h>
#include <sys/sysctl.h>

#define BAR_H 30
@interface NSObject (TBSymbols) + (BOOL)drawSymbol:(NSString *)name inRect:(NSRect)cell size:(CGFloat)pt weight:(int)weight color:(NSColor *)c; @end

static int BatteryPercent(void) { int v = -1; size_t n = sizeof v; if (sysctlbyname("hw.acpi.battery.life", &v, &n, NULL, 0) != 0) return getenv("TOPBAR_FAKE_BATTERY") ? 100 : -1; return v; }
static BOOL BatteryCharging(void) { int v = 0; size_t n = sizeof v; if (sysctlbyname("hw.acpi.battery.state", &v, &n, NULL, 0) != 0) return NO; return (v & 2) != 0; }     /* ACPI battery state: 1 discharging, 2 charging */
static BOOL LightText(void) { static BOOL (*fn)(void); static BOOL looked; if (!looked) { looked = YES; fn = (BOOL (*)(void))dlsym(RTLD_DEFAULT, "WsdBarWantsLightText"); } return fn ? fn() : YES; }

void ToggleControlCenter(void); void ToggleSpotlight(void); void ShowBatteryMenu(NSView *v, double rightEdge); void ToggleNotificationCenter(void); void NCStart(void);
@interface BarView : NSView { NSTimer *timer; int battery; BOOL charging; NSInteger pressed; }
@end
@implementation BarView
- (BOOL)isFlipped { return YES; }
- (instancetype)initWithFrame:(NSRect)f
{
	if (!(self = [super initWithFrame: f])) return nil;
	battery = BatteryPercent(); charging = BatteryCharging(); pressed = -1;
	timer = [NSTimer scheduledTimerWithTimeInterval: 1.0 target: self selector: @selector(tick:) userInfo: nil repeats: YES];
	return self;
}
- (void)tick:(NSTimer *)t { battery = BatteryPercent(); charging = BatteryCharging(); [self setNeedsDisplay: YES]; }
/* the centres of the items counted from the right edge, the same on every screen */
- (NSArray *)centres { NSMutableArray *a = [NSMutableArray arrayWithObjects: @"siri", @149, @"cc", @186, @"search", @223, nil]; if (battery >= 0 || getenv("TOPBAR_FAKE_BATTERY")) { [a addObject: @"battery"]; [a addObject: @260]; } return a; }
- (NSString *)clockString
{
	time_t now = time(NULL); struct tm tmv; localtime_r(&now, &tmv); char d[48], tp[16]; strftime(d, sizeof d, "%a %e %b", &tmv); strftime(tp, sizeof tp, "%H:%M", &tmv);
	NSMutableString *s = [NSMutableString stringWithUTF8String: d]; while ([s containsString: @"  "]) [s replaceOccurrencesOfString: @"  " withString: @" " options: 0 range: NSMakeRange(0, [s length])];
	return [NSString stringWithFormat: @"%@  %s", s, tp];
}
- (void)drawRect:(NSRect)dirty
{
	double W = [self bounds].size.width; BOOL light = LightText(); NSColor *fg = light ? [NSColor colorWithCalibratedWhite: 1 alpha: 1] : [NSColor colorWithCalibratedWhite: 0 alpha: 0.9];
	NSFont *font = [NSFont systemFontOfSize: 13]; NSDictionary *at = @{ NSFontAttributeName: font, NSForegroundColorAttributeName: fg };
	NSString *clk = [self clockString]; NSSize cs = [clk sizeWithAttributes: at]; double right = W - 25 + 1;                                         /* the last lit column is 25 px from the edge */
	if (pressed == 99) { [[NSColor colorWithCalibratedWhite: light ? 1 : 0 alpha: light ? 0.13 : 0.12] setFill]; [[NSBezierPath bezierPathWithRoundedRect: NSMakeRect(right - cs.width - 8, 3, cs.width + 16, 24) xRadius: 6 yRadius: 6] fill]; }
	[clk drawAtPoint: NSMakePoint(right - cs.width, 15 - cs.height / 2 - 0.5) withAttributes: at];                                              /* cap height 10 centred on y = 13.5 */
	NSArray *c = [self centres];
	for (NSUInteger i = 0; i + 1 < [c count]; i += 2) {
		NSString *n = c[i]; double cx = W - [c[i + 1] doubleValue], cy = 15;
		if (pressed == (NSInteger)i) { double w = [n isEqual: @"battery"] ? 33 : 25; [[NSColor colorWithCalibratedWhite: light ? 1 : 0 alpha: light ? 0.13 : 0.12] setFill]; [[NSBezierPath bezierPathWithRoundedRect: NSMakeRect(cx - w / 2 - 4, 3, w + 8, 24) xRadius: 6 yRadius: 6] fill]; }
		if ([n isEqual: @"siri"]) [self drawSiri: NSMakePoint(cx, cy) color: fg];
		else if ([n isEqual: @"cc"]) [NSClassFromString(@"WsdFinderSupport") drawSymbol: @"switch.2" inRect: NSMakeRect(cx - 9, cy - 9, 18, 18) size: 17 weight: 5 color: fg];
		else if ([n isEqual: @"search"]) [NSClassFromString(@"WsdFinderSupport") drawSymbol: @"magnifyingglass" inRect: NSMakeRect(cx - 9, cy - 9, 18, 18) size: 17 weight: 5 color: fg];
		else [self drawBattery: NSMakePoint(cx, cy) color: fg light: light];
	}
}
/* the Siri item: a ring with the two bands of the orb across it */
- (void)drawSiri:(NSPoint)c color:(NSColor *)fg
{
	[fg setStroke]; NSBezierPath *r = [NSBezierPath bezierPathWithOvalInRect: NSMakeRect(c.x - 6, c.y - 6, 12, 12)]; [r setLineWidth: 1.3]; [r stroke];
	NSBezierPath *s = [NSBezierPath bezierPath]; [s setLineWidth: 1.3]; [s setLineCapStyle: NSRoundLineCapStyle]; [s moveToPoint: NSMakePoint(c.x - 4.8, c.y - 1.5)]; [s curveToPoint: NSMakePoint(c.x + 4.8, c.y + 1.5) controlPoint1: NSMakePoint(c.x - 1, c.y - 5) controlPoint2: NSMakePoint(c.x + 1, c.y + 5)]; [s stroke];
	NSBezierPath *s2 = [NSBezierPath bezierPath]; [s2 setLineWidth: 1.3]; [s2 setLineCapStyle: NSRoundLineCapStyle]; [s2 moveToPoint: NSMakePoint(c.x - 4.8, c.y + 2)]; [s2 curveToPoint: NSMakePoint(c.x + 4.8, c.y - 2) controlPoint1: NSMakePoint(c.x - 1, c.y - 2) controlPoint2: NSMakePoint(c.x + 1, c.y + 2)]; [s2 stroke];
}
/* the battery: a capsule 25 x 12 filled white with the percentage cut out (the bar shows through) and, charging, the bolt */
- (void)drawBattery:(NSPoint)c color:(NSColor *)fg light:(BOOL)light
{
	NSRect body = NSMakeRect(c.x - 13.5, c.y - 6, 23, 12); [fg setFill]; [[NSBezierPath bezierPathWithRoundedRect: body xRadius: 4 yRadius: 4] fill];
	NSBezierPath *cap = [NSBezierPath bezierPathWithRoundedRect: NSMakeRect(NSMaxX(body) + 1, c.y - 2.5, 2, 5) xRadius: 1 yRadius: 1]; [[fg colorWithAlphaComponent: 0.5] setFill]; [cap fill];
	NSString *pc = [NSString stringWithFormat: @"%d", battery]; NSDictionary *a = @{ NSFontAttributeName: [NSFont boldSystemFontOfSize: 10], NSForegroundColorAttributeName: light ? [NSColor colorWithCalibratedWhite: 0.1 alpha: 1] : [NSColor colorWithCalibratedWhite: 1 alpha: 1] };
	NSSize ts = [pc sizeWithAttributes: a]; double tx = NSMinX(body) + (charging ? 3 : (body.size.width - ts.width) / 2); [pc drawAtPoint: NSMakePoint(tx, c.y - ts.height / 2) withAttributes: a];
	if (charging) [NSClassFromString(@"WsdFinderSupport") drawSymbol: @"bolt.fill" inRect: NSMakeRect(NSMaxX(body) - 9, c.y - 5, 8, 10) size: 8 weight: 6 color: a[NSForegroundColorAttributeName]];
}
- (BOOL)acceptsFirstMouse:(NSEvent *)e { return YES; }
- (void)mouseDown:(NSEvent *)e
{
	if (getenv("TOPBAR_DEBUG")) NSLog(@"topbar mouseDown %@", NSStringFromPoint([self convertPoint: [e locationInWindow] fromView: nil]));
	NSPoint p = [self convertPoint: [e locationInWindow] fromView: nil]; double W = [self bounds].size.width; NSArray *c = [self centres]; pressed = -1;
	NSSize cs = [[self clockString] sizeWithAttributes: @{ NSFontAttributeName: [NSFont systemFontOfSize: 13] }]; if (p.x > W - 25 - cs.width - 8) pressed = 99;
	for (NSUInteger i = 0; pressed < 0 && i + 1 < [c count]; i += 2) if (fabs(p.x - (W - [c[i + 1] doubleValue])) < 18) pressed = (NSInteger)i;
	[self setNeedsDisplay: YES];
}
- (void)mouseUp:(NSEvent *)e { NSArray *c = [self centres]; if (pressed == 99) ToggleNotificationCenter(); else if (pressed >= 0 && pressed < 99 && [c[pressed] isEqual: @"cc"]) ToggleControlCenter(); else if (pressed >= 0 && pressed < 99 && [c[pressed] isEqual: @"search"]) ToggleSpotlight(); else if (pressed >= 0 && pressed < 99 && [c[pressed] isEqual: @"battery"]) ShowBatteryMenu(self, [[self window] frame].origin.x + [self bounds].size.width - [c[pressed + 1] doubleValue] + 24); pressed = -1; [self setNeedsDisplay: YES]; }
@end

int main(int argc, char *argv[])
{
	@autoreleasepool {
		NSApplication *app = [NSApplication sharedApplication];
		NSRect scr = [[NSScreen mainScreen] frame]; double width = 300;
		NSWindow *win = [[NSWindow alloc] initWithContentRect: NSMakeRect(scr.size.width - width, scr.size.height - BAR_H, width, BAR_H) styleMask: NSBorderlessWindowMask backing: NSBackingStoreBuffered defer: NO];
		[win setOpaque: NO]; [win setBackgroundColor: [NSColor clearColor]]; [win setHasShadow: NO]; [win setLevel: 21]; [win setHidesOnDeactivate: NO]; [win setCanHide: NO];
		BarView *v = [[BarView alloc] initWithFrame: NSMakeRect(0, 0, width, BAR_H)]; [win setContentView: v];
		[win orderFrontRegardless]; NCStart(); [app run];
	}
	return 0;
}
