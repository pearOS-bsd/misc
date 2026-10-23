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

@class WPWindow;
@interface WPWindow : NSWindow { @public BOOL relaying; } @end
@interface WPView : NSView { @public NSArray *nets; BOOL expanded, power, known; NSString *current; } @end
@implementation WPView
- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstMouse:(NSEvent *)e { return YES; }
/* the vertical layout: (y from the top of the panel) the section from 69, a current network row 32 + 5 to the line, the disclosure 6 under the line, the rows of the scan from 22 under it, "Other…" 22, the line of the footer 5 under the list, the footer 35 */
- (NSDictionary *)wpLayout
{
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
- (NSRect)rowRect:(NSUInteger)i { return NSMakeRect(14, [[self wpLayout][@"list"] doubleValue] + 32.0 * i, 280, 32); }
- (void)drawRect:(NSRect)dirty
{
	NSDictionary *head = @{ NSFontAttributeName: [NSFont boldSystemFontOfSize: 13], NSForegroundColorAttributeName: G(238, 1) }, *name = @{ NSFontAttributeName: [NSFont systemFontOfSize: 13], NSForegroundColorAttributeName: G(237, 1) }, *sec = @{ NSFontAttributeName: [NSFont boldSystemFontOfSize: 11], NSForegroundColorAttributeName: G(161, 1) }, *dim = @{ NSFontAttributeName: [NSFont systemFontOfSize: 13], NSForegroundColorAttributeName: G(133, 1) };
	[@"Wi‑Fi" drawAtPoint: NSMakePoint(14, 13) withAttributes: head];
	NSRect sw = [self switchRect]; [(power ? [NSColor colorWithCalibratedRed: 0 green: 0.478 blue: 1 alpha: 1] : G(255, 0.18)) setFill]; [[NSBezierPath bezierPathWithRoundedRect: sw xRadius: 12 yRadius: 12] fill];
	[[NSColor whiteColor] setFill]; [[NSBezierPath bezierPathWithOvalInRect: NSMakeRect(power ? NSMaxX(sw) - 22 : sw.origin.x + 2, sw.origin.y + 2, 20, 20)] fill];
	if (!power) { [@"Wi‑Fi Settings…" drawAtPoint: NSMakePoint(14, 69) withAttributes: name]; return; }       /* off: the list is gone (the height with the switch off is not measured) */
	NSDictionary *L = [self wpLayout]; NSRect disc = [self discRect]; NSMutableArray *rows = [NSMutableArray array]; for (NSDictionary *n in nets) if ([n[@"current"] boolValue]) [rows addObject: n];
	if ([rows count]) [self drawNet: rows[0] in: NSMakeRect(14, [L[@"rowY"] doubleValue], 280, 32) name: name current: YES];       /* the heading "Personal Hotspot" (11 pt, 161) belongs to a hotspot: not drawn, hotspots are not told apart here */
	[G(255, 0.1) setFill]; NSRectFill(NSMakeRect(14, [L[@"line"] doubleValue], 280, 1));
	[@"Other Networks" drawAtPoint: NSMakePoint(14, disc.origin.y + 3) withAttributes: dim]; Sym(expanded ? @"chevron.down" : @"chevron.right", NSMakeRect(NSMaxX(disc) - 14, disc.origin.y + 4, 10, 14), 11, G(133, 1));
	if (expanded) { NSUInteger k = 0; for (NSDictionary *n in nets) { if ([n[@"current"] boolValue]) continue; [self drawNet: n in: [self rowRect: k++] name: name current: NO]; } NSRect ob = [self rowRect: k]; [@"Other…" drawAtPoint: NSMakePoint(ob.origin.x + 38, ob.origin.y + 3) withAttributes: name]; }
	CGFloat by = [L[@"foot"] doubleValue]; [G(255, 0.1) setFill]; NSRectFill(NSMakeRect(14, by, 280, 1)); [@"Wi‑Fi Settings…" drawAtPoint: NSMakePoint(14, by + 11) withAttributes: name];
}
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
	if (NSPointInRect(p, [self switchRect])) { power = !power; SetWifiPower(power); [self relayout]; return; }
	if (power && NSPointInRect(p, [self discRect])) { expanded = !expanded; [self relayout]; return; }
	if (NSPointInRect(p, [self settingsRect])) { [[self window] orderOut: nil]; [[NSWorkspace sharedWorkspace] launchApplication: @"System Settings"]; }
}
- (void)relayout { WPWindow *w = (WPWindow *)[self window]; w->relaying = YES; [self performSelector: @selector(_relayDone) withObject: nil afterDelay: 0.3]; NSRect scr = [[NSScreen mainScreen] frame]; double h = [self panelHeight]; [w setFrame: NSMakeRect(scr.size.width - 8 - WW, scr.size.height - 36 - h, WW, h) display: YES]; [self setFrame: NSMakeRect(0, 0, WW, h)]; [self applyGlass]; [self setNeedsDisplay: YES]; }
- (void)_relayDone { ((WPWindow *)[self window])->relaying = NO; [[self window] makeKeyAndOrderFront: nil]; }
- (void)applyGlass { id srv = GSCurrentServer(); if ([srv respondsToSelector: @selector(wsdGlassSlot:::::)]) [srv wsdGlassSlot: 1 : (int)[[self window] windowNumber] : NSMakeRect(0, 0, WW, [self panelHeight]) : 16 : 5]; }
- (void)reload
{
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

void ToggleWifiPanel(void)
{
	static WPWindow *w; NSRect scr = [[NSScreen mainScreen] frame];
	if (w && [w isVisible]) { [w orderOut: nil]; return; }
	if (!w) { w = [[WPWindow alloc] initWithContentRect: NSMakeRect(scr.size.width - 8 - WW, scr.size.height - 36 - 193, WW, 193) styleMask: NSBorderlessWindowMask backing: NSBackingStoreBuffered defer: NO];
		[w setOpaque: NO]; [w setBackgroundColor: [NSColor clearColor]]; [w setHasShadow: NO]; [w setLevel: 22]; [w setHidesOnDeactivate: NO]; [w setContentView: [[WPView alloc] initWithFrame: NSMakeRect(0, 0, WW, 193)]]; }
	WPView *v = (WPView *)[w contentView]; [v reload]; [NSApp activateIgnoringOtherApps: YES]; [w makeKeyAndOrderFront: nil]; [v relayout];
}
