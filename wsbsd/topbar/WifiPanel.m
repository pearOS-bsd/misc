/* The Wi-Fi panel of the Control Center (details of the Wi-Fi tile). Measured on the Mac (AX of ControlCenter + pixels): 308 wide, its right edge 8 pt from the screen's, its top 36 pt under the screen's top (6 under the bar),
 * 193 high with the list collapsed; the header "Wi-Fi" 13 pt bold at (14, 13) and the switch 54 x 24 at (240, 9); the list from y 66: the heading of a section 11 pt (colour 161) at y 69, rows 280 x 32 at x 14 on a pitch of 32
 * (a grey circle with the Wi-Fi symbol, the name 13 pt (237), a lock at the right for a secured network), "Other Networks" a disclosure row 22 high (colour 133, chevron at the right), expanded: the rows of the scan and an "Other…" button 22 high;
 * "Wi-Fi Settings…" under a line at the bottom. The material is the context-menu glass (rim 131, fill ~55). Not measured: the radius of the corners (about 16 here), the look of a connected ordinary network, the signal icon
 * for each number of bars, the password sheet. The networks come from CoreWLAN (the repository's, through airportd) when it is there; TOPBAR_FAKE_WIFI=1 shows three sample networks. */
#import <AppKit/AppKit.h>
#import <objc/message.h>
#import <GNUstepGUI/GSDisplayServer.h>
#include <dlfcn.h>

#define WW 308.0
@interface NSObject (WPSymbols) + (BOOL)drawSymbol:(NSString *)name inRect:(NSRect)cell size:(CGFloat)pt weight:(int)weight color:(NSColor *)c; @end
@interface NSObject (WPGlass) - (void)wsdGlassSlot:(int)slot :(int)win :(NSRect)r :(int)radius :(int)mode; @end
id WifiInterface(void); BOOL WifiPower(BOOL *known); void SetWifiPower(BOOL on);
double MixerVolume(void); void SetMixerVolume(double v); double Brightness(void); void SetBrightness(double v); BOOL DarkNow(void); void SetDark(BOOL dark);

@class WPWindow;
@interface WPWindow : NSWindow { @public BOOL relaying; } @end
@interface WPView : NSView { @public NSArray *nets; BOOL expanded, power, known; NSString *current; int mode; double level; BOOL night, trueTone, dragging; } @end
@implementation WPView
- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstMouse:(NSEvent *)e { return YES; }
/* the vertical layout: (y from the top of the panel) the section from 69, a current network row 32 + 5 to the line, the disclosure 6 under the line, the rows of the scan from 22 under it, "Other…" 22, the line of the footer 5 under the list, the footer 35 */
- (NSDictionary *)wpLayout
{
	if (mode == 2) { double foot = 92 + [nets count] * 32 + 5; return @{ @"foot": @(foot), @"h": @(foot + 35), @"list": @92.0 }; }       /* Sound: header, the slider row, a line, "Output", the devices from y 92 */
	if (mode == 3) return @{ @"foot": @160.0, @"h": @188.0 };       /* Display: one display (188 high; the Mac with two displays: 242) */
	if (mode == 1) { double foot = 48 + [nets count] * 32 + 5; return @{ @"foot": @(foot), @"h": @(foot + 35), @"list": @48.0 }; }       /* Bluetooth: the devices from y 48 on a pitch of 32, the footer 5 under them (152 high with two devices) */
	BOOL cur = NO; NSUInteger others = 0; for (NSDictionary *n in nets) if ([n[@"current"] boolValue]) cur = YES; else others++;
	double y = 69, rowY = y; if (cur) y += 32 + 5; double line = y, disc = line + 6, listStart = disc + 22, end = disc + 22;
	if (expanded) end = listStart + others * 32 + 22; double foot = end + 5;
	return @{ @"cur": @(cur), @"rowY": @(rowY), @"line": @(line), @"disc": @(disc), @"list": @(listStart), @"foot": @(foot), @"h": @(foot + 35) };
}
- (CGFloat)panelHeight { return MIN(800, [[self wpLayout][@"h"] doubleValue]); }
static void Sym(NSString *n, NSRect r, double pt, NSColor *c) { [NSClassFromString(@"WsdFinderSupport") drawSymbol: n inRect: r size: pt weight: 5 color: c]; }
static NSColor *G(CGFloat w, CGFloat a) { return [NSColor colorWithCalibratedWhite: w / 255.0 alpha: a]; }
- (NSRect)switchRect { return NSMakeRect(240, 9, 54, 24); }
- (NSRect)discRect { return NSMakeRect(14, [[self wpLayout][@"disc"] doubleValue], 280, 22); }
- (NSRect)settingsRect { return NSMakeRect(0, [[self wpLayout][@"foot"] doubleValue], WW, 35); }
- (NSRect)rowRect:(NSUInteger)i { if (mode == 2) return NSMakeRect(5, [[self wpLayout][@"list"] doubleValue] + 32.0 * i, 298, 32); return NSMakeRect(14, [[self wpLayout][@"list"] doubleValue] + 32.0 * i, 280, 32); }
- (void)drawRect:(NSRect)dirty
{
	NSDictionary *head = @{ NSFontAttributeName: [NSFont boldSystemFontOfSize: 13], NSForegroundColorAttributeName: G(238, 1) }, *name = @{ NSFontAttributeName: [NSFont systemFontOfSize: 13], NSForegroundColorAttributeName: G(237, 1) }, *sec = @{ NSFontAttributeName: [NSFont boldSystemFontOfSize: 11], NSForegroundColorAttributeName: G(161, 1) }, *dim = @{ NSFontAttributeName: [NSFont systemFontOfSize: 13], NSForegroundColorAttributeName: G(133, 1) };
	if (mode != 3) [mode == 1 ? @"Bluetooth" : mode == 2 ? @"Sound" : @"Wi‑Fi" drawAtPoint: NSMakePoint(14, 13) withAttributes: head];
	if (mode >= 2) power = YES; else {}
	NSRect sw = [self switchRect]; if (mode < 2) { [(power ? [NSColor colorWithCalibratedRed: 0 green: 0.478 blue: 1 alpha: 1] : G(255, 0.18)) setFill]; [[NSBezierPath bezierPathWithRoundedRect: sw xRadius: 12 yRadius: 12] fill]; }
	if (mode < 2) { [[NSColor whiteColor] setFill]; [[NSBezierPath bezierPathWithOvalInRect: NSMakeRect(power ? NSMaxX(sw) - 22 : sw.origin.x + 2, sw.origin.y + 2, 20, 20)] fill]; }
	if (mode == 2 || mode == 3) { [self drawSlider: mode == 2 ? NSMakeRect(34, 38, 231, 16) : NSMakeRect(36, 43, 235, 16)]; }
	if (mode == 2) {
		Sym(@"speaker.fill", NSMakeRect(16, 39, 10, 14), 11, G(238, 1)); Sym(@"speaker.wave.3.fill", NSMakeRect(271, 38, 21, 16), 12, G(238, 1)); [G(255, 0.1) setFill]; NSRectFill(NSMakeRect(14, 64, 280, 1)); [@"Output" drawAtPoint: NSMakePoint(14, 73) withAttributes: sec];
		NSUInteger k = 0; for (NSDictionary *d in nets) { NSRect r = [self rowRect: k++]; BOOL on = [d[@"on"] boolValue]; NSRect ic = NSMakeRect(r.origin.x + 10, r.origin.y + 4, 24, 24); [(on ? [NSColor colorWithCalibratedRed: 0 green: 0.478 blue: 1 alpha: 1] : G(255, 0.25)) setFill]; [[NSBezierPath bezierPathWithOvalInRect: ic] fill]; Sym(on ? @"laptopcomputer" : @"speaker.wave.2.fill", NSInsetRect(ic, 5, 6), 12, [NSColor whiteColor]); [d[@"name"] drawAtPoint: NSMakePoint(r.origin.x + 43, NSMidY(r) - 8) withAttributes: name]; }
		CGFloat by = [[self wpLayout][@"foot"] doubleValue]; [G(255, 0.1) setFill]; NSRectFill(NSMakeRect(14, by, 280, 1)); [@"Sound Settings…" drawAtPoint: NSMakePoint(14, by + 9) withAttributes: name]; return;
	}
	if (mode == 3) {
		Sym(@"sun.min", NSMakeRect(15, 43, 16, 16), 12, G(200, 1)); Sym(@"sun.max.fill", NSMakeRect(276, 42, 17, 17), 13, G(238, 1)); [NSLocalizedString(@"Built-in Display", nil) drawAtPoint: NSMakePoint(14, 15) withAttributes: head];
		NSArray *tg = @[ @[ @"Dark Mode", @"circle.lefthalf.filled", @(DarkNow()) ], @[ @"Night Shift", @"sun.max", @(night) ], @[ @"True Tone", @"sun.max", @(trueTone) ] ]; double cx[3] = { 52, 154, 255 };
		for (int i = 0; i < 3; i++) { BOOL on = [tg[i][2] boolValue]; NSRect c = NSMakeRect(cx[i] - 20, 73, 40, 40); [(on ? [NSColor whiteColor] : G(255, 0.22)) setFill]; [[NSBezierPath bezierPathWithOvalInRect: c] fill]; Sym(tg[i][1], NSInsetRect(c, 9, 9), 18, on ? G(30, 1) : [NSColor whiteColor]);
			NSDictionary *sm = @{ NSFontAttributeName: [NSFont systemFontOfSize: 10], NSForegroundColorAttributeName: G(150, 1) }; NSSize z = [tg[i][0] sizeWithAttributes: sec]; [tg[i][0] drawAtPoint: NSMakePoint(cx[i] - z.width / 2, 121) withAttributes: @{ NSFontAttributeName: [NSFont boldSystemFontOfSize: 11], NSForegroundColorAttributeName: G(238, 1) }]; NSString *st = on ? @"On" : @"Off"; NSSize z2 = [st sizeWithAttributes: sm]; [st drawAtPoint: NSMakePoint(cx[i] - z2.width / 2, 136) withAttributes: sm]; }
		[G(255, 0.1) setFill]; NSRectFill(NSMakeRect(14, 160, 280, 1)); [@"Display Settings…" drawAtPoint: NSMakePoint(14, 171) withAttributes: name]; return;
	}
	if (mode == 1) { if (power) { NSUInteger k = 0; [G(255, 0.1) setFill]; NSRectFill(NSMakeRect(14, 42, 280, 1)); for (NSDictionary *d in nets) { NSRect r = [self rowRect: k++]; NSRect ic = NSMakeRect(r.origin.x + 5, r.origin.y + 5, 22, 22); [([d[@"on"] boolValue] ? [NSColor colorWithCalibratedRed: 0 green: 0.478 blue: 1 alpha: 1] : G(255, 0.25)) setFill]; [[NSBezierPath bezierPathWithOvalInRect: ic] fill]; [d[@"name"] drawAtPoint: NSMakePoint(r.origin.x + 38, NSMidY(r) - 8) withAttributes: name]; if (d[@"battery"]) { NSString *b = [NSString stringWithFormat: @"%@%%", d[@"battery"]]; NSSize z = [b sizeWithAttributes: dim]; [b drawAtPoint: NSMakePoint(NSMaxX(r) - z.width - 28, NSMidY(r) - 8) withAttributes: dim]; Sym(@"battery.50", NSMakeRect(NSMaxX(r) - 24, NSMidY(r) - 6, 24, 12), 12, G(133, 1)); } } CGFloat by = [[self wpLayout][@"foot"] doubleValue]; [G(255, 0.1) setFill]; NSRectFill(NSMakeRect(14, by, 280, 1)); [@"Bluetooth Settings…" drawAtPoint: NSMakePoint(14, by + 11) withAttributes: name]; } return; }
	if (!power) { [@"Wi‑Fi Settings…" drawAtPoint: NSMakePoint(14, 69) withAttributes: name]; return; }       /* off: the list is gone (the height with the switch off is not measured) */
	NSDictionary *L = [self wpLayout]; NSRect disc = [self discRect]; NSMutableArray *rows = [NSMutableArray array]; for (NSDictionary *n in nets) if ([n[@"current"] boolValue]) [rows addObject: n];
	if ([rows count]) [self drawNet: rows[0] in: NSMakeRect(14, [L[@"rowY"] doubleValue], 280, 32) name: name current: YES];       /* the heading "Personal Hotspot" (11 pt, 161) belongs to a hotspot: not drawn, hotspots are not told apart here */
	[G(255, 0.1) setFill]; NSRectFill(NSMakeRect(14, [L[@"line"] doubleValue], 280, 1));
	[@"Other Networks" drawAtPoint: NSMakePoint(14, disc.origin.y + 3) withAttributes: dim]; Sym(expanded ? @"chevron.down" : @"chevron.right", NSMakeRect(NSMaxX(disc) - 14, disc.origin.y + 4, 10, 14), 11, G(133, 1));
	if (expanded) { NSUInteger k = 0; for (NSDictionary *n in nets) { if ([n[@"current"] boolValue]) continue; [self drawNet: n in: [self rowRect: k++] name: name current: NO]; } NSRect ob = [self rowRect: k]; [@"Other…" drawAtPoint: NSMakePoint(ob.origin.x + 38, ob.origin.y + 3) withAttributes: name]; }
	CGFloat by = [L[@"foot"] doubleValue]; [G(255, 0.1) setFill]; NSRectFill(NSMakeRect(14, by, 280, 1)); [@"Wi‑Fi Settings…" drawAtPoint: NSMakePoint(14, by + 11) withAttributes: name];
}
- (void)drawSlider:(NSRect)r
{
	double v = level; NSRect tr = NSMakeRect(r.origin.x, r.origin.y + 6, r.size.width, 4); [G(255, 0.22) setFill]; [[NSBezierPath bezierPathWithRoundedRect: tr xRadius: 2 yRadius: 2] fill];
	double kx = r.origin.x + (r.size.width - 20) * v; NSRect fr = tr; fr.size.width = kx + 10 - tr.origin.x; [[NSColor whiteColor] setFill]; [[NSBezierPath bezierPathWithRoundedRect: fr xRadius: 2 yRadius: 2] fill];
	[[NSBezierPath bezierPathWithRoundedRect: NSMakeRect(kx, r.origin.y, 20, 16) xRadius: 8 yRadius: 8] fill];
}
- (NSRect)sliderRect { return mode == 2 ? NSMakeRect(34, 38, 231, 16) : NSMakeRect(36, 43, 235, 16); }
- (void)setLevelAt:(NSPoint)p { NSRect r = [self sliderRect]; level = MAX(0, MIN(1, (p.x - r.origin.x - 10) / (r.size.width - 20))); if (mode == 2) SetMixerVolume(level); else SetBrightness(level); [self setNeedsDisplay: YES]; }
- (void)mouseDragged:(NSEvent *)e { if (dragging) [self setLevelAt: [self convertPoint: [e locationInWindow] fromView: nil]]; }
- (void)mouseUp:(NSEvent *)e { dragging = NO; }
- (void)drawNet:(NSDictionary *)n in:(NSRect)r name:(NSDictionary *)na current:(BOOL)cur
{
	NSRect ic = NSMakeRect(r.origin.x + 2, r.origin.y + 2, 28, 28); [(cur ? [NSColor colorWithCalibratedRed: 0 green: 0.478 blue: 1 alpha: 1] : G(255, 0.2)) setFill]; [[NSBezierPath bezierPathWithOvalInRect: ic] fill];
	int bars = [n[@"bars"] intValue]; Sym(@"wifi", NSInsetRect(ic, 5, 6), 13, G(255, 0.35 + 0.2 * bars));
	[n[@"ssid"] drawAtPoint: NSMakePoint(r.origin.x + 38, NSMidY(r) - 8) withAttributes: na];
	if ([n[@"secure"] boolValue]) Sym(@"lock.fill", NSMakeRect(NSMaxX(r) - 20, NSMidY(r) - 7, 12, 14), 11, G(133, 1));
}
- (void)mouseDown:(NSEvent *)e
{
	NSPoint p = [self convertPoint: [e locationInWindow] fromView: nil];
	if (mode >= 2 && NSPointInRect(p, NSInsetRect([self sliderRect], -6, -6))) { dragging = YES; [self setLevelAt: p]; return; }
	if (mode == 2) { for (NSUInteger i = 0; i < [nets count]; i++) if (NSPointInRect(p, [self rowRect: i])) { NSMutableArray *m = [NSMutableArray array]; for (NSUInteger k = 0; k < [nets count]; k++) { NSMutableDictionary *d = [nets[k] mutableCopy]; d[@"on"] = @(k == i); [m addObject: d]; } nets = m; [self setNeedsDisplay: YES]; NSString *unit = nets[i][@"unit"]; if (unit) { NSTask *t = [NSTask launchedTaskWithLaunchPath: @"/sbin/sysctl" arguments: @[ [@"hw.snd.default_unit=" stringByAppendingString: unit] ]]; (void)t; } return; } if (NSPointInRect(p, [self settingsRect])) [[self window] orderOut: nil]; return; }
	if (mode == 3) { double cx[3] = { 52, 154, 255 }; for (int i = 0; i < 3; i++) if (NSPointInRect(p, NSMakeRect(cx[i] - 40, 73, 80, 80))) { if (i == 0) SetDark(!DarkNow()); else if (i == 1) night = !night; else trueTone = !trueTone; [self setNeedsDisplay: YES]; } return; }
	if (NSPointInRect(p, [self switchRect])) { power = !power; if (mode == 0) SetWifiPower(power); [self relayout]; return; }
	if (mode == 1) { if (NSPointInRect(p, [self settingsRect])) { [[self window] orderOut: nil]; [[NSWorkspace sharedWorkspace] launchApplication: @"System Settings"]; } return; }
	if (power && NSPointInRect(p, [self discRect])) { expanded = !expanded; [self relayout]; return; }
	if (NSPointInRect(p, [self settingsRect])) { [[self window] orderOut: nil]; [[NSWorkspace sharedWorkspace] launchApplication: @"System Settings"]; }
}
- (void)relayout { WPWindow *w = (WPWindow *)[self window]; w->relaying = YES; [self performSelector: @selector(_relayDone) withObject: nil afterDelay: 0.3]; NSRect scr = [[NSScreen mainScreen] frame]; double h = [self panelHeight]; [w setFrame: NSMakeRect(scr.size.width - 8 - WW, scr.size.height - 36 - h, WW, h) display: YES]; [self setFrame: NSMakeRect(0, 0, WW, h)]; [self applyGlass]; [self setNeedsDisplay: YES]; }
- (void)_relayDone { ((WPWindow *)[self window])->relaying = NO; [[self window] makeKeyAndOrderFront: nil]; }
- (void)applyGlass { id srv = GSCurrentServer(); if ([srv respondsToSelector: @selector(wsdGlassSlot:::::)]) [srv wsdGlassSlot: 1 : (int)[[self window] windowNumber] : NSMakeRect(0, 0, WW, [self panelHeight]) : 16 : 5]; }
- (void)reload
{
	if (mode == 3) { double b = Brightness(); level = b < 0 ? 1 : b; return; }
	if (mode == 2) {
		double v = MixerVolume(); level = v < 0 ? 0.5625 : v; NSMutableArray *a = [NSMutableArray array]; NSString *snd = [NSString stringWithContentsOfFile: @"/dev/sndstat" encoding: NSUTF8StringEncoding error: NULL]; NSInteger def = -1;
		for (NSString *l in [snd componentsSeparatedByString: @"\n"]) { if (![l hasPrefix: @"pcm"]) continue; NSRange c = [l rangeOfString: @":"], lt = [l rangeOfString: @"<"], gt = [l rangeOfString: @">"]; if (c.location == NSNotFound || lt.location == NSNotFound || gt.location == NSNotFound) continue;
			NSString *unit = [[l substringWithRange: NSMakeRange(3, c.location - 3)] description]; NSString *nm = [l substringWithRange: NSMakeRange(lt.location + 1, gt.location - lt.location - 1)]; BOOL isdef = [l rangeOfString: @"default"].location != NSNotFound; if (isdef) def = (NSInteger)[a count]; [a addObject: @{ @"name": nm, @"unit": unit, @"on": @(isdef) }]; }
		if (getenv("TOPBAR_FAKE_SOUND")) { a = [@[ @{ @"name": @"Built-in Speakers", @"on": @YES }, @{ @"name": @"HDMI Output", @"on": @NO }, @{ @"name": @"USB Audio", @"on": @NO } ] mutableCopy]; }
		nets = a; (void)def; return;
	}

	if (mode == 1) { power = YES; nets = getenv("TOPBAR_FAKE_BT") ? @[ @{ @"name": @"Keyboard", @"on": @YES, @"battery": @80 }, @{ @"name": @"Speaker", @"on": @NO } ] : @[]; return; }       /* no Bluetooth stack here: the devices of the Mac (hcsecd, hccontrol) are not read; the switch only changes the picture */
	known = NO; power = WifiPower(&known); NSMutableArray *a = [NSMutableArray array]; current = nil;
	if (getenv("TOPBAR_FAKE_WIFI")) { power = YES; known = YES; [a addObject: @{ @"ssid": @"Home", @"bars": @3, @"secure": @YES, @"current": @YES }]; [a addObject: @{ @"ssid": @"Neighbour 2.4G", @"bars": @2, @"secure": @YES }]; [a addObject: @{ @"ssid": @"Guest", @"bars": @1, @"secure": @NO }]; }
	else if (known) {
		id i = WifiInterface(); NSString *cur = ((id (*)(id, SEL))objc_msgSend)(i, @selector(ssid)); NSSet *res = nil; @try { res = ((id (*)(id, SEL))objc_msgSend)(i, @selector(cachedScanResults)); } @catch (NSException *x) {}
		for (id n in res) { NSString *s = ((id (*)(id, SEL))objc_msgSend)(n, @selector(ssid)); if (![s length]) continue; long long rssi = ((long long (*)(id, SEL))objc_msgSend)(n, @selector(rssiValue)); BOOL open = ((BOOL (*)(id, SEL, long long))objc_msgSend)(n, @selector(supportsSecurity:), 0);
			[a addObject: @{ @"ssid": s, @"bars": @(rssi > -60 ? 3 : rssi > -70 ? 2 : rssi > -80 ? 1 : 0), @"secure": @(!open), @"current": @([s isEqual: cur]) }]; }
		[a sortUsingComparator: ^NSComparisonResult(NSDictionary *x, NSDictionary *y) { return [x[@"ssid"] caseInsensitiveCompare: y[@"ssid"]]; }];
	}
	nets = a;
}
@end

@implementation WPWindow
- (BOOL)canBecomeKeyWindow { return YES; }
- (void)resignKeyWindow { [super resignKeyWindow]; if (!relaying) [self orderOut: nil]; }
- (void)keyDown:(NSEvent *)e { if ([[e characters] isEqual: @"\x1b"]) [self orderOut: nil]; else [super keyDown: e]; }
@end

static void TogglePanel(int mode)
{
	static WPWindow *w[4]; NSRect scr = [[NSScreen mainScreen] frame];
	if (w[mode] && [w[mode] isVisible]) { [w[mode] orderOut: nil]; return; }
	if (!w[mode]) { w[mode] = [[WPWindow alloc] initWithContentRect: NSMakeRect(scr.size.width - 8 - WW, scr.size.height - 36 - 193, WW, 193) styleMask: NSBorderlessWindowMask backing: NSBackingStoreBuffered defer: NO];
		[w[mode] setOpaque: NO]; [w[mode] setBackgroundColor: [NSColor clearColor]]; [w[mode] setHasShadow: NO]; [w[mode] setLevel: 22]; [w[mode] setHidesOnDeactivate: NO]; WPView *nv = [[WPView alloc] initWithFrame: NSMakeRect(0, 0, WW, 193)]; nv->mode = mode; [w[mode] setContentView: nv]; }
	WPView *v = (WPView *)[w[mode] contentView]; [v reload]; [NSApp activateIgnoringOtherApps: YES]; [w[mode] makeKeyAndOrderFront: nil]; [v relayout];
}
void ToggleWifiPanel(void) { TogglePanel(0); }
void ToggleBluetoothPanel(void) { TogglePanel(1); }
void ToggleSoundPanel(void) { TogglePanel(2); }
void ToggleDisplayPanel(void) { TogglePanel(3); }
