/* TopBar: the status area of the menu bar (right side): control center, search, battery and the clock, measured on the real menu bar (3440 x 1440 screen: clock text ends 22 px from the right edge,
 * 13 pt, cap height 10 px; status icons 12 ... 25 px wide on a pitch of 37 px). The application's menus are drawn by the application itself (the theme's menu bar window); this window sits above it. */
#import <AppKit/AppKit.h>
#include <math.h>
#include <string.h>
#include <sys/sysctl.h>

#define BAR_H 30
static void SetW(CGContextRef c, double a) { CGContextSetRGBFillColor(c, 1, 1, 1, a); CGContextSetRGBStrokeColor(c, 1, 1, 1, a); }
static double TextWidth(CGContextRef c, const char *s, double size)
{
	CGContextSaveGState(c); CGContextSelectFont(c, "Helvetica", size, kCGEncodingMacRoman); CGContextSetTextMatrix(c, CGAffineTransformIdentity);
	CGContextTranslateCTM(c, -100000, -100000); CGContextSetTextPosition(c, 0, 0); CGContextShowText(c, s, strlen(s)); double w = CGContextGetTextPosition(c).x; CGContextRestoreGState(c); return w;
}
static void Text(CGContextRef c, const char *s, double size, double x, double y)
{
	CGContextSaveGState(c); CGContextSelectFont(c, "Helvetica", size, kCGEncodingMacRoman); CGContextSetTextMatrix(c, CGAffineTransformIdentity); CGContextShowTextAtPoint(c, x, y, s, strlen(s)); CGContextRestoreGState(c);
}
static int BatteryPercent(void) { int v = -1; size_t n = sizeof v; if (sysctlbyname("hw.acpi.battery.life", &v, &n, NULL, 0) != 0) return -1; return v; }

@interface BarView : NSView { NSTimer *timer; int battery; }
@end
@implementation BarView
- (BOOL)isFlipped { return NO; }
- (instancetype)initWithFrame:(NSRect)f
{
	if (!(self = [super initWithFrame: f])) return nil;
	battery = BatteryPercent();
	timer = [NSTimer scheduledTimerWithTimeInterval: 1.0 target: self selector: @selector(tick:) userInfo: nil repeats: YES];
	return self;
}
- (void)tick:(NSTimer *)t { battery = BatteryPercent(); [self setNeedsDisplay: YES]; }
- (void)drawRect:(NSRect)r
{
	CGContextRef c = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort]; if (!c) return;
	CGContextSaveGState(c); CGContextClearRect(c, NSRectToCGRect([self bounds])); CGContextRestoreGState(c);
	double W = [self bounds].size.width, y0 = 11.0;                    /* the text's baseline: 19 px below the top of the 30 px bar (measured on the real bar; menuBarHeight is 30, the menu bar font is 13 pt with a cap height of 9.16, from AppKit itself) */
	time_t now = time(NULL); struct tm tmv; localtime_r(&now, &tmv); /* ControlCenter's Clock module: "DATE_TIME_FORMAT_WITH_MONTH" is "%1$@  %2$@", the date and the time with TWO spaces between them (one when the date has no month) */
	char clk[64], dpart[32], tpart[16]; strftime(dpart, sizeof dpart, "%a ", &tmv); size_t dl = strlen(dpart); snprintf(dpart + dl, sizeof dpart - dl, "%d ", tmv.tm_mday); dl = strlen(dpart); strftime(dpart + dl, sizeof dpart - dl, "%b", &tmv);
	strftime(tpart, sizeof tpart, "%H:%M", &tmv); snprintf(clk, sizeof clk, "%s  %s", dpart, tpart);
	double tw = TextWidth(c, clk, 13), x = W - 22 - tw; SetW(c, 0.95); Text(c, clk, 13, x, y0);
	double cx = x - 24;                                                                       /* centre of the next icon: 37 px pitch in the real bar */
	double cy = 15.0;                                                                          /* the icons are centred 15 px above the bottom of the bar */
	SetW(c, 0.95);
	{   /* control center: two small toggles */
		CGContextSetLineWidth(c, 1.4);
		CGRect a = CGRectMake(cx - 6.5, cy + 1.2, 13, 5.6), b = CGRectMake(cx - 6.5, cy - 6.8, 13, 5.6);
		CGPathRef pa = CGPathCreateWithRect(a, NULL); (void)pa; CGPathRelease(pa);
		CGContextStrokeRect(c, a); CGContextStrokeRect(c, b);
		CGContextFillEllipseInRect(c, CGRectMake(cx + 1.5, cy + 1.6, 4.8, 4.8)); CGContextFillEllipseInRect(c, CGRectMake(cx - 6.2, cy - 6.4, 4.8, 4.8));
	}
	cx -= 37;
	{   /* search: a magnifying glass */
		CGContextSetLineWidth(c, 1.6); CGContextStrokeEllipseInRect(c, CGRectMake(cx - 6.5, cy - 2, 9.5, 9.5));
		CGContextMoveToPoint(c, cx + 2.2, cy - 2.2); CGContextAddLineToPoint(c, cx + 6.5, cy - 6.5); CGContextStrokePath(c);
	}
	if (battery >= 0) {                                                                       /* battery: an outline with the percentage inside, only when the machine has one */
		cx -= 37; char pc[8]; snprintf(pc, sizeof pc, "%d", battery);
		CGContextSetLineWidth(c, 1.2); CGContextStrokeRect(c, CGRectMake(cx - 12.5, cy - 5.5, 22, 11)); CGContextFillRect(c, CGRectMake(cx + 10, cy - 2, 2, 4));
		double w = TextWidth(c, pc, 8); Text(c, pc, 8, cx - 1.5 - w / 2, cy - 3);
	}
}
@end

int main(int argc, char *argv[])
{
	@autoreleasepool {
		NSApplication *app = [NSApplication sharedApplication];
		NSRect scr = [[NSScreen mainScreen] frame]; 
		double width = BatteryPercent() >= 0 ? 330 : 255;
		NSWindow *win = [[NSWindow alloc] initWithContentRect: NSMakeRect(scr.size.width - width, scr.size.height - BAR_H, width, BAR_H) styleMask: NSBorderlessWindowMask backing: NSBackingStoreBuffered defer: NO];
		[win setOpaque: NO]; [win setBackgroundColor: [NSColor clearColor]]; [win setHasShadow: NO]; [win setLevel: 21]; [win setHidesOnDeactivate: NO]; [win setCanHide: NO];
		BarView *v = [[BarView alloc] initWithFrame: NSMakeRect(0, 0, width, BAR_H)]; [win setContentView: v];
		[win orderFrontRegardless]; [app run];
	}
	return 0;
}
