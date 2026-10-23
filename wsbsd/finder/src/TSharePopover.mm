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
