/* The Share popover of the toolbar, laid out from the accessibility tree of the real Finder's (266 x 342 with the contacts row; its hosting view 240 wide inset 13): from the origin of the popover the thumbnail
 * 30 x 42 at (24, 24), the name 14 pt bold at (62, 28) and the kind and size ("PDF Document · 142 KB") 12 pt dimmed at (62, 46), a separator, the services as rows of 216 x 22 from x 25 on a pitch of 22,
 * a separator, "Copy" and "Edit Extensions…". The popover opens above the button, centred on it. Here: the header, AirDrop (the window of AirDrop) and Copy; the services of the Mac (Mail, Messages,
 * Notes, Freeform) are not installed, the contacts row needs AirDrop, "Edit Extensions…" needs System Settings. Not measured: the corner radius, the arrow of the popover (left out), the icons of the rows. */
#import "TFinderViews.h"
#import <GNUstepGUI/GSDisplayServer.h>
@interface NSObject (SPGlass) - (void)wsdMenuGlass:(int)win :(int)w :(int)h; @end

@interface TShareView : NSView { @public NSArray *paths; NSInteger hot; id owner; }
@end
@implementation TShareView
- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstMouse:(NSEvent *)e { return YES; }
- (NSArray *)rows { return @[ @[ @"AirDrop", @(79) ], @[ @"Copy", @(124) ] ]; }
- (void)drawRect:(NSRect)dirty
{
	NSString *p = [paths firstObject]; NSFileManager *fm = [NSFileManager defaultManager]; NSDictionary *at = [fm attributesOfItemAtPath: p error: NULL]; BOOL dir = [at[NSFileType] isEqual: NSFileTypeDirectory];
	NSString *name = [paths count] > 1 ? [NSString stringWithFormat: @"%lu items", (unsigned long)[paths count]] : [[p lastPathComponent] stringByDeletingPathExtension]; if (dir || ![[p pathExtension] length]) name = [p lastPathComponent] ?: name;
	TFDrawIcon(p, NSMakeRect(24, 24, 30, 30)); NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init]; [ps setLineBreakMode: NSLineBreakByTruncatingTail];
	[name drawInRect: NSMakeRect(62, 28, 178, 18) withAttributes: @{ NSFontAttributeName: [NSFont boldSystemFontOfSize: 14], NSForegroundColorAttributeName: TFRGB(255, 255, 255), NSParagraphStyleAttributeName: ps }];
	NSString *sub = [paths count] > 1 ? @"" : [NSString stringWithFormat: @"%@ · %@", TFKindString(p, dir), TFSizeString([at[NSFileSize] unsignedLongLongValue])]; [sub drawInRect: NSMakeRect(62, 46, 178, 16) withAttributes: @{ NSFontAttributeName: [NSFont systemFontOfSize: 12], NSForegroundColorAttributeName: TFRGBA(255, 255, 255, 0.55), NSParagraphStyleAttributeName: ps }];
	[TFRGBA(255, 255, 255, 0.14) setFill]; NSRectFill(NSMakeRect(18, 72, 230, 1)); NSRectFill(NSMakeRect(18, 107, 230, 1));
	NSArray *rows = [self rows]; for (NSUInteger i = 0; i < [rows count]; i++) { double y = [rows[i][1] doubleValue] + 33 - 79 + (i == 0 ? 0 : 0); NSRect r = NSMakeRect(25, i == 0 ? 80 : 115, 216, 22); (void)y; if (hot == (NSInteger)i) { [TFRGBA(255, 255, 255, 0.14) setFill]; [[NSBezierPath bezierPathWithRoundedRect: r xRadius: 6 yRadius: 6] fill]; } [rows[i][0] drawAtPoint: NSMakePoint(r.origin.x + 8, r.origin.y + 3) withAttributes: @{ NSFontAttributeName: [NSFont systemFontOfSize: 13], NSForegroundColorAttributeName: TFRGB(255, 255, 255) }]; }
}
- (NSInteger)rowAt:(NSPoint)p { for (NSInteger i = 0; i < 2; i++) { NSRect r = NSMakeRect(25, i == 0 ? 80 : 115, 216, 22); if (NSPointInRect(p, r)) return i; } return -1; }
- (void)mouseMoved:(NSEvent *)e { NSInteger h = [self rowAt: [self convertPoint: [e locationInWindow] fromView: nil]]; if (h != hot) { hot = h; [self setNeedsDisplay: YES]; } }
- (void)updateTrackingAreas { [super updateTrackingAreas]; [self addTrackingRect: [self bounds] owner: self userData: NULL assumeInside: NO]; }
- (void)mouseDown:(NSEvent *)e
{
	NSInteger r = [self rowAt: [self convertPoint: [e locationInWindow] fromView: nil]]; if (r < 0) return; NSWindow *w = [self window];
	if (r == 0) [owner performSelector: @selector(cmdGoToAirDrop:) withObject: nil];
	else { NSPasteboard *pb = [NSPasteboard generalPasteboard]; [pb declareTypes: @[ NSFilenamesPboardType ] owner: nil]; [pb setPropertyList: paths forType: NSFilenamesPboardType]; }
	[w orderOut: nil];
}
@end
@interface TShareWindow : NSWindow @end
@implementation TShareWindow
- (BOOL)canBecomeKeyWindow { return YES; }
- (void)resignKeyWindow { [super resignKeyWindow]; [self orderOut: nil]; }
- (void)keyDown:(NSEvent *)e { if ([[e characters] isEqual: @"\x1b"]) [self orderOut: nil]; else [super keyDown: e]; }
@end

/* the popover for paths, centred on the point (screen coordinates) above it */
void TFShowSharePopover(NSArray *paths, NSPoint anchor, id owner)
{
	static TShareWindow *w; double W = 266, H = 160; NSRect f = NSMakeRect(anchor.x - W / 2, anchor.y + 6, W, H);
	if (!w) { w = [[TShareWindow alloc] initWithContentRect: f styleMask: NSWindowStyleMaskBorderless backing: NSBackingStoreBuffered defer: NO]; [w setOpaque: NO]; [w setBackgroundColor: [NSColor clearColor]]; [w setHasShadow: NO]; [w setLevel: 101]; [w setAcceptsMouseMovedEvents: YES]; [w setContentView: [[TShareView alloc] initWithFrame: NSMakeRect(0, 0, W, H)]]; }
	else [w setFrame: f display: YES];
	TShareView *v = (TShareView *)[w contentView]; v->paths = paths; v->owner = owner; v->hot = -1; [v setNeedsDisplay: YES]; [NSApp activateIgnoringOtherApps: YES]; [w makeKeyAndOrderFront: nil];
	id srv = GSCurrentServer(); if ([srv respondsToSelector: @selector(wsdMenuGlass:::)]) [srv wsdMenuGlass: (int)[w windowNumber] : (int)W : (int)H];
}

/* The Add Tags popover (the tag button of the toolbar and "Tags…"), from the accessibility tree of the real one: 252 x 251, "Assign tags to “name”" 13 pt at (26, 17), the tag field 218 x 27 at (17, 37),
 * the list of the tags in rows of 226 x 19 from (13, 80) (an 18 pt picture at x 28, the name at x 45). Here a click on a row assigns or removes the tag; the assigned ones are written in the field.
 * Not measured: the look of the field and of the assigned state, the corner radius and the arrow. */
@interface TTagsView : NSView { @public NSArray *paths; id owner; NSArray *names; NSInteger hot; }
@end
@implementation TTagsView
- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstMouse:(NSEvent *)e { return YES; }
- (BOOL)_all:(NSString *)n { BOOL all = [paths count] > 0; for (NSString *p in paths) if (![TFTagsOf(p) containsObject: n]) all = NO; return all; }
- (void)drawRect:(NSRect)dirty
{
	NSString *what = [paths count] == 1 ? [NSString stringWithFormat: @"Assign tags to “%@”", [paths[0] lastPathComponent]] : [NSString stringWithFormat: @"Assign tags to %lu items", (unsigned long)[paths count]]; NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init]; [ps setLineBreakMode: NSLineBreakByTruncatingMiddle];
	[what drawInRect: NSMakeRect(26, 17, 200, 16) withAttributes: @{ NSFontAttributeName: [NSFont systemFontOfSize: 13], NSForegroundColorAttributeName: TFRGBA(255, 255, 255, 0.55), NSParagraphStyleAttributeName: ps }];
	NSRect fr = NSMakeRect(17, 37, 218, 27); [TFRGBA(255, 255, 255, 0.08) setFill]; [[NSBezierPath bezierPathWithRoundedRect: fr xRadius: 6 yRadius: 6] fill];
	NSMutableArray *have = [NSMutableArray array]; for (NSString *n in names) if ([self _all: n]) [have addObject: n]; [[have componentsJoinedByString: @", "] drawInRect: NSMakeRect(25, 42, 202, 18) withAttributes: @{ NSFontAttributeName: [NSFont systemFontOfSize: 13], NSForegroundColorAttributeName: TFRGB(255, 255, 255), NSParagraphStyleAttributeName: ps }];
	Class sp = NSClassFromString(@"WsdFinderSupport");
	for (NSUInteger i = 0; i < [names count]; i++) { NSRect r = NSMakeRect(13, 80 + 19 * i, 226, 19); if (hot == (NSInteger)i) { [TFRGB(0, 122, 255) setFill]; [[NSBezierPath bezierPathWithRoundedRect: r xRadius: 5 yRadius: 5] fill]; }
		[[sp colorOfTag: names[i]] setFill]; [[NSBezierPath bezierPathWithOvalInRect: NSMakeRect(28 + 2.5, r.origin.y + 3, 13, 13)] fill]; [names[i] drawAtPoint: NSMakePoint(45, r.origin.y + 1) withAttributes: @{ NSFontAttributeName: [NSFont systemFontOfSize: 13], NSForegroundColorAttributeName: TFRGB(255, 255, 255) }];
		if ([self _all: names[i]]) TFSymbol(@"checkmark", NSMakeRect(212, r.origin.y + 1, 16, 17), 11, TFRGB(255, 255, 255)); }
}
- (NSInteger)rowAt:(NSPoint)p { if (p.x < 13 || p.x >= 239 || p.y < 80) return -1; NSInteger i = (NSInteger)((p.y - 80) / 19); return i < (NSInteger)[names count] ? i : -1; }
- (void)mouseMoved:(NSEvent *)e { NSInteger h = [self rowAt: [self convertPoint: [e locationInWindow] fromView: nil]]; if (h != hot) { hot = h; [self setNeedsDisplay: YES]; } }
- (void)updateTrackingAreas { [super updateTrackingAreas]; [self addTrackingRect: [self bounds] owner: self userData: NULL assumeInside: NO]; }
- (void)mouseDown:(NSEvent *)e
{
	NSInteger r = [self rowAt: [self convertPoint: [e locationInWindow] fromView: nil]]; if (r < 0) return; NSString *n = names[r]; BOOL all = [self _all: n];
	for (NSString *p in paths) { NSMutableArray *cur = [TFTagsOf(p) mutableCopy]; if (all) [cur removeObject: n]; else if (![cur containsObject: n]) [cur addObject: n]; TFSetTags(cur, p); }
	[owner performSelector: @selector(reload)]; [self setNeedsDisplay: YES];
}
@end
void TFShowTagsPopover(NSArray *paths, NSPoint anchor, id owner)
{
	static TShareWindow *w; double W = 252, H = 251; NSRect f = NSMakeRect(anchor.x - W / 2, anchor.y - H, W, H);
	if (!w) { w = [[TShareWindow alloc] initWithContentRect: f styleMask: NSWindowStyleMaskBorderless backing: NSBackingStoreBuffered defer: NO]; [w setOpaque: NO]; [w setBackgroundColor: [NSColor clearColor]]; [w setHasShadow: NO]; [w setLevel: 101]; [w setAcceptsMouseMovedEvents: YES]; [w setContentView: [[TTagsView alloc] initWithFrame: NSMakeRect(0, 0, W, H)]]; }
	else [w setFrame: f display: YES];
	TTagsView *v = (TTagsView *)[w contentView]; v->paths = paths; v->owner = owner; v->names = [NSClassFromString(@"WsdFinderSupport") tagNames]; v->hot = -1; [v setNeedsDisplay: YES]; [NSApp activateIgnoringOtherApps: YES]; [w makeKeyAndOrderFront: nil];
	id srv = GSCurrentServer(); if ([srv respondsToSelector: @selector(wsdMenuGlass:::)]) [srv wsdMenuGlass: (int)[w windowNumber] : (int)W : (int)H];
}
