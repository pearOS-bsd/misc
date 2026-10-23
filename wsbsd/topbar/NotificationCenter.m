/* Notification Center: the UI of the notification system (the Mac's NotificationCenter.app). An application never draws a banner: it hands a request to usernoted (XPC), which tells this process, registered as the "shell",
 * to present it (WSUserNotificationEvents). Measured on the Mac (AX of NotificationCenter while a banner was shown + pixels): banners and cards 344 wide with the right edge 16 from the screen's, the first 46 under the
 * top (16 under the bar), 6 apart; the icon 32 x 32 at (14, centred), the text from x 58: title 13 pt semibold at y 12 (16 high), the subtitle 13 pt semibold 17 under it, the body 13 pt regular, lines of 16, its width 265;
 * height = 12 + the lines + 13 (74 for a title and two lines of body, 75 for title, subtitle and a line); the material is glass with corners of about 22 (here glass material 5 with the lens). Banners disappear after
 * 5 s (the Mac: the same) and slide in from the right (the curve is not measured). The panel of the clock shows the delivered list in the same cards and the "Edit Widgets" pill (measured earlier; the widgets are not here).
 * Not measured: grouping by application, the close button on hover, "Clear", the actions of a notification, the look of an alert (stays until dismissed), the dismiss animation. */
#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSDisplayServer.h>
#import <wsbsd/WSUserNotifications.h>
#import <wsbsd/NSXPCConnection.h>
#import <Foundation/NSXPCConnection.h>
#include <time.h>

#define NW 344.0
#define CARD_GAP 6.0
@interface NSObject (NCGlass) - (void)wsdGlassSlot:(int)slot :(int)win :(NSRect)r :(int)radius :(int)mode; @end

static NSMutableParagraphStyle *Para(void) { NSMutableParagraphStyle *p = [[NSMutableParagraphStyle alloc] init]; [p setLineBreakMode: NSLineBreakByWordWrapping]; [p setMinimumLineHeight: 16]; [p setMaximumLineHeight: 16]; return p; }
static NSDictionary *TitleAttrs(void) { return @{ NSFontAttributeName: [NSFont boldSystemFontOfSize: 13], NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite: 0.92 alpha: 1], NSParagraphStyleAttributeName: Para() }; }
static NSDictionary *BodyAttrs(void) { return @{ NSFontAttributeName: [NSFont systemFontOfSize: 13], NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite: 0.86 alpha: 1], NSParagraphStyleAttributeName: Para() }; }
static double BodyHeight(NSString *s) { if (![s length]) return 0; NSRect r = [s boundingRectWithSize: NSMakeSize(265, 1000) options: NSStringDrawingUsesLineFragmentOrigin attributes: BodyAttrs()]; return MIN(ceil(r.size.height / 16.0), 4) * 16; }
double NCCardHeight(NSDictionary *n)
{
	double h = 12 + 13, t = [n[@"title"] length] ? 17 : 0, s = [n[@"subtitle"] length] ? 17 : 0, b = BodyHeight(n[@"body"]);
	if (!t && !s && !b) t = 17; return h + t + s + b - (b ? 1 : 0) + (b ? 0 : -0);
}
/* one card (banner or list item) in r, flipped coordinates */
void NCDrawCard(NSRect r, NSDictionary *n)
{
	NSImage *icon = nil; NSString *p = n[@"appPath"]; if ([p length]) icon = [[NSWorkspace sharedWorkspace] iconForFile: p];
	if (icon) [icon drawInRect: NSMakeRect(r.origin.x + 14, r.origin.y + (r.size.height - 32) / 2, 32, 32) fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1];
	double y = r.origin.y + 12, x = r.origin.x + 58; NSString *t = n[@"title"], *s = n[@"subtitle"], *b = n[@"body"];
	if (![t length] && ![s length] && ![b length]) t = n[@"appName"];
	if ([t length]) { [t drawInRect: NSMakeRect(x, y, 265, 16) withAttributes: TitleAttrs()]; y += 17; }
	if ([s length]) { [s drawInRect: NSMakeRect(x, y, 265, 16) withAttributes: TitleAttrs()]; y += 17; }
	if ([b length]) [b drawInRect: NSMakeRect(x, y, 265, BodyHeight(b)) withAttributes: BodyAttrs()];
}

/* ---- the connection to usernoted ---- */
@interface NCLink : NSObject <WSUserNotificationEvents> { NSXPCConnection *conn; @public id<WSUserNotificationRequests> daemon; } + (NCLink *)shared; - (void)connect; @end
void NCShowBanner(NSDictionary *n); void NCListChanged(void);
@implementation NCLink
+ (NCLink *)shared { static NCLink *l; if (!l) { l = [NCLink new]; [l connect]; [NSTimer scheduledTimerWithTimeInterval: 3 target: l selector: @selector(ensure) userInfo: nil repeats: YES]; } return l; }
- (void)ensure { if (!conn) [self connect]; }
- (void)connect
{
	conn = [[NSXPCConnection alloc] initWithMachServiceName: WSUserNotificationServiceName options: 0]; [conn setRemoteObjectInterface: [NSXPCInterface interfaceWithProtocol: @protocol(WSUserNotificationRequests)]];
	[conn setExportedInterface: [NSXPCInterface interfaceWithProtocol: @protocol(WSUserNotificationEvents)]]; [conn setExportedObject: self];
	__weak NCLink *me = self; void (^lost)(void) = ^{ NCLink *s = me; if (s) { s->conn = nil; s->daemon = nil; } }; [conn setInvalidationHandler: lost]; [conn setInterruptionHandler: lost]; [conn resume];
	daemon = [conn remoteObjectProxyWithErrorHandler: ^(NSError *e) { lost(); }];
	[daemon registerClientWithInfo: @{ @"bundle": @"com.apple.notificationcenterui", @"name": @"Notification Center", @"role": @"shell" } reply: ^(BOOL ok) {}];
}
- (void)presentBanner:(NSDictionary *)n { dispatch_async(dispatch_get_main_queue(), ^{ NCShowBanner(n); }); }
- (void)listChanged { dispatch_async(dispatch_get_main_queue(), ^{ NCListChanged(); }); }
@end
void NCStart(void) { [NCLink shared]; }
void NCSetFocus(BOOL on) { [[NCLink shared]->daemon setFocus: on]; }

/* ---- banners ---- */
@interface NCBanner : NSWindow { @public NSDictionary *note; NSTimer *timer; } @end
@interface NCCardView : NSView { @public NSDictionary *note; } @end
@implementation NCCardView
- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstMouse:(NSEvent *)e { return YES; }
- (void)drawRect:(NSRect)d { NCDrawCard([self bounds], note); }
- (void)mouseDown:(NSEvent *)e { NSWindow *w = [self window]; if ([w isKindOfClass: [NCBanner class]]) { NSDictionary *n = note; [(id)w performSelector: @selector(dismissNow)]; [[NCLink shared]->daemon activateNotification: n[@"uid"] action: nil]; } }
@end
static NSMutableArray *gBanners;
static void Restack(BOOL animate);
@implementation NCBanner
- (BOOL)canBecomeKeyWindow { return NO; }
- (void)dismissNow { [timer invalidate]; timer = nil; [gBanners removeObject: self]; [self orderOut: nil]; Restack(YES); }
@end
static void Restack(BOOL animate)
{
	NSRect scr = [[NSScreen mainScreen] frame]; double top = scr.size.height - 46;      // the screen's top is 46 above the first banner
	for (NCBanner *b in gBanners) { NSRect f = [b frame]; f.origin.x = scr.size.width - 16 - NW; f.origin.y = top - f.size.height; [b setFrame: f display: YES]; top -= f.size.height + CARD_GAP; }
}
void NCShowBanner(NSDictionary *n)
{
	if (!gBanners) gBanners = [NSMutableArray array]; NSRect scr = [[NSScreen mainScreen] frame]; double h = NCCardHeight(n);
	NCBanner *w = [[NCBanner alloc] initWithContentRect: NSMakeRect(scr.size.width, scr.size.height - 46 - h, NW, h) styleMask: NSBorderlessWindowMask backing: NSBackingStoreBuffered defer: NO]; w->note = n;
	[w setOpaque: NO]; [w setBackgroundColor: [NSColor clearColor]]; [w setHasShadow: NO]; [w setLevel: 23]; [w setHidesOnDeactivate: NO]; [w setCanHide: NO];
	NCCardView *v = [[NCCardView alloc] initWithFrame: NSMakeRect(0, 0, NW, h)]; v->note = n; [w setContentView: v];
	[gBanners insertObject: w atIndex: 0]; [w orderFrontRegardless];
	id srv = GSCurrentServer(); if ([srv respondsToSelector: @selector(wsdGlassSlot:::::)]) [srv wsdGlassSlot: 1 : (int)[w windowNumber] : NSMakeRect(0, 0, NW, h) : 22 : 5];
	// slides in from the right
	NSRect fin = [w frame]; fin.origin.x = scr.size.width - 16 - NW; Restack(NO); NSRect start = fin; start.origin.x = scr.size.width; [w setFrame: start display: YES];
	__block int step = 0; NSTimer *t = [NSTimer scheduledTimerWithTimeInterval: 1.0 / 60 repeats: YES block: ^(NSTimer *x) { step++; double k = MIN(1.0, step / 18.0), e = 1 - pow(1 - k, 3); NSRect f = start; f.origin.x = start.origin.x + (fin.origin.x - start.origin.x) * e; [w setFrame: f display: YES]; if (k >= 1) [x invalidate]; }]; (void)t;
	w->timer = [NSTimer scheduledTimerWithTimeInterval: 5 target: w selector: @selector(dismissNow) userInfo: nil repeats: NO];
}

/* ---- the panel of the clock ---- */
@interface NCView : NSView { @public NSArray *list; } @end
static NCView *gPanel;
@implementation NCView
- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstMouse:(NSEvent *)e { return YES; }
static void Card(NSRect r) { NSBezierPath *p = [NSBezierPath bezierPathWithRoundedRect: r xRadius: 20 yRadius: 20]; [[NSColor colorWithCalibratedRed: 0.11 green: 0.11 blue: 0.12 alpha: 0.9] setFill]; [p fill]; [[NSColor colorWithCalibratedWhite: 1 alpha: 0.14] setStroke]; [[NSBezierPath bezierPathWithRoundedRect: NSInsetRect(r, 0.5, 0.5) xRadius: 20 yRadius: 20] stroke]; }
- (double)contentHeight { double y = 16; for (NSDictionary *n in list) y += NCCardHeight(n) + CARD_GAP; return y; }
- (NSRect)cardRect:(NSUInteger)i { double y = 16; for (NSUInteger k = 0; k < i; k++) y += NCCardHeight(list[k]) + CARD_GAP; return NSMakeRect(0, y, NW, NCCardHeight(list[i])); }
- (void)drawRect:(NSRect)dirty
{
	for (NSUInteger i = 0; i < [list count]; i++) { NSRect r = [self cardRect: i]; Card(r); NCDrawCard(r, list[i]); }
	NSDictionary *small = @{ NSFontAttributeName: [NSFont systemFontOfSize: 11], NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite: 1 alpha: 0.95] };
	NSRect ec = NSMakeRect(NW - 94 - 15, [self contentHeight] + 7, 94, 23); NSBezierPath *p = [NSBezierPath bezierPathWithRoundedRect: ec xRadius: 11.5 yRadius: 11.5]; [[NSColor colorWithCalibratedRed: 0.11 green: 0.11 blue: 0.12 alpha: 0.9] setFill]; [p fill];
	[[NSColor colorWithCalibratedWhite: 1 alpha: 0.14] setStroke]; [[NSBezierPath bezierPathWithRoundedRect: NSInsetRect(ec, 0.5, 0.5) xRadius: 11.5 yRadius: 11.5] stroke];
	NSSize z = [@"Edit Widgets" sizeWithAttributes: small]; [@"Edit Widgets" drawAtPoint: NSMakePoint(NSMidX(ec) - z.width / 2, NSMidY(ec) - z.height / 2) withAttributes: small];
}
- (void)mouseDown:(NSEvent *)e { NSPoint p = [self convertPoint: [e locationInWindow] fromView: nil]; for (NSUInteger i = 0; i < [list count]; i++) if (NSPointInRect(p, [self cardRect: i])) { [[NCLink shared]->daemon activateNotification: list[i][@"uid"] action: nil]; [[self window] orderOut: nil]; return; } }
@end
@interface NCWindow : NSWindow @end
@implementation NCWindow
- (BOOL)canBecomeKeyWindow { return YES; }
- (void)resignKeyWindow { [super resignKeyWindow]; [self orderOut: nil]; }
- (void)keyDown:(NSEvent *)e { if ([[e characters] isEqual: @"\x1b"]) [self orderOut: nil]; else [super keyDown: e]; }
@end
static NCWindow *gPanelWin;
static void Layout(void)
{
	NSRect scr = [[NSScreen mainScreen] frame]; double h = [gPanel contentHeight] + 7 + 23 + 16; NSRect f = NSMakeRect(scr.size.width - 16 - NW, scr.size.height - 30 - h, NW, h);
	[gPanelWin setFrame: f display: YES]; [gPanel setFrame: NSMakeRect(0, 0, NW, h)]; [gPanel setNeedsDisplay: YES];
	/* the cards of the panel are dark fills of their own: glass slots 6 apart would melt into one shape */
}
void NCListChanged(void)
{
	if (!gPanelWin || ![gPanelWin isVisible]) return;
	[[NCLink shared]->daemon allDeliveredWithReply: ^(NSArray *a) { dispatch_async(dispatch_get_main_queue(), ^{ gPanel->list = a ?: @[]; Layout(); }); }];
}
void ToggleNotificationCenter(void)
{
	NSRect scr = [[NSScreen mainScreen] frame];
	if (gPanelWin && [gPanelWin isVisible]) { [gPanelWin orderOut: nil]; return; }
	if (!gPanelWin) { gPanelWin = [[NCWindow alloc] initWithContentRect: NSMakeRect(scr.size.width - 16 - NW, scr.size.height - 30 - 60, NW, 60) styleMask: NSBorderlessWindowMask backing: NSBackingStoreBuffered defer: NO];
		[gPanelWin setOpaque: NO]; [gPanelWin setBackgroundColor: [NSColor clearColor]]; [gPanelWin setHasShadow: NO]; [gPanelWin setLevel: 22]; [gPanelWin setHidesOnDeactivate: NO]; gPanel = [[NCView alloc] initWithFrame: NSMakeRect(0, 0, NW, 60)]; gPanel->list = @[]; [gPanelWin setContentView: gPanel]; }
	Layout(); [NSApp activateIgnoringOtherApps: YES]; [gPanelWin makeKeyAndOrderFront: nil];
	[[NCLink shared]->daemon allDeliveredWithReply: ^(NSArray *a) { dispatch_async(dispatch_get_main_queue(), ^{ gPanel->list = a ?: @[]; Layout(); }); }];
}
