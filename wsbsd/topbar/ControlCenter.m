/* The Control Center panel. Geometry from the accessibility tree of the real ControlCenter on the Mac (screen 3440 wide, the panel's tiles at x 3134 ... 3426: 292 wide, its right edge 14 from the
 * screen's), tiles of 64 pt on a pitch of 76 (columns x = 0, 76, 152, 228, rows y = 12 + 76 k under the menu bar, the Edit Controls pill at y = 624, 94 x 24): Wi-Fi (0,0), Bluetooth (1,0),
 * Now Playing 140 x 140 (2,0), Dark Mode (0,1), Night Shift (1,1), AirDrop 140 x 64 (0,2), Stage Manager (2,2), Screen Mirroring (3,2), True Tone (0,3), Display (1,3), Focus 140 x 64 (2,3), Sound
 * 292 x 64 (0,4), Display brightness 140 x 64 (1,5), Start Screen Saver 140 x 140 (0,6), Keyboard brightness 140 x 64 (2,6), Battery 140 x 64 (2,7). Inside the tiles (offsets from the tile): the title
 * of Sound/Display/Keyboard 15 pt high at (16 or 18, 11), the slider 14 high at y 35 (a track 4 high, 51 grey on 32, a white fill with no knob), Sound's slider from x 34, 181 wide, the AirPlay circle 26
 * at (252, 29); Display's slider from x 40, 82 wide; Keyboard's from x 42, 80 wide; Now Playing: the artwork 40 at (14, 14), the title at (14, 64), the three 30 pt buttons at y 96. Tile corners: 32
 * (Sound 22); the fill is the window server's glass slot of each tile; a circle that is on is white with the icon in its colour; the circle holding an icon in AirDrop and Focus is 36 wide at (15, 14)
 * in white 24 %. Not measured: the radius of the glass blur, the battery tile's inside, the icons that have no equivalent in the symbol set (Stage Manager, True Tone, Night Shift, AirDrop) and
 * the state of Wi-Fi/Bluetooth/AirDrop/Focus here (drawn, not connected). Working: Dark Mode (the appearance key of the global preferences), Sound (mixer), Display brightness (backlight), the Wi-Fi tile (power of the first CoreWLAN interface when CoreWLAN and airportd are there). */
#import <AppKit/AppKit.h>
#import <objc/message.h>
#import <GNUstepGUI/GSDisplayServer.h>
#include <math.h>
#include <sys/sysctl.h>
#include <dlfcn.h>
@interface NSObject (CCSymbols) + (BOOL)drawSymbol:(NSString *)name inRect:(NSRect)cell size:(CGFloat)pt weight:(int)weight color:(NSColor *)c; @end
@interface NSObject (CCGlass) - (void)wsdGlassSlot:(int)slot :(int)win :(NSRect)r :(int)radius :(int)mode; @end

/* Wi-Fi through CoreWLAN (the framework of this repository, which talks to airportd): loaded when it is on the system, the tile then shows and sets the power of the first interface */
id WifiInterface(void)
{
	static id iface; static BOOL tried; if (tried) return iface; tried = YES;
	dlopen("/System/Library/Frameworks/CoreWLAN.framework/Versions/A/CoreWLAN", RTLD_LAZY | RTLD_GLOBAL); Class c = NSClassFromString(@"CWWiFiClient"); if (!c) return nil;
	id client = ((id (*)(id, SEL))objc_msgSend)(c, @selector(sharedWiFiClient)); if (client) iface = ((id (*)(id, SEL))objc_msgSend)(client, @selector(interface)); return iface;
}
BOOL WifiPower(BOOL *known) { id i = WifiInterface(); if (!i) { *known = NO; return NO; } *known = YES; return ((BOOL (*)(id, SEL))objc_msgSend)(i, @selector(powerOn)); }
void SetWifiPower(BOOL on) { id i = WifiInterface(); if (i) { NSError *e = nil; ((BOOL (*)(id, SEL, BOOL, NSError **))objc_msgSend)(i, @selector(setPower:error:), on, &e); } }
#define PANEL_W 292.0
void ToggleWifiPanel(void); void ToggleBluetoothPanel(void); void ToggleSoundPanel(void); void ToggleDisplayPanel(void); void NCSetFocus(BOOL on);
static double ColX(int c) { return c * 76.0; }
static double RowY(double k) { return 12 + k * 76.0; }

static NSString *Run(NSString *path, NSArray *args)
{
	NSTask *t = [[NSTask alloc] init]; NSPipe *p = [NSPipe pipe]; [t setLaunchPath: path]; [t setArguments: args]; [t setStandardOutput: p]; [t setStandardError: [NSPipe pipe]];
	@try { [t launch]; NSData *d = [[p fileHandleForReading] readDataToEndOfFile]; [t waitUntilExit]; return [[NSString alloc] initWithData: d encoding: NSUTF8StringEncoding]; } @catch (NSException *e) { return nil; }
}
/* the first number of a line like "vol:0.50:0.50" or "vol = 0.50:0.50" (FreeBSD mixer(8)); -1 when there is no mixer */
static double FirstFloat(NSString *o) { if (!o) return -1; NSScanner *sc = [NSScanner scannerWithString: o]; [sc setCharactersToBeSkipped: [NSCharacterSet characterSetWithCharactersInString: @"abcdefghijklmnopqrstuvwxyz :=\n"]]; double v; return [sc scanDouble: &v] ? v : -1; }
double MixerVolume(void) { return FirstFloat(Run(@"/usr/sbin/mixer", @[ @"-s", @"vol" ])); }
void SetMixerVolume(double v) { Run(@"/usr/sbin/mixer", @[ [NSString stringWithFormat: @"vol=%.2f", v] ]); }
double Brightness(void) { NSString *o = Run(@"/usr/bin/backlight", @[]); if (!o) return -1; for (NSString *x in [o componentsSeparatedByCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]]) if ([x doubleValue] > 0) return [x doubleValue] / 100.0; return -1; }
void SetBrightness(double v) { Run(@"/usr/bin/backlight", @[ [NSString stringWithFormat: @"%d", (int)lround(v * 100)] ]); }
static int BatteryPct(void) { int v = -1; size_t n = sizeof v; if (sysctlbyname("hw.acpi.battery.life", &v, &n, NULL, 0)) return -1; return v; }
static BOOL Charging(void) { int v = 0; size_t n = sizeof v; if (sysctlbyname("hw.acpi.battery.state", &v, &n, NULL, 0)) return NO; return (v & 2) != 0; }
static NSString *GlobalPrefsPath(void) { return [NSHomeDirectory() stringByAppendingPathComponent: @"Library/Preferences/.GlobalPreferences.plist"]; }
BOOL DarkNow(void) { NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile: GlobalPrefsPath()]; id v = d[@"AppleInterfaceStyle"]; return !v || [v caseInsensitiveCompare: @"Dark"] == NSOrderedSame; }
void SetDark(BOOL dark)
{
	NSString *f = GlobalPrefsPath(); NSMutableDictionary *d = [[NSDictionary dictionaryWithContentsOfFile: f] mutableCopy] ?: [NSMutableDictionary dictionary]; if (dark) d[@"AppleInterfaceStyle"] = @"Dark"; else [d removeObjectForKey: @"AppleInterfaceStyle"];
	[[NSFileManager defaultManager] createDirectoryAtPath: [f stringByDeletingLastPathComponent] withIntermediateDirectories: YES attributes: nil error: NULL]; [d writeToFile: f atomically: YES];
}

@interface CCView : NSView { NSMutableDictionary *on; NSString *drag; double volume, brightness, kbd; NSArray *tiles; }
- (void)applyGlass;
@end
@implementation CCView
- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstMouse:(NSEvent *)e { return YES; }
- (instancetype)initWithFrame:(NSRect)f
{
	if (!(self = [super initWithFrame: f])) return nil;
	on = [NSMutableDictionary dictionaryWithDictionary: @{ @"wifi": @YES, @"bluetooth": @YES, @"dark": @(DarkNow()), @"nightshift": @NO, @"airdrop": @NO, @"stage": @NO, @"mirror": @NO, @"truetone": @NO, @"focus": @NO }];
	{ BOOL known; BOOL w = WifiPower(&known); if (known) on[@"wifi"] = @(w); }       /* without CoreWLAN/airportd the tile keeps its drawn state */
	volume = MixerVolume(); brightness = Brightness(); kbd = 1; if (volume < 0) volume = 0.5625; if (brightness < 0) brightness = 1;
	/* kind, id, column, row, columns, rows, symbol, title */
	tiles = @[ @[ @"circle", @"wifi", @0, @0, @1, @1, @"wifi", @"" ], @[ @"circle", @"bluetooth", @1, @0, @1, @1, @"", @"" ], @[ @"nowplaying", @"np", @2, @0, @2, @2, @"", @"" ],
		@[ @"circle", @"dark", @0, @1, @1, @1, @"circle.lefthalf.filled", @"" ], @[ @"circle", @"nightshift", @1, @1, @1, @1, @"sun.max", @"" ],
		@[ @"wide", @"airdrop", @0, @2, @2, @1, @"wifi.slash", @"AirDrop" ], @[ @"circle", @"stage", @2, @2, @1, @1, @"rectangle.3.group", @"" ], @[ @"circle", @"mirror", @3, @2, @1, @1, @"rectangle.on.rectangle", @"" ],
		@[ @"circle", @"truetone", @0, @3, @1, @1, @"sun.max", @"" ], @[ @"circle", @"display", @1, @3, @1, @1, @"display", @"" ], @[ @"wide", @"focus", @2, @3, @2, @1, @"moon.fill", @"Focus" ],
		@[ @"slider", @"sound", @0, @4, @4, @1, @"speaker.fill", @"Sound" ], @[ @"slider", @"bright", @1, @5, @2, @1, @"sun.max.fill", @"Display" ],
		@[ @"tall", @"saver", @0, @6, @2, @2, @"display", @"Start Screen Saver" ], @[ @"slider", @"kbdlight", @2, @6, @2, @1, @"light.max", @"Keyboard" ], @[ @"battery", @"battery", @2, @7, @2, @1, @"battery.100percent", @"" ] ];
	return self;
}
- (NSRect)rectOf:(NSArray *)t { int c = [t[4] intValue], r = [t[5] intValue]; return NSMakeRect(ColX([t[2] intValue]), RowY([t[3] doubleValue]), c * 64.0 + (c - 1) * 12, r * 64.0 + (r - 1) * 12); }
static NSRect EditRect(void) { return NSMakeRect(99, 624, 94, 24); }
- (int)radiusOf:(NSArray *)t { return [t[1] isEqual: @"sound"] ? 22 : 32; }
/* the fill of the tiles is the window server's glass: one slot per tile */
- (void)applyGlass
{
	id srv = GSCurrentServer();
	int win = (int)[[self window] windowNumber]; int slot = 1; if (![srv respondsToSelector: @selector(wsdGlassSlot:::::)]) return;
	for (NSArray *t in tiles) { if ([on[t[1]] boolValue] && [t[0] isEqual: @"circle"]) { [srv wsdGlassSlot: slot++ : win : [self rectOf: t] : 32 : 1]; continue; } [srv wsdGlassSlot: slot++ : win : [self rectOf: t] : [self radiusOf: t] : 1]; }
	[srv wsdGlassSlot: slot++ : win : EditRect() : 12 : 1];
}
static void Sym(NSString *n, NSRect r, double pt, NSColor *c) { [NSClassFromString(@"WsdFinderSupport") drawSymbol: n inRect: r size: pt weight: 5 color: c]; }
static void Bluetooth(NSPoint c, NSColor *col) { NSBezierPath *p = [NSBezierPath bezierPath]; [p setLineWidth: 2]; [p setLineCapStyle: NSRoundLineCapStyle]; [p setLineJoinStyle: NSRoundLineJoinStyle]; [p moveToPoint: NSMakePoint(c.x - 5, c.y - 5)]; [p lineToPoint: NSMakePoint(c.x + 5, c.y + 5)]; [p lineToPoint: NSMakePoint(c.x, c.y + 10)]; [p lineToPoint: NSMakePoint(c.x, c.y - 10)]; [p lineToPoint: NSMakePoint(c.x + 5, c.y - 5)]; [p lineToPoint: NSMakePoint(c.x - 5, c.y + 5)]; [col setStroke]; [p stroke]; }
- (void)drawRect:(NSRect)dirty
{
	NSColor *white = [NSColor colorWithCalibratedWhite: 1 alpha: 0.95], *dim = [NSColor colorWithCalibratedWhite: 1 alpha: 0.5], *blue = [NSColor colorWithCalibratedRed: 0 green: 0.48 blue: 1 alpha: 1], *ink = [NSColor colorWithCalibratedWhite: 0.05 alpha: 1];
	NSDictionary *tf = @{ NSFontAttributeName: [NSFont boldSystemFontOfSize: 13], NSForegroundColorAttributeName: white }, *sf = @{ NSFontAttributeName: [NSFont systemFontOfSize: 13], NSForegroundColorAttributeName: dim };
	for (NSArray *t in tiles) {
		NSRect r = [self rectOf: t]; NSString *k = t[0], *id_ = t[1]; BOOL isOn = [on[id_] boolValue];
		if ([k isEqual: @"circle"]) {
			if (isOn) { [[NSColor whiteColor] setFill]; [[NSBezierPath bezierPathWithOvalInRect: r] fill]; }
			NSColor *ic = isOn ? ([id_ isEqual: @"wifi"] || [id_ isEqual: @"bluetooth"] ? blue : ink) : white; NSRect ir = NSInsetRect(r, 16, 16);
			if ([id_ isEqual: @"bluetooth"]) Bluetooth(NSMakePoint(NSMidX(r), NSMidY(r)), ic); else Sym(t[6], ir, 24, ic);
		} else if ([k isEqual: @"wide"]) {
			NSRect ic = NSMakeRect(r.origin.x + 15, r.origin.y + 14, 36, 36); [[NSColor colorWithCalibratedWhite: 1 alpha: isOn ? 0.95 : 0.24] setFill]; [[NSBezierPath bezierPathWithOvalInRect: ic] fill]; Sym(t[6], NSInsetRect(ic, 8, 8), 18, isOn ? ink : white);
			if ([id_ isEqual: @"airdrop"]) { [@"AirDrop" drawAtPoint: NSMakePoint(r.origin.x + 57, r.origin.y + 13) withAttributes: tf]; [(isOn ? @"Contacts Only" : @"Off") drawAtPoint: NSMakePoint(r.origin.x + 57, r.origin.y + 32) withAttributes: sf]; }
			else { NSSize z = [t[7] sizeWithAttributes: tf]; [t[7] drawAtPoint: NSMakePoint(r.origin.x + 57, NSMidY(r) - z.height / 2) withAttributes: tf]; }
		} else if ([k isEqual: @"nowplaying"]) {
			for (int i = 0; i < 3; i++) Sym(@[ @"backward.fill", @"play.fill", @"forward.fill" ][i], NSMakeRect(r.origin.x + 15 + 40 * i, r.origin.y + 96, 30, 30), 22, dim);
		} else if ([k isEqual: @"slider"]) {
			double v = [id_ isEqual: @"sound"] ? volume : [id_ isEqual: @"bright"] ? brightness : kbd; BOOL snd = [id_ isEqual: @"sound"], br = [id_ isEqual: @"bright"];
			[t[7] drawAtPoint: NSMakePoint(r.origin.x + (snd ? 16 : 18), r.origin.y + 11) withAttributes: tf];
			NSRect tr = NSMakeRect(r.origin.x + (snd ? 34 : br ? 40 : 42), r.origin.y + 37, snd ? 181 : br ? 82 : 80, 4); [[NSColor colorWithCalibratedWhite: 1 alpha: 0.085] setFill]; [[NSBezierPath bezierPathWithRoundedRect: tr xRadius: 2 yRadius: 2] fill];
			NSRect fr = tr; fr.size.width *= v; [[NSColor whiteColor] setFill]; [[NSBezierPath bezierPathWithRoundedRect: fr xRadius: 2 yRadius: 2] fill];
			if (snd) { Sym(@"speaker.fill", NSMakeRect(r.origin.x + 16, r.origin.y + 35, 14, 14), 11, white); Sym(@"speaker.wave.3.fill", NSMakeRect(r.origin.x + 221, r.origin.y + 34, 21, 16), 12, white); NSRect ap = NSMakeRect(r.origin.x + 252, r.origin.y + 29, 26, 26); [[NSColor colorWithCalibratedWhite: 1 alpha: 0.24] setFill]; [[NSBezierPath bezierPathWithOvalInRect: ap] fill]; Sym(@"airplay.audio", NSInsetRect(ap, 5, 5), 12, white); }
			else if (br) Sym(@"sun.max.fill", NSMakeRect(r.origin.x + 17, r.origin.y + 35, 14, 14), 11, white);
			else Sym(@"light.max", NSMakeRect(r.origin.x + 17, r.origin.y + 38, 16, 9), 9, white);
		} else if ([k isEqual: @"tall"]) {
			Sym(t[6], NSMakeRect(r.origin.x + 16, r.origin.y + 16, 30, 26), 24, white); [t[7] drawInRect: NSMakeRect(r.origin.x + 16, NSMaxY(r) - 32, r.size.width - 12, 18) withAttributes: tf];
		} else if ([k isEqual: @"battery"]) {
			int b = BatteryPct(); NSString *s = b >= 0 ? [NSString stringWithFormat: @"%d%%", b] : @"100%"; NSSize z = [s sizeWithAttributes: tf]; double x0 = NSMidX(r) - (z.width + 30) / 2; Sym(Charging() ? @"battery.100percent.bolt" : @"battery.100percent", NSMakeRect(x0, NSMidY(r) - 10, 24, 20), 18, white); [s drawAtPoint: NSMakePoint(x0 + 30, NSMidY(r) - z.height / 2) withAttributes: tf];
		}
	}
	NSRect ec = EditRect(); NSSize ez = [@"Edit Controls" sizeWithAttributes: sf]; [@"Edit Controls" drawAtPoint: NSMakePoint(NSMidX(ec) - ez.width / 2, NSMidY(ec) - ez.height / 2) withAttributes: @{ NSFontAttributeName: [NSFont boldSystemFontOfSize: 11], NSForegroundColorAttributeName: white }];
}
- (void)set:(NSString *)id_ at:(NSPoint)p inRect:(NSRect)r
{
	BOOL snd = [id_ isEqual: @"sound"], br = [id_ isEqual: @"bright"]; double lo = r.origin.x + (snd ? 34 : br ? 40 : 42), w = snd ? 181 : br ? 82 : 80, v = MAX(0, MIN(1, (p.x - lo) / w));
	if (snd) { volume = v; SetMixerVolume(v); } else if (br) { brightness = v; SetBrightness(v); } else kbd = v;
	[self setNeedsDisplay: YES];
}
- (void)mouseDown:(NSEvent *)e
{
	NSPoint p = [self convertPoint: [e locationInWindow] fromView: nil]; drag = nil;
	for (NSArray *t in tiles) { NSRect r = [self rectOf: t]; if (!NSPointInRect(p, r)) continue; NSString *id_ = t[1];
		if ([t[0] isEqual: @"slider"]) { if (p.y < r.origin.y + 28 && p.x < r.origin.x + 70 && ([id_ isEqual: @"sound"] || [id_ isEqual: @"bright"])) { [[self window] orderOut: nil]; if ([id_ isEqual: @"sound"]) ToggleSoundPanel(); else ToggleDisplayPanel(); return; }       /* the titles are buttons that open the details */
			drag = id_; [self set: id_ at: p inRect: r]; return; }
		if ([t[0] isEqual: @"circle"] || [t[0] isEqual: @"wide"]) { BOOL v = ![on[id_] boolValue]; on[id_] = @(v); if ([id_ isEqual: @"dark"]) SetDark(v); if ([id_ isEqual: @"wifi"]) SetWifiPower(v); if ([id_ isEqual: @"focus"]) NCSetFocus(v); [self applyGlass]; [self setNeedsDisplay: YES]; }
		return; }
}
- (void)rightMouseDown:(NSEvent *)e { NSPoint p = [self convertPoint: [e locationInWindow] fromView: nil]; for (NSArray *t in tiles) if (([t[1] isEqual: @"wifi"] || [t[1] isEqual: @"bluetooth"]) && NSPointInRect(p, [self rectOf: t])) { [[self window] orderOut: nil]; if ([t[1] isEqual: @"wifi"]) ToggleWifiPanel(); else ToggleBluetoothPanel(); } }       /* the details of the Wi-Fi tile (AX: the custom action "show details") */
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
	if (!w) { double h = 660; w = [[CCWindow alloc] initWithContentRect: NSMakeRect(scr.size.width - 14 - PANEL_W, scr.size.height - 30 - h, PANEL_W, h) styleMask: NSBorderlessWindowMask backing: NSBackingStoreBuffered defer: NO];
		[w setOpaque: NO]; [w setBackgroundColor: [NSColor clearColor]]; [w setHasShadow: NO]; [w setLevel: 22]; [w setHidesOnDeactivate: NO]; [w setContentView: [[CCView alloc] initWithFrame: NSMakeRect(0, 0, PANEL_W, h)]]; }
	else [[w contentView] setNeedsDisplay: YES];
	[NSApp activateIgnoringOtherApps: YES]; [w makeKeyAndOrderFront: nil]; [(CCView *)[w contentView] applyGlass];
}
