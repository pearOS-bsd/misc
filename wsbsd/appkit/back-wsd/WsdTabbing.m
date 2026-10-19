/* Window tabbing (macOS 10.12+): NSWindowTabGroup, the NSWindow methods that join, merge, split and select tabs, and the tab bar the decoration view draws under the title bar of a tabbed window
 * (WsdMacTheme.m calls WsdTabBarHeight / WsdDrawTabBar / WsdTabBarMouseDown). The windows of a group share one frame: only the selected window is on screen, selecting another puts it where the
 * old one was. A tab is closed with its x (the window closes), the + asks the selected window for a new tab (newWindowForTab:, as macOS's + does). Compiled without ARC. */
#import <AppKit/AppKit.h>
#import <objc/runtime.h>

static char kGroup, kMode, kIdent, kBarForced;
enum { TabbingAutomatic = 0, TabbingPreferred, TabbingDisallowed };
#define BAR_H 28.0

@interface NSWindowTabGroup : NSObject { @public NSMutableArray *_windows; NSWindow *_selected; BOOL _overview; BOOL _forceBar; } @end

static void RefreshDecoration(NSWindow *w) { [[[w contentView] superview] setNeedsDisplay: YES]; }
static void Relayout(NSWindow *w)                                  /* the content view gives the tab bar its room */
{
	NSView *fv = [[w contentView] superview];
	if ([fv respondsToSelector: @selector(wsdApplyTabInset)]) [fv performSelector: @selector(wsdApplyTabInset)];
	[fv setNeedsDisplay: YES];
}

@implementation NSWindowTabGroup
- (id)init { if ((self = [super init])) _windows = [[NSMutableArray alloc] init]; return self; }
- (void)dealloc { [_windows release]; [super dealloc]; }
- (NSArray *)windows { return [NSArray arrayWithArray: _windows]; }
- (NSWindow *)selectedWindow { return _selected; }
- (BOOL)isOverviewVisible { return _overview; }
- (BOOL)isTabBarVisible { return [_windows count] > 1 || _forceBar; }
- (void)wsdRefresh { for (NSWindow *w in _windows) { Relayout(w); } }
- (void)setSelectedWindow:(NSWindow *)w
{
	if (![_windows containsObject: w] || w == _selected) return;
	NSWindow *old = _selected; _selected = w;
	if (old) { [w setFrame: [old frame] display: NO]; [old orderOut: nil]; [w makeKeyAndOrderFront: nil]; }       /* the old one first: ordering out the key window makes AppKit promote another window, the new one must come last */
	else [w makeKeyAndOrderFront: nil];
	[self wsdRefresh];
}
- (void)insertWindow:(NSWindow *)w atIndex:(NSInteger)i
{
	if ([_windows containsObject: w]) return;
	NSWindowTabGroup *g = objc_getAssociatedObject(w, &kGroup); if (g) [g removeWindow: w];
	if (i > (NSInteger)[_windows count]) i = [_windows count];
	[_windows insertObject: w atIndex: i]; objc_setAssociatedObject(w, &kGroup, self, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(wsdClosed:) name: NSWindowWillCloseNotification object: w];
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(wsdTitle:) name: NSWindowDidResignKeyNotification object: w];
	if (!_selected) _selected = w; else { [w setFrame: [_selected frame] display: NO]; [w orderOut: nil]; }
	[self wsdRefresh];
}
- (void)addWindow:(NSWindow *)w { [self insertWindow: w atIndex: [_windows count]]; }
- (void)removeWindow:(NSWindow *)w
{
	NSUInteger i = [_windows indexOfObject: w]; if (i == NSNotFound) return;
	[self retain]; [w retain];
	[[NSNotificationCenter defaultCenter] removeObserver: self name: NSWindowWillCloseNotification object: w];
	[[NSNotificationCenter defaultCenter] removeObserver: self name: NSWindowDidResignKeyNotification object: w];
	[_windows removeObjectAtIndex: i]; objc_setAssociatedObject(w, &kGroup, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	if (w == _selected) { _selected = [_windows count] ? [_windows objectAtIndex: MIN(i, [_windows count] - 1)] : nil; if (_selected) { [_selected setFrame: [w frame] display: NO]; [_selected makeKeyAndOrderFront: nil]; } }
	Relayout(w); [self wsdRefresh];
	if ([_windows count] == 1) { NSWindow *last = [_windows objectAtIndex: 0]; objc_setAssociatedObject(last, &kGroup, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC); [_windows removeAllObjects]; _selected = nil; Relayout(last); }
	[w release]; [self release];
}
- (void)wsdClosed:(NSNotification *)n { NSWindow *w = [n object]; [self removeWindow: w]; }
- (void)wsdTitle:(NSNotification *)n { [self wsdRefresh]; }
@end

@implementation NSWindow (WsdTabbing)
+ (BOOL)allowsAutomaticWindowTabbing { NSNumber *n = objc_getAssociatedObject([NSWindow class], &kBarForced); return n ? [n boolValue] : YES; }
+ (void)setAllowsAutomaticWindowTabbing:(BOOL)b { objc_setAssociatedObject([NSWindow class], &kBarForced, [NSNumber numberWithBool: b], OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
+ (NSInteger)userTabbingPreference { return 1; }
- (NSInteger)tabbingMode { return [objc_getAssociatedObject(self, &kMode) integerValue]; }
- (void)setTabbingMode:(NSInteger)m { objc_setAssociatedObject(self, &kMode, [NSNumber numberWithInteger: m], OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (NSString *)tabbingIdentifier { return objc_getAssociatedObject(self, &kIdent) ?: [self title]; }
- (void)setTabbingIdentifier:(NSString *)s { objc_setAssociatedObject(self, &kIdent, s, OBJC_ASSOCIATION_COPY_NONATOMIC); }
- (NSWindowTabGroup *)tabGroup { return objc_getAssociatedObject(self, &kGroup); }
- (NSArray *)tabbedWindows { NSWindowTabGroup *g = [self tabGroup]; return g && [g->_windows count] > 1 ? [g windows] : nil; }
- (void)addTabbedWindow:(NSWindow *)w ordered:(NSWindowOrderingMode)o
{
	if (w == self || [w tabbingMode] == TabbingDisallowed) return;
	NSWindowTabGroup *g = [self tabGroup]; if (!g) { g = [[[NSWindowTabGroup alloc] init] autorelease]; [g addWindow: self]; }
	NSInteger i = [g->_windows indexOfObject: self]; [g insertWindow: w atIndex: o == NSWindowBelow ? i : i + 1];
	[g setSelectedWindow: w];
}
- (void)mergeAllWindows:(id)s
{
	for (NSWindow *w in [NSApp windows]) if (w != self && [w isVisible] && ([w styleMask] & NSTitledWindowMask) && ![w isKindOfClass: [NSPanel class]] && [w tabbingMode] != TabbingDisallowed && ![w attachedSheet] && ![self isEqual: w]) [self addTabbedWindow: w ordered: NSWindowAbove];
	[[self tabGroup] setSelectedWindow: self];
}
- (void)moveTabToNewWindow:(id)s
{
	NSWindowTabGroup *g = [self tabGroup]; if (!g) return; NSRect f = [self frame];
	[g removeWindow: self]; [self setFrame: NSOffsetRect(f, 24, -24) display: YES]; [self makeKeyAndOrderFront: nil]; Relayout(self);
}
- (void)selectNextTab:(id)s { NSWindowTabGroup *g = [self tabGroup]; if (!g) return; NSUInteger i = [g->_windows indexOfObject: g->_selected]; [g setSelectedWindow: [g->_windows objectAtIndex: (i + 1) % [g->_windows count]]]; }
- (void)selectPreviousTab:(id)s { NSWindowTabGroup *g = [self tabGroup]; if (!g) return; NSUInteger i = [g->_windows indexOfObject: g->_selected], n = [g->_windows count]; [g setSelectedWindow: [g->_windows objectAtIndex: (i + n - 1) % n]]; }
- (void)toggleTabBar:(id)s { NSWindowTabGroup *g = [self tabGroup]; if (g) { g->_forceBar = ![g isTabBarVisible] || g->_forceBar ? !g->_forceBar : YES; [g wsdRefresh]; } }
- (void)toggleTabOverview:(id)s { NSWindowTabGroup *g = [self tabGroup]; if (g) g->_overview = !g->_overview; }
- (BOOL)isSheet { return [self sheetParent] != nil; }
@end

/* the tab bar of the decoration view */
CGFloat WsdTabBarHeight(NSWindow *w) { NSWindowTabGroup *g = [w tabGroup]; return g && [g isTabBarVisible] ? BAR_H : 0; }
static NSRect TabRect(NSRect bar, NSUInteger i, NSUInteger n) { CGFloat plus = 30, w = (bar.size.width - plus) / n; if (w > 220) w = 220; return NSMakeRect(bar.origin.x + i * w, bar.origin.y, w, bar.size.height); }
void WsdDrawTabBar(NSWindow *win, NSRect bar, BOOL dark, BOOL key)
{
	NSWindowTabGroup *g = [win tabGroup]; if (!g) return; NSUInteger n = [g->_windows count]; if (!n) return;
	NSMutableParagraphStyle *ps = [[[NSMutableParagraphStyle alloc] init] autorelease]; [ps setLineBreakMode: NSLineBreakByTruncatingTail]; [ps setAlignment: NSCenterTextAlignment];
	for (NSUInteger i = 0; i < n; i++)
	{
		NSWindow *w = [g->_windows objectAtIndex: i]; NSRect r = TabRect(bar, i, n); BOOL sel = w == g->_selected;
		if (sel) { [(dark ? [NSColor colorWithCalibratedWhite: 1 alpha: 0.10] : [NSColor colorWithCalibratedWhite: 0 alpha: 0.07]) set]; [[NSBezierPath bezierPathWithRoundedRect: NSInsetRect(r, 4, 3) xRadius: 7 yRadius: 7] fill]; }
		else if (i > 0 && i - 1 < n && [g->_windows objectAtIndex: i - 1] != g->_selected) { [(dark ? [NSColor colorWithCalibratedWhite: 1 alpha: 0.12] : [NSColor colorWithCalibratedWhite: 0 alpha: 0.12]) set]; NSRectFill(NSMakeRect(r.origin.x, r.origin.y + 8, 1, r.size.height - 16)); }
		NSColor *tc = sel ? (dark ? [NSColor colorWithCalibratedWhite: 1 alpha: key ? 0.88 : 0.5] : [NSColor colorWithCalibratedWhite: 0 alpha: key ? 0.85 : 0.45]) : (dark ? [NSColor colorWithCalibratedWhite: 1 alpha: 0.55] : [NSColor colorWithCalibratedWhite: 0 alpha: 0.55]);
		NSDictionary *at = [NSDictionary dictionaryWithObjectsAndKeys: [NSFont systemFontOfSize: 12], NSFontAttributeName, tc, NSForegroundColorAttributeName, ps, NSParagraphStyleAttributeName, nil];
		[[w title] ?: @"" drawInRect: NSMakeRect(r.origin.x + 22, r.origin.y + 6, r.size.width - 44, 16) withAttributes: at];
		if (sel) { NSBezierPath *x = [NSBezierPath bezierPath]; CGFloat cx = r.origin.x + 14, cy = NSMidY(r); [x moveToPoint: NSMakePoint(cx - 3, cy - 3)]; [x lineToPoint: NSMakePoint(cx + 3, cy + 3)]; [x moveToPoint: NSMakePoint(cx - 3, cy + 3)]; [x lineToPoint: NSMakePoint(cx + 3, cy - 3)]; [x setLineWidth: 1.2]; [tc set]; [x stroke]; }
	}
	NSRect pr = NSMakeRect(NSMaxX(bar) - 30, bar.origin.y, 30, bar.size.height); NSBezierPath *p = [NSBezierPath bezierPath]; CGFloat cx = NSMidX(pr), cy = NSMidY(pr);
	[p moveToPoint: NSMakePoint(cx - 5, cy)]; [p lineToPoint: NSMakePoint(cx + 5, cy)]; [p moveToPoint: NSMakePoint(cx, cy - 5)]; [p lineToPoint: NSMakePoint(cx, cy + 5)]; [p setLineWidth: 1.3];
	[(dark ? [NSColor colorWithCalibratedWhite: 1 alpha: 0.6] : [NSColor colorWithCalibratedWhite: 0 alpha: 0.6]) set]; [p stroke];
}
BOOL WsdTabBarMouseDown(NSWindow *win, NSRect bar, NSPoint pt, NSEvent *e)
{
	NSWindowTabGroup *g = [win tabGroup]; if (!g || !NSPointInRect(pt, bar)) return NO; NSUInteger n = [g->_windows count];
	if (pt.x > NSMaxX(bar) - 30) { [NSApp sendAction: @selector(newWindowForTab:) to: nil from: g->_selected]; return YES; }
	for (NSUInteger i = 0; i < n; i++)
	{
		NSRect r = TabRect(bar, i, n); if (!NSPointInRect(pt, r)) continue; NSWindow *w = [g->_windows objectAtIndex: i];
		if (w == g->_selected && pt.x < r.origin.x + 26) { [w performClose: nil]; return YES; }
		[g setSelectedWindow: w]; return YES;
	}
	return YES;
}
