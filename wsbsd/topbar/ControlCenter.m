/* The Control Center panel (the item of the status area): tiles of glass on a grid of 63 pt cells with 13.5 pt gaps (4 columns, rows on a pitch of 76.5 pt), measured on the Mac: the panel is 292 wide, its right edge
 * 14 pt from the screen's, its first row 13 pt under the menu bar; a tile is dark glass with a light 1 pt rim, a circle button is white when on (the icon in its colour) and dark when off; the Sound slider
 * is a white bar on a dark track with no knob. Working here: Dark Mode (the appearance key of the global preferences), Sound (mixer), Display brightness (backlight), Wi-Fi (ifconfig), the battery state;
 * the other tiles are drawn and switch their look when clicked. */
#import <AppKit/AppKit.h>
#include <math.h>
#include <sys/sysctl.h>
@interface NSObject (CCSymbols) + (BOOL)drawSymbol:(NSString *)name inRect:(NSRect)cell size:(CGFloat)pt weight:(int)weight color:(NSColor *)c; @end

#define CELL 63.0
#define GAP 13.5
#define PANEL_W 292.0
static double ColX(int c) { return c * (CELL + GAP); }
static double RowY(double k) { return 13 + k * (CELL + GAP); }

static NSString *Run(NSString *path, NSArray *args)
{
	NSTask *t = [[NSTask alloc] init]; NSPipe *p = [NSPipe pipe]; [t setLaunchPath: path]; [t setArguments: args]; [t setStandardOutput: p]; [t setStandardError: [NSPipe pipe]];
	@try { [t launch]; NSData *d = [[p fileHandleForReading] readDataToEndOfFile]; [t waitUntilExit]; return [[NSString alloc] initWithData: d encoding: NSUTF8StringEncoding]; } @catch (NSException *e) { return nil; }
}
/* the first number of a line like "vol:0.50:0.50" or "vol = 0.50:0.50" (FreeBSD mixer(8)); -1 when there is no mixer */
static double FirstFloat(NSString *o) { if (!o) return -1; NSScanner *sc = [NSScanner scannerWithString: o]; [sc setCharactersToBeSkipped: [NSCharacterSet characterSetWithCharactersInString: @"abcdefghijklmnopqrstuvwxyz :=\n"]]; double v; return [sc scanDouble: &v] ? v : -1; }
static double MixerVolume(void) { return FirstFloat(Run(@"/usr/sbin/mixer", @[ @"-s", @"vol" ])); }
static void SetMixerVolume(double v) { Run(@"/usr/sbin/mixer", @[ [NSString stringWithFormat: @"vol=%.2f", v] ]); }
static double Brightness(void) { NSString *o = Run(@"/usr/bin/backlight", @[]); if (!o) return -1; NSArray *w = [o componentsSeparatedByCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]]; for (NSString *x in w) if ([x doubleValue] > 0) return [x doubleValue] / 100.0; return -1; }
static void SetBrightness(double v) { Run(@"/usr/bin/backlight", @[ [NSString stringWithFormat: @"%d", (int)lround(v * 100)] ]); }
static int BatteryPct(void) { int v = -1; size_t n = sizeof v; if (sysctlbyname("hw.acpi.battery.life", &v, &n, NULL, 0)) return -1; return v; }
static BOOL Charging(void) { int v = 0; size_t n = sizeof v; if (sysctlbyname("hw.acpi.battery.state", &v, &n, NULL, 0)) return NO; return (v & 2) != 0; }
static NSString *GlobalPrefsPath(void) { return [NSHomeDirectory() stringByAppendingPathComponent: @"Library/Preferences/.GlobalPreferences.plist"]; }
static BOOL DarkNow(void) { NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile: GlobalPrefsPath()]; id v = d[@"AppleInterfaceStyle"]; return !v || [v caseInsensitiveCompare: @"Dark"] == NSOrderedSame; }
static void SetDark(BOOL dark)
{
	NSString *f = GlobalPrefsPath(); NSMutableDictionary *d = [[NSDictionary dictionaryWithContentsOfFile: f] mutableCopy] ?: [NSMutableDictionary dictionary]; if (dark) d[@"AppleInterfaceStyle"] = @"Dark"; else [d removeObjectForKey: @"AppleInterfaceStyle"];
	[[NSFileManager defaultManager] createDirectoryAtPath: [f stringByDeletingLastPathComponent] withIntermediateDirectories: YES attributes: nil error: NULL]; [d writeToFile: f atomically: YES];
}

@interface CCView : NSView { NSMutableDictionary *on; NSString *drag; double volume, brightness; NSArray *tiles; }
@end
@implementation CCView
- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstMouse:(NSEvent *)e { return YES; }
- (instancetype)initWithFrame:(NSRect)f
{
	if (!(self = [super initWithFrame: f])) return nil;
	on = [NSMutableDictionary dictionaryWithDictionary: @{ @"wifi": @YES, @"bluetooth": @NO, @"dark": @(DarkNow()), @"truetone": @NO, @"airdrop": @NO, @"stage": @NO, @"mirror": @NO, @"kbd": @NO, @"focus": @NO }];
	volume = MixerVolume(); brightness = Brightness(); if (volume < 0) volume = 0.5;
	/* kind, id, column, row, columns, rows, symbol, title */
	tiles = @[ @[ @"circle", @"wifi", @0, @0, @1, @1, @"wifi", @"" ], @[ @"circle", @"bluetooth", @1, @0, @1, @1, @"bluetooth", @"" ], @[ @"nowplaying", @"np", @2, @0, @2, @2, @"", @"Not Playing" ],
		@[ @"circle", @"dark", @0, @1, @1, @1, @"circle.lefthalf.filled", @"" ], @[ @"circle", @"truetone", @1, @1, @1, @1, @"sun.max", @"" ],
		@[ @"wide", @"airdrop", @0, @2, @2, @1, @"airplayaudio", @"AirDrop" ], @[ @"circle", @"stage", @2, @2, @1, @1, @"rectangle.3.group", @"" ], @[ @"circle", @"mirror", @3, @2, @1, @1, @"rectangle.on.rectangle", @"" ],
		@[ @"circle", @"kbd", @0, @3, @1, @1, @"light.max", @"" ], @[ @"circle", @"display", @1, @3, @1, @1, @"display", @"" ], @[ @"wide", @"focus", @2, @3, @2, @1, @"moon.fill", @"Focus" ],
		@[ @"slider", @"sound", @0, @4, @4, @1, @"speaker.fill", @"Sound" ], @[ @"slider", @"bright", @1, @5, @2, @1, @"sun.max.fill", @"Display" ],
		@[ @"tall", @"saver", @0, @6, @2, @2, @"display", @"Start Screen Saver" ], @[ @"slider", @"kbdlight", @2, @6, @2, @1, @"light.max", @"Keyboard" ], @[ @"battery", @"battery", @2, @7, @2, @1, @"battery.100percent", @"" ] ];
	return self;
}
- (NSRect)rectOf:(NSArray *)t { return NSMakeRect(ColX([t[2] intValue]), RowY([t[3] doubleValue]), [t[4] intValue] * CELL + ([t[4] intValue] - 1) * GAP, [t[5] intValue] * CELL + ([t[5] intValue] - 1) * GAP); }
static void Glass(NSRect r, double rad) { NSBezierPath *p = [NSBezierPath bezierPathWithRoundedRect: r xRadius: rad yRadius: rad]; [[NSColor colorWithCalibratedRed: 0.11 green: 0.11 blue: 0.12 alpha: 0.88] setFill]; [p fill]; [[NSColor colorWithCalibratedWhite: 1 alpha: 0.14] setStroke]; [p setLineWidth: 1]; [NSBezierPath strokeRect: NSZeroRect]; NSBezierPath *rim = [NSBezierPath bezierPathWithRoundedRect: NSInsetRect(r, 0.5, 0.5) xRadius: rad yRadius: rad]; [rim setLineWidth: 1]; [rim stroke]; }
static void Sym(NSString *n, NSRect r, double pt, NSColor *c) { [NSClassFromString(@"WsdFinderSupport") drawSymbol: n inRect: r size: pt weight: 5 color: c]; }
- (void)drawRect:(NSRect)dirty
{
	NSColor *white = [NSColor colorWithCalibratedWhite: 1 alpha: 0.95], *dim = [NSColor colorWithCalibratedWhite: 1 alpha: 0.6];
	NSDictionary *tf = @{ NSFontAttributeName: [NSFont boldSystemFontOfSize: 12], NSForegroundColorAttributeName: white }, *sf = @{ NSFontAttributeName: [NSFont systemFontOfSize: 11], NSForegroundColorAttributeName: dim };
	for (NSArray *t in tiles) {
		NSRect r = [self rectOf: t]; NSString *k = t[0], *id_ = t[1]; BOOL isOn = [on[id_] boolValue];
		if ([k isEqual: @"circle"]) {
			NSBezierPath *c = [NSBezierPath bezierPathWithOvalInRect: r]; if (isOn) { [[NSColor colorWithCalibratedWhite: 1 alpha: 0.98] setFill]; [c fill]; } else { Glass(r, CELL / 2); }
			NSColor *ic = isOn ? ([id_ isEqual: @"wifi"] || [id_ isEqual: @"bluetooth"] ? [NSColor colorWithCalibratedRed: 0 green: 0.48 blue: 1 alpha: 1] : [NSColor colorWithCalibratedWhite: 0.1 alpha: 1]) : white; Sym(t[6], NSInsetRect(r, 15, 15), 22, ic);
		} else if ([k isEqual: @"wide"]) {
			Glass(r, CELL / 2); NSRect ic = NSMakeRect(r.origin.x + 8, r.origin.y + 8, 47, 47); [(isOn ? [NSColor colorWithCalibratedWhite: 1 alpha: 0.98] : [NSColor colorWithCalibratedWhite: 1 alpha: 0.28]) setFill]; [[NSBezierPath bezierPathWithOvalInRect: ic] fill]; Sym(t[6], NSInsetRect(ic, 11, 11), 18, isOn ? [NSColor colorWithCalibratedWhite: 0.1 alpha: 1] : white);
			[t[7] drawAtPoint: NSMakePoint(NSMaxX(ic) + 10, NSMidY(r) - ([id_ isEqual: @"airdrop"] ? 15 : 8)) withAttributes: tf]; if ([id_ isEqual: @"airdrop"]) [(isOn ? @"Contacts Only" : @"Off") drawAtPoint: NSMakePoint(NSMaxX(ic) + 10, NSMidY(r) + 1) withAttributes: sf];
		} else if ([k isEqual: @"nowplaying"]) {
			Glass(r, 20); NSSize z = [t[7] sizeWithAttributes: tf]; [t[7] drawAtPoint: NSMakePoint(NSMidX(r) - z.width / 2, NSMidY(r) - z.height / 2) withAttributes: tf]; Sym(@"play.fill", NSMakeRect(NSMidX(r) - 10, NSMaxY(r) - 36, 20, 20), 16, dim);
		} else if ([k isEqual: @"slider"]) {
			Glass(r, 20); [t[7] drawAtPoint: NSMakePoint(r.origin.x + 14, r.origin.y + 9) withAttributes: tf]; double v = [id_ isEqual: @"sound"] ? volume : [id_ isEqual: @"bright"] ? (brightness < 0 ? 0.6 : brightness) : 0.5;
			NSRect tr = NSMakeRect(r.origin.x + ([id_ isEqual: @"sound"] ? 38 : 34), NSMaxY(r) - 26, r.size.width - ([id_ isEqual: @"sound"] ? 38 + 80 : 34 + 14), 4); [[NSColor colorWithCalibratedWhite: 1 alpha: 0.18] setFill]; [[NSBezierPath bezierPathWithRoundedRect: tr xRadius: 2 yRadius: 2] fill];
			NSRect fr = tr; fr.size.width *= v; [white setFill]; [[NSBezierPath bezierPathWithRoundedRect: fr xRadius: 2 yRadius: 2] fill];
			Sym(t[6], NSMakeRect(r.origin.x + 12, NSMaxY(r) - 32, 16, 16), 12, white); if ([id_ isEqual: @"sound"]) { Sym(@"speaker.wave.3.fill", NSMakeRect(NSMaxX(tr) + 10, NSMaxY(r) - 32, 20, 16), 12, white); [[NSColor colorWithCalibratedWhite: 1 alpha: 0.28] setFill]; [[NSBezierPath bezierPathWithOvalInRect: NSMakeRect(NSMaxX(r) - 42, NSMaxY(r) - 41, 30, 30)] fill]; Sym(@"airplayaudio", NSMakeRect(NSMaxX(r) - 37, NSMaxY(r) - 36, 20, 20), 13, white); }
		} else if ([k isEqual: @"tall"]) {
			Glass(r, 24); Sym(t[6], NSMakeRect(r.origin.x + 14, r.origin.y + 14, 28, 28), 24, white); [t[7] drawInRect: NSMakeRect(r.origin.x + 14, NSMaxY(r) - 34, r.size.width - 28, 30) withAttributes: tf];
		} else if ([k isEqual: @"battery"]) {
			Glass(r, CELL / 2); int b = BatteryPct(); NSString *s = b >= 0 ? [NSString stringWithFormat: @"%d%%", b] : @"AC"; NSSize z = [s sizeWithAttributes: tf]; double x0 = NSMidX(r) - (z.width + 28) / 2; Sym(Charging() ? @"battery.100percent.bolt" : @"battery.100percent", NSMakeRect(x0, NSMidY(r) - 10, 22, 20), 17, white); [s drawAtPoint: NSMakePoint(x0 + 28, NSMidY(r) - z.height / 2) withAttributes: tf];
		}
	}
	NSRect ec = NSMakeRect(PANEL_W / 2 - 47, RowY(8) + 1, 94, 23); Glass(ec, 11.5); NSSize ez = [@"Edit Controls" sizeWithAttributes: sf]; [@"Edit Controls" drawAtPoint: NSMakePoint(NSMidX(ec) - ez.width / 2, NSMidY(ec) - ez.height / 2) withAttributes: @{ NSFontAttributeName: [NSFont systemFontOfSize: 11], NSForegroundColorAttributeName: white }];
}
- (void)set:(NSString *)id_ at:(NSPoint)p inRect:(NSRect)r
{
	double lo = r.origin.x + ([id_ isEqual: @"sound"] ? 38 : 34), w = r.size.width - ([id_ isEqual: @"sound"] ? 118 : 48), v = MAX(0, MIN(1, (p.x - lo) / w));
	if ([id_ isEqual: @"sound"]) { volume = v; SetMixerVolume(v); } else if ([id_ isEqual: @"bright"]) { brightness = v; SetBrightness(v); }
	[self setNeedsDisplay: YES];
}
- (void)mouseDown:(NSEvent *)e
{
	NSPoint p = [self convertPoint: [e locationInWindow] fromView: nil]; drag = nil;
	for (NSArray *t in tiles) { NSRect r = [self rectOf: t]; if (!NSPointInRect(p, r)) continue; NSString *id_ = t[1];
		if ([t[0] isEqual: @"slider"]) { if ([id_ isEqual: @"sound"] || [id_ isEqual: @"bright"]) { drag = id_; [self set: id_ at: p inRect: r]; } return; }
		if ([t[0] isEqual: @"circle"] || [t[0] isEqual: @"wide"]) { BOOL v = ![on[id_] boolValue]; on[id_] = @(v); if ([id_ isEqual: @"dark"]) SetDark(v); [self setNeedsDisplay: YES]; }
		return; }
}
- (void)mouseDragged:(NSEvent *)e { if (!drag) return; NSPoint p = [self convertPoint: [e locationInWindow] fromView: nil]; for (NSArray *t in tiles) if ([t[1] isEqual: drag]) [self set: drag at: p inRect: [self rectOf: t]]; }
- (void)mouseUp:(NSEvent *)e { drag = nil; }
@end

@interface CCWindow : NSWindow @end
@implementation CCWindow
- (BOOL)canBecomeKeyWindow { return YES; }
- (void)resignKeyWindow { [super resignKeyWindow]; [self orderOut: nil]; }
- (void)keyDown:(NSEvent *)e { if ([[e characters] isEqual: @"\x1b"]) [self orderOut: nil]; else [super keyDown: e]; }
@end

/* the panel under the item: toggled by the status area */
void ToggleControlCenter(void)
{
	static CCWindow *w; NSRect scr = [[NSScreen mainScreen] frame];
	if (w && [w isVisible]) { [w orderOut: nil]; return; }
	if (!w) { double h = RowY(8) + 23 + 13; w = [[CCWindow alloc] initWithContentRect: NSMakeRect(scr.size.width - 14 - PANEL_W, scr.size.height - 30 - h, PANEL_W, h) styleMask: NSBorderlessWindowMask backing: NSBackingStoreBuffered defer: NO];
		[w setOpaque: NO]; [w setBackgroundColor: [NSColor clearColor]]; [w setHasShadow: NO]; [w setLevel: 22]; [w setHidesOnDeactivate: NO]; [w setContentView: [[CCView alloc] initWithFrame: NSMakeRect(0, 0, PANEL_W, h)]]; }
	else [[w contentView] setNeedsDisplay: YES];
	[w makeKeyAndOrderFront: nil];
}
