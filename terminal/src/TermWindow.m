#import "TermWindow.h"
#include <math.h>

#define TABBAR_H 28.0
#define FINDBAR_H 36.0

static NSMutableArray *all;


/* ---- the panes of one tab (Split Pane): terminals side by side with a divider; the active one gets the keyboard ---- */
@interface TermPanes : NSView { NSMutableArray *panes; NSUInteger active; }
- (instancetype)initWithTerm:(TermView *)t;
- (TermView *)activePane; - (NSArray *)panes;
- (void)addPane:(TermView *)t; - (void)removePane:(TermView *)t; - (void)setActivePane:(TermView *)t;
@end
@implementation TermPanes
- (instancetype)initWithTerm:(TermView *)t { self = [super initWithFrame:NSMakeRect(0, 0, 100, 100)]; panes = [[NSMutableArray alloc] initWithObjects:t, nil]; [self addSubview:t]; return self; }
- (void)dealloc { [panes release]; [super dealloc]; }
- (BOOL)isFlipped { return YES; }
- (TermView *)activePane { return [panes objectAtIndex:active < [panes count] ? active : 0]; }
- (NSArray *)panes { return panes; }
- (void)layoutPanes
{
	NSUInteger n = [panes count]; CGFloat w = ([self bounds].size.width - (n - 1)) / n, h = [self bounds].size.height;
	for (NSUInteger i = 0; i < n; i++) [(TermView *)[panes objectAtIndex:i] setFrame:NSMakeRect(floor(i * (w + 1)), 0, floor(w), h)];
	[self setNeedsDisplay:YES];
}
- (void)setFrameSize:(NSSize)s { [super setFrameSize:s]; [self layoutPanes]; }
- (void)addPane:(TermView *)t { [panes addObject:t]; [self addSubview:t]; active = [panes count] - 1; [self layoutPanes]; }
- (void)removePane:(TermView *)t { NSUInteger i = [panes indexOfObject:t]; if (i == NSNotFound) return; [t removeFromSuperview]; [panes removeObjectAtIndex:i]; if (active >= [panes count]) active = [panes count] - 1; [self layoutPanes]; }
- (void)setActivePane:(TermView *)t { NSUInteger i = [panes indexOfObject:t]; if (i != NSNotFound) { active = i; [self setNeedsDisplay:YES]; } }
- (void)drawRect:(NSRect)r { [[NSColor colorWithCalibratedWhite:0.35 alpha:1] set]; NSRectFill([self bounds]); }       /* the divider shows between the panes */
@end

/* ---- the tab bar ---- */
@interface TermTabBar : NSView { TermWindowController *owner; NSInteger hoverTab; }
- (instancetype)initWithOwner:(TermWindowController *)o;
@end
@implementation TermTabBar
- (instancetype)initWithOwner:(TermWindowController *)o { self = [super initWithFrame:NSMakeRect(0, 0, 100, TABBAR_H)]; owner = o; hoverTab = -1; return self; }
- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstMouse:(NSEvent *)e { return YES; }
- (NSRect)tabRect:(NSUInteger)i
{
	NSUInteger n = [[owner tabs] count]; CGFloat w = ([self bounds].size.width - 32) / (n ? n : 1); if (w > 240) w = 240;
	return NSMakeRect(i * w, 0, w, TABBAR_H);
}
- (void)drawRect:(NSRect)r
{
	TermProfile *p = [[owner term] profile]; CGFloat lum = [[p->background colorUsingColorSpaceName:NSCalibratedRGBColorSpace] brightnessComponent]; BOOL dark = lum < 0.5;
	NSColor *barBg = dark ? [NSColor colorWithCalibratedWhite:0.16 alpha:1] : [NSColor colorWithCalibratedWhite:0.87 alpha:1]; [barBg set]; NSRectFill([self bounds]);
	NSColor *fg = dark ? [NSColor colorWithCalibratedWhite:0.92 alpha:1] : [NSColor colorWithCalibratedWhite:0.15 alpha:1];
	NSArray *tabs = [owner tabs];
	for (NSUInteger i = 0; i < [tabs count]; i++) {
		NSRect t = [self tabRect:i]; BOOL sel = i == [owner currentIndex];
		if (sel) { [(dark ? [NSColor colorWithCalibratedWhite:0.27 alpha:1] : [NSColor colorWithCalibratedWhite:0.97 alpha:1]) set]; NSRectFill(NSInsetRect(t, 0, 0)); }
		[[NSColor colorWithCalibratedWhite:dark ? 0 : 0.7 alpha:0.4] set]; NSRectFill(NSMakeRect(NSMaxX(t) - 1, 4, 1, TABBAR_H - 8));
		NSString *title = [[(TermPanes *)[tabs objectAtIndex:i] activePane] titleString];
		NSMutableParagraphStyle *ps = [[[NSMutableParagraphStyle alloc] init] autorelease]; [ps setAlignment:NSCenterTextAlignment]; [ps setLineBreakMode:NSLineBreakByTruncatingTail];
		NSDictionary *at = [NSDictionary dictionaryWithObjectsAndKeys:[NSFont systemFontOfSize:12], NSFontAttributeName, fg, NSForegroundColorAttributeName, ps, NSParagraphStyleAttributeName, nil];
		[title drawInRect:NSMakeRect(t.origin.x + 26, 6, t.size.width - 52, 16) withAttributes:at];
		if ((NSInteger)i == hoverTab || sel) {                               /* the close button */
			NSPoint c = NSMakePoint(t.origin.x + 14, TABBAR_H / 2); NSBezierPath *x = [NSBezierPath bezierPath];
			[x moveToPoint:NSMakePoint(c.x - 3, c.y - 3)]; [x lineToPoint:NSMakePoint(c.x + 3, c.y + 3)]; [x moveToPoint:NSMakePoint(c.x + 3, c.y - 3)]; [x lineToPoint:NSMakePoint(c.x - 3, c.y + 3)];
			[x setLineWidth:1.2]; [[fg colorWithAlphaComponent:(NSInteger)i == hoverTab ? 0.9 : 0.5] set]; [x stroke];
		}
	}
	NSPoint pc = NSMakePoint([self bounds].size.width - 16, TABBAR_H / 2); NSBezierPath *plus = [NSBezierPath bezierPath];     /* the new tab button */
	[plus moveToPoint:NSMakePoint(pc.x - 5, pc.y)]; [plus lineToPoint:NSMakePoint(pc.x + 5, pc.y)]; [plus moveToPoint:NSMakePoint(pc.x, pc.y - 5)]; [plus lineToPoint:NSMakePoint(pc.x, pc.y + 5)];
	[plus setLineWidth:1.3]; [[fg colorWithAlphaComponent:0.7] set]; [plus stroke];
	[[NSColor colorWithCalibratedWhite:dark ? 0 : 0.6 alpha:0.5] set]; NSRectFill(NSMakeRect(0, TABBAR_H - 1, [self bounds].size.width, 1));
}
- (NSInteger)tabAtPoint:(NSPoint)p { for (NSUInteger i = 0; i < [[owner tabs] count]; i++) if (NSPointInRect(p, [self tabRect:i])) return (NSInteger)i; return -1; }
- (void)mouseDown:(NSEvent *)e
{
	NSPoint p = [self convertPoint:[e locationInWindow] fromView:nil]; NSInteger i = [self tabAtPoint:p];
	if (p.x > [self bounds].size.width - 32) { [owner newTabWithProfile:nil command:nil]; return; }
	if (i < 0) return;
	NSRect t = [self tabRect:(NSUInteger)i]; if (p.x < t.origin.x + 24) { [owner closeTab:(NSUInteger)i]; return; }
	[owner selectTab:(NSUInteger)i];
}
- (void)mouseMoved:(NSEvent *)e { hoverTab = [self tabAtPoint:[self convertPoint:[e locationInWindow] fromView:nil]]; [self setNeedsDisplay:YES]; }
- (void)mouseExited:(NSEvent *)e { hoverTab = -1; [self setNeedsDisplay:YES]; }
- (void)updateTrackingAreas { [super updateTrackingAreas]; [self addTrackingRect:[self bounds] owner:self userData:nil assumeInside:NO]; }
- (void)setFrameSize:(NSSize)s { [super setFrameSize:s]; [self setNeedsDisplay:YES]; }
- (void)viewDidMoveToWindow { [[self window] setAcceptsMouseMovedEvents:YES]; [self addTrackingRect:[self bounds] owner:self userData:nil assumeInside:NO]; }
@end


/* ---- the controller ---- */
@implementation TermWindowController

+ (NSMutableArray *)all { if (!all) all = [[NSMutableArray alloc] init]; return all; }

- (instancetype)initWithProfile:(TermProfile *)p command:(NSString *)cmd
{
	if (!(self = [super init])) return nil;
	tabs = [[NSMutableArray alloc] init];
	TermProfile *prof = p ?: [TermProfile defaultProfile];
	TermView *first = [[[TermView alloc] initWithProfile:prof command:cmd] autorelease]; [first setDelegate:self];
	NSSize sz = [first idealSizeForCols:prof->cols rows:prof->rows];
	static int cascade; NSRect cr = NSMakeRect(80 + 24 * (cascade % 8), 160 + 0, sz.width, sz.height); cascade++;
	window = [[NSWindow alloc] initWithContentRect:cr styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask) backing:NSBackingStoreBuffered defer:NO];
	[window setReleasedWhenClosed:NO]; [window setDelegate:(id)self];
	root = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, sz.width, sz.height)]; [root setAutoresizesSubviews:NO];
	host = [[NSView alloc] initWithFrame:[root bounds]]; [root addSubview:host];
	[window setContentView:root];
	TermPanes *firstTab = [[[TermPanes alloc] initWithTerm:first] autorelease]; [tabs addObject:firstTab]; current = 0; [host addSubview:firstTab];
	[self applyWindowLook];
	[self layoutViews]; [self updateTitle];
	[[TermWindowController all] addObject:self];
	[window makeFirstResponder:first]; [window makeKeyAndOrderFront:nil];
	return self;
}
- (void)dealloc { [tabs release]; [root release]; [host release]; [window release]; [super dealloc]; }
- (NSWindow *)window { return window; }
- (TermView *)term { return [[tabs objectAtIndex:current] activePane]; }
- (TermPanes *)currentTab { return [tabs objectAtIndex:current]; }
- (NSArray *)tabs { return tabs; }
- (NSUInteger)currentIndex { return current; }

/* a profile with blur or transparency: the window is not opaque and a behind-window effect lies under the views */
- (void)applyWindowLook
{
	TermProfile *p = [[self term] profile]; BOOL clear = [p->background alphaComponent] < 0.999 || p->blur > 0;
	[window setOpaque:!clear]; [window setBackgroundColor:clear ? [NSColor clearColor] : p->background];
	[effect removeFromSuperview]; [effect release]; effect = nil;
	if (clear) {
		Class c = NSClassFromString(@"NSVisualEffectView");
		if (c) {
			effect = [[c alloc] initWithFrame:[root bounds]];
			@try { [effect setValue:[NSNumber numberWithInt:0] forKey:@"blendingMode"]; [effect setValue:[NSNumber numberWithInt:1] forKey:@"state"]; [effect setValue:[NSNumber numberWithInt:p->blur > 0.01 ? 21 : 21] forKey:@"material"]; } @catch (id x) {}
			[root addSubview:effect positioned:NSWindowBelow relativeTo:nil];
		}
	}
}

- (BOOL)tabBarShown { return forceTabBar || [tabs count] > 1; }
- (void)layoutViews
{
	NSRect b = [root bounds]; CGFloat top = 0, bottom = 0;
	[effect setFrame:b];
	if ([self tabBarShown]) { if (!tabBar) { tabBar = [[TermTabBar alloc] initWithOwner:self]; [root addSubview:tabBar]; } [tabBar setFrame:NSMakeRect(0, b.size.height - TABBAR_H, b.size.width, TABBAR_H)]; [tabBar setHidden:NO]; [tabBar setNeedsDisplay:YES]; top = TABBAR_H; }
	else [tabBar setHidden:YES];
	if (findShown && findBar) { [findBar setFrame:NSMakeRect(0, 0, b.size.width, FINDBAR_H)]; bottom = FINDBAR_H; }
	NSRect h = NSMakeRect(0, bottom, b.size.width, b.size.height - top - bottom); [host setFrame:h];
	for (TermPanes *t in tabs) [t setFrame:[host bounds]];
}
- (void)windowDidResize:(NSNotification *)n { (void)n; [self layoutViews]; }

- (void)updateTitle
{
	TermView *t = [self term]; const char *u = getenv("USER"); NSString *user = u ? [NSString stringWithUTF8String:u] : NSUserName();
	NSString *ot = [t titleString];
	[window setTitle:[ot isEqualToString:@"Terminal"] ? [NSString stringWithFormat:@"%@ — -%@ — %d×%d", user, [[[NSProcessInfo processInfo].environment objectForKey:@"SHELL"] lastPathComponent] ?: @"sh", [t cols], [t rows]] : [NSString stringWithFormat:@"%@ — %@", user, ot]];
}
- (void)termViewChanged:(TermView *)t { if (t == [self term]) [self updateTitle]; [tabBar setNeedsDisplay:YES]; }
- (void)termViewActivated:(TermView *)t { for (TermPanes *tab in tabs) if ([[tab panes] containsObject:t]) { [tab setActivePane:t]; [window makeFirstResponder:t]; [self updateTitle]; } }
- (void)termViewFontChanged:(TermView *)t { (void)t; }
- (void)termViewExited:(TermView *)t
{
	[self performSelector:@selector(closeExited:) withObject:t afterDelay:0.0];       /* the shell ended: its pane (the tab, the window) closes (Profile > Shell > "Close if the shell exited cleanly") */
}
- (void)closeExited:(TermView *)t
{
	for (NSUInteger i = 0; i < [tabs count]; i++) { TermPanes *tab = [tabs objectAtIndex:i]; if (![[tab panes] containsObject:t]) continue; if ([[tab panes] count] > 1) { [t setDelegate:nil]; [tab removePane:t]; [window makeFirstResponder:[self term]]; } else [self closeTab:i]; return; }
}
- (void)splitPane:(id)sender
{
	(void)sender; TermView *t = [[[TermView alloc] initWithProfile:[[self term] profile] command:nil] autorelease]; [t setDelegate:self];
	[[self currentTab] addPane:t]; [window makeFirstResponder:t]; [self updateTitle];
}
- (void)closeSplitPane:(id)sender
{
	(void)sender; TermPanes *tab = [self currentTab]; if ([[tab panes] count] < 2) return;
	TermView *t = [tab activePane]; [t setDelegate:nil]; [tab removePane:t]; [window makeFirstResponder:[self term]]; [self updateTitle];
}
- (BOOL)hasSplitPanes { return [[[self currentTab] panes] count] > 1; }

- (void)newTabWithProfile:(TermProfile *)p command:(NSString *)cmd
{
	TermProfile *prof = p ?: [[self term] profile];
	TermView *t = [[[TermView alloc] initWithProfile:prof command:cmd] autorelease]; [t setDelegate:self];
	TermPanes *nt = [[[TermPanes alloc] initWithTerm:t] autorelease]; [[self currentTab] removeFromSuperview]; [tabs insertObject:nt atIndex:current + 1]; current = current + 1; [host addSubview:nt];
	[self layoutViews]; [window makeFirstResponder:t]; [self updateTitle]; [tabBar setNeedsDisplay:YES];
	NSSize want = [[self term] idealSizeForCols:prof->cols rows:prof->rows]; (void)want;
}
- (void)selectTab:(NSUInteger)i
{
	if (i >= [tabs count] || i == current) return;
	[[self term] setActive:NO]; [[self currentTab] removeFromSuperview]; current = i; [host addSubview:[self currentTab]]; [self layoutViews]; [window makeFirstResponder:[self term]]; [[self term] setActive:YES]; [self applyWindowLook]; [self updateTitle]; [tabBar setNeedsDisplay:YES];
}
- (void)closeTab:(NSUInteger)i
{
	if (i >= [tabs count]) return;
	if ([tabs count] == 1) { [window close]; return; }
	TermPanes *t = [tabs objectAtIndex:i]; BOOL wasCurrent = i == current; [t removeFromSuperview]; for (TermView *pn in [t panes]) [pn setDelegate:nil]; [tabs removeObjectAtIndex:i];
	if (wasCurrent) { current = i >= [tabs count] ? [tabs count] - 1 : i; [host addSubview:[self currentTab]]; [window makeFirstResponder:[self term]]; } else if (i < current) current--;
	[self layoutViews]; [self updateTitle]; [tabBar setNeedsDisplay:YES];
}
- (void)closeCurrentTab:(id)sender { (void)sender; if ([self hasSplitPanes]) { [self closeSplitPane:nil]; return; } [self closeTab:current]; }
- (void)nextTab:(id)sender { (void)sender; [self selectTab:(current + 1) % [tabs count]]; }
- (void)previousTab:(id)sender { (void)sender; [self selectTab:(current + [tabs count] - 1) % [tabs count]]; }
- (void)toggleTabBar:(id)sender { (void)sender; forceTabBar = ![self tabBarShown] || ([tabs count] == 1 ? !forceTabBar : forceTabBar); if ([tabs count] > 1) forceTabBar = YES; [self layoutViews]; }
- (void)applyProfileToCurrent:(TermProfile *)p { [[self term] applyProfile:p]; [self applyWindowLook]; [self layoutViews]; [self updateTitle]; [tabBar setNeedsDisplay:YES]; }

/* ---- the find bar ---- */
- (void)buildFindBar
{
	findBar = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 400, FINDBAR_H)];
	findField = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 6, 260, 24)]; [findField setTarget:self]; [findField setAction:@selector(findNext:)]; [findField setPlaceholderString:@"Find"]; [findBar addSubview:findField];
	struct { NSString *t; SEL s; CGFloat x, w; } b[] = { { @"◀", @selector(findPrevious:), 278, 30 }, { @"▶", @selector(findNext:), 310, 30 }, { @"Done", @selector(hideFindBar:), 350, 56 } };
	for (int i = 0; i < 3; i++) { NSButton *bt = [[[NSButton alloc] initWithFrame:NSMakeRect(b[i].x, 5, b[i].w, 26)] autorelease]; [bt setTitle:b[i].t]; [bt setBezelStyle:NSRoundedBezelStyle]; [bt setTarget:self]; [bt setAction:b[i].s]; [findBar addSubview:bt]; }
	[root addSubview:findBar];
}
- (void)showFindBar:(id)sender
{
	(void)sender; if (!findBar) [self buildFindBar];
	findShown = YES; [findBar setHidden:NO]; [self layoutViews]; [window makeFirstResponder:findField];
	NSString *sel = [[self term] selectedText]; if ([sel length]) [findField setStringValue:sel];
	[[self term] setFindHighlight:[findField stringValue]];
}
- (void)hideFindBar:(id)sender { (void)sender; findShown = NO; [findBar setHidden:YES]; [[self term] setFindHighlight:nil]; [self layoutViews]; [window makeFirstResponder:[self term]]; }
- (void)findNext:(id)sender { (void)sender; if (!findShown) { [self showFindBar:nil]; return; } [[self term] setFindHighlight:[findField stringValue]]; if (![[self term] findText:[findField stringValue] forward:YES caseSensitive:findCase]) NSBeep(); }
- (void)findPrevious:(id)sender { (void)sender; if (!findShown) { [self showFindBar:nil]; return; } [[self term] setFindHighlight:[findField stringValue]]; if (![[self term] findText:[findField stringValue] forward:NO caseSensitive:findCase]) NSBeep(); }
- (void)useSelectionForFind:(id)sender { (void)sender; NSString *s = [[self term] selectedText]; if (![s length]) return; if (!findBar) [self buildFindBar]; [findField setStringValue:s]; [[self term] setFindHighlight:s]; }

/* ---- window events ---- */
- (void)windowDidBecomeKey:(NSNotification *)n { (void)n; [[self term] setActive:YES]; }
- (void)windowDidResignKey:(NSNotification *)n { (void)n; [[self term] setActive:NO]; }
- (BOOL)windowShouldClose:(id)sender { (void)sender; return YES; }
- (void)windowWillClose:(NSNotification *)n
{
	(void)n; for (TermPanes *tab in tabs) for (TermView *t in [tab panes]) [t setDelegate:nil];
	[[TermWindowController all] removeObject:self];
}
@end
