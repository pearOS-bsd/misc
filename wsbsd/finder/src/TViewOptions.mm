/* View Options (View > Show View Options, cmd-J) for the icon view: icon size, grid spacing, text size, item info, icon preview and the arrangement; the values are kept in the folder's .DS_Store (icvp). */
#import "TFinderViews.h"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static void FillR(NSRect r, CGFloat rad, NSColor *c) { [c setFill]; [[NSBezierPath bezierPathWithRoundedRect: r xRadius: rad yRadius: rad] fill]; }
static NSDictionary *F(CGFloat sz, BOOL bold, NSColor *c) { return @{ NSFontAttributeName: bold ? [NSFont boldSystemFontOfSize: sz] : [NSFont systemFontOfSize: sz], NSForegroundColorAttributeName: c }; }
@interface NSObject (TVDrag) - (BOOL)isDragPoint:(NSPoint)p; @end
@interface TViewOptionsView : NSView { @public TIconView *view; NSString *folder; void (^changed)(void); NSMutableArray *_hits; }
@end
@implementation TViewOptionsView
- (BOOL)isFlipped { return YES; } - (BOOL)acceptsFirstMouse:(NSEvent *)e { return YES; } - (BOOL)isDragPoint:(NSPoint)p { return p.y < 44; }
- (void)_slider:(NSRect)r value:(double)v
{
	[(TFDark() ? TFRGBA(255, 255, 255, 0.22) : TFRGBA(0, 0, 0, 0.2)) setFill]; FillR(NSMakeRect(r.origin.x, NSMidY(r) - 1.5, r.size.width, 3), 1.5, TFDark() ? TFRGBA(255, 255, 255, 0.22) : TFRGBA(0, 0, 0, 0.2));
	CGFloat kx = r.origin.x + 7 + v * (r.size.width - 14); FillR(NSMakeRect(kx - 7, NSMidY(r) - 7, 14, 14), 7, TFDark() ? TFRGB(215, 215, 215) : TFRGB(255, 255, 255));
}
- (void)drawRect:(NSRect)rr
{
	NSRect b = [self bounds]; [TF_SIDEBAR setFill]; NSRectFill(b); NSColor *t = TF_TEXT, *d = TF_DIM; NSString *title = folder; NSSize ts = [title sizeWithAttributes: F(13, YES, t)]; [title drawAtPoint: NSMakePoint(b.size.width / 2 - ts.width / 2, 19) withAttributes: F(13, YES, t)];
	_hits = [NSMutableArray array]; __block CGFloat y = 66; CGFloat x = 24, w = b.size.width - 48;
	void (^label)(NSString *) = ^(NSString *s) { [s drawAtPoint: NSMakePoint(x, y) withAttributes: F(13, NO, t)]; };
	label([NSString stringWithFormat: @"Icon size: %d × %d", (int)view->_isz, (int)view->_isz]); y += 24; NSRect s1 = NSMakeRect(x, y, w, 20); [self _slider: s1 value: (view->_isz - 16) / 112.0]; [_hits addObject: @{ @"r": [NSValue valueWithRect: s1], @"k": @"icon" }]; y += 34;
	label(@"Grid spacing"); y += 24; NSRect s2 = NSMakeRect(x, y, w, 20); [self _slider: s2 value: (view->_grid - 36) / 64.0]; [_hits addObject: @{ @"r": [NSValue valueWithRect: s2], @"k": @"grid" }]; y += 38;
	label(@"Text size:"); NSRect p1 = NSMakeRect(x + 90, y - 4, 70, 24); FillR(p1, 12, TF_PILL); [[NSString stringWithFormat: @"%d pt", (int)view->_textSize] drawAtPoint: NSMakePoint(p1.origin.x + 12, y) withAttributes: F(13, NO, t)]; TFSymbol(@"chevron.up.chevron.down", NSMakeRect(NSMaxX(p1) - 24, p1.origin.y, 16, 24), 9, d); [_hits addObject: @{ @"r": [NSValue valueWithRect: p1], @"k": @"text" }]; y += 40;
	for (NSArray *c in @[ @[ @"Show item info", @"info", @(view->_showInfo) ], @[ @"Show icon preview", @"preview", @(view->_showPreview) ] ]) { NSRect cb = NSMakeRect(x, y, 16, 16); FillR(cb, 4, [c[2] boolValue] ? TF_ACCENT : (TFDark() ? TFRGBA(255, 255, 255, 0.14) : TFRGBA(0, 0, 0, 0.12))); if ([c[2] boolValue]) TFSymbol(@"checkmark", cb, 10, TFRGB(255, 255, 255)); [c[0] drawAtPoint: NSMakePoint(x + 24, y) withAttributes: F(13, NO, t)]; [_hits addObject: @{ @"r": [NSValue valueWithRect: NSMakeRect(x, y - 3, 240, 22)], @"k": c[1] }]; y += 28; }
	y += 8; label(@"Sort by:"); NSRect p2 = NSMakeRect(x + 90, y - 4, 150, 24); FillR(p2, 12, TF_PILL); NSDictionary *names = @{ @"": @"None", @"name": @"Name", @"kind": @"Kind", @"modified": @"Date Modified", @"created": @"Date Created", @"size": @"Size", @"tags": @"Tags" }; [names[view->_arrange ?: @""] ?: @"None" drawAtPoint: NSMakePoint(p2.origin.x + 12, y) withAttributes: F(13, NO, t)]; TFSymbol(@"chevron.up.chevron.down", NSMakeRect(NSMaxX(p2) - 24, p2.origin.y, 16, 24), 9, d); [_hits addObject: @{ @"r": [NSValue valueWithRect: p2], @"k": @"sort" }]; y += 48;
	NSRect ub = NSMakeRect(x, y, w, 30); FillR(ub, 15, TF_PILL); NSSize us = [@"Use as Defaults" sizeWithAttributes: F(13, NO, t)]; [@"Use as Defaults" drawAtPoint: NSMakePoint(NSMidX(ub) - us.width / 2, NSMidY(ub) - us.height / 2) withAttributes: F(13, NO, t)]; [_hits addObject: @{ @"r": [NSValue valueWithRect: ub], @"k": @"defaults" }];
}
- (void)_apply { [view applyOptions]; if (changed) changed(); [self setNeedsDisplay: YES]; }
- (void)mouseDown:(NSEvent *)e
{
	NSPoint p = [self convertPoint: [e locationInWindow] fromView: nil];
	for (NSDictionary *h in _hits) { NSRect r = [h[@"r"] rectValue]; if (!NSPointInRect(p, NSInsetRect(r, -4, -4))) continue; NSString *k = h[@"k"];
		if ([k isEqual: @"icon"] || [k isEqual: @"grid"]) { NSEvent *ev = e; do { NSPoint q = [self convertPoint: [ev locationInWindow] fromView: nil]; double v = MAX(0, MIN(1, (q.x - r.origin.x - 7) / (r.size.width - 14))); if ([k isEqual: @"icon"]) view->_isz = 16 + round(v * 112); else view->_grid = 36 + round(v * 64); [self _apply]; if ([ev type] == NSLeftMouseUp) break; ev = [[self window] nextEventMatchingMask: NSLeftMouseDraggedMask | NSLeftMouseUpMask untilDate: [NSDate distantFuture] inMode: NSEventTrackingRunLoopMode dequeue: YES]; } while (1); return; }
		if ([k isEqual: @"info"]) { view->_showInfo = !view->_showInfo; [self _apply]; return; } if ([k isEqual: @"preview"]) { view->_showPreview = !view->_showPreview; [self _apply]; return; }
		if ([k isEqual: @"text"]) { NSMenu *m = [[NSMenu alloc] initWithTitle: @""]; for (int sz = 10; sz <= 16; sz++) { NSMenuItem *it = [m addItemWithTitle: [NSString stringWithFormat: @"%d pt", sz] action: @selector(_pickText:) keyEquivalent: @""]; [it setTarget: self]; [it setTag: sz]; [it setState: sz == (int)view->_textSize ? NSOnState : NSOffState]; } TFPopupMenu(self, NSMakePoint(r.origin.x, NSMaxY(r) + 2), m); return; }
		if ([k isEqual: @"sort"]) { NSMenu *m = [[NSMenu alloc] initWithTitle: @""]; NSArray *o = @[ @[ @"None", @"" ], @[ @"Name", @"name" ], @[ @"Kind", @"kind" ], @[ @"Date Modified", @"modified" ], @[ @"Date Created", @"created" ], @[ @"Size", @"size" ], @[ @"Tags", @"tags" ] ]; for (NSArray *a in o) { NSMenuItem *it = [m addItemWithTitle: a[0] action: @selector(_pickSort:) keyEquivalent: @""]; [it setTarget: self]; [it setRepresentedObject: a[1]]; [it setState: [a[1] isEqual: view->_arrange ?: @""] ? NSOnState : NSOffState]; } TFPopupMenu(self, NSMakePoint(r.origin.x, NSMaxY(r) + 2), m); return; }
		if ([k isEqual: @"defaults"]) { TFSetPref(@"IconViewDefaults", @{ @"iconSize": @(view->_isz), @"gridSpacing": @(view->_grid), @"textSize": @(view->_textSize), @"showItemInfo": @(view->_showInfo), @"showIconPreview": @(view->_showPreview) }); return; }
	}
}
- (void)_pickText:(NSMenuItem *)it { view->_textSize = [it tag]; [self _apply]; }
- (void)_pickSort:(NSMenuItem *)it { NSString *k = [it representedObject]; [view arrangeBy: [k length] ? k : nil]; if (changed) changed(); [self setNeedsDisplay: YES]; }
@end

void TFOpenViewOptions(TIconView *view, NSString *folderName, void (^changed)(void))
{
	if (view->desktop) { TFOpenDesktopViewOptions(view, changed); return; }
	static NSWindow *w; if (w && [w isVisible]) { [w close]; return; }
	w = [[TFinderWindow alloc] initWithContentRect: NSMakeRect(960, 300, 290, 400) styleMask: NSWindowStyleMaskBorderless backing: NSBackingStoreBuffered defer: NO]; [w setReleasedWhenClosed: NO]; [w setOpaque: NO]; [w setBackgroundColor: [NSColor clearColor]]; [w setMinSize: NSMakeSize(290, 400)]; [w setMaxSize: NSMakeSize(290, 400)];
	TViewOptionsView *v = [[TViewOptionsView alloc] initWithFrame: NSMakeRect(0, 0, 290, 400)]; v->view = view; v->folder = folderName; v->changed = changed; [w setContentView: v]; TWindowTrim *trim = [[TWindowTrim alloc] initWithFrame: [v bounds]]; [trim setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable]; [v addSubview: trim];
	[w makeKeyAndOrderFront: nil]; [NSClassFromString(@"WsdFinderSupport") roundWindow: w radius: 16];
}
