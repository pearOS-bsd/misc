/* The Open and Save panels of the Mac, drawn after the real ones (AppKit's NSOpenPanel / NSSavePanel run in the "Open and Save Panel Service", not in the Finder). The sizes and colours come from the panel of this Mac measured in a test program:
 * the Open panel is 880 x 448 with a sidebar 135 wide, a toolbar 63 high, columns 228 wide with rows of 22, a bar of 66 at the bottom; the Save panel is a form of 370 x 204 (Save As, Tags, Where).
 * GNUstep's NSSavePanel / NSOpenPanel stay the API: -[NSApplication runModalForWindow:] of one of them runs this panel instead, and the answers are handed out through the panel's accessors. */
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#include <math.h>

static IMP origSetName, origRunModal, origRunModalRel, origBeginCompletion, origSaveFilename, origOpenFilenames;
static const char kResult = 0;

static NSColor *RGB(int r, int g, int b) { return [NSColor colorWithCalibratedRed: r / 255.0 green: g / 255.0 blue: b / 255.0 alpha: 1]; }
static NSColor *RGBA(int r, int g, int b, double a) { return [NSColor colorWithCalibratedRed: r / 255.0 green: g / 255.0 blue: b / 255.0 alpha: a]; }
static BOOL PDark(void) { const char *e = getenv("WSD_APPEARANCE"); return !(e && !strcmp(e, "light")); }
/* the palette: measured on the dark panel (the light one is the same structure on white) */
#define P_CONTENT   (PDark() ? RGB(28, 36, 44) : RGB(255, 255, 255))
#define P_SIDEBAR   (PDark() ? RGB(31, 41, 50) : RGB(236, 236, 238))
#define P_CONTROL   (PDark() ? RGB(45, 52, 60) : RGB(245, 245, 247))
#define P_FIELD     (PDark() ? RGB(23, 24, 25) : RGB(255, 255, 255))
#define P_LINE      (PDark() ? RGB(50, 57, 65) : RGB(214, 214, 218))
#define P_SELECT    (PDark() ? RGB(46, 55, 64) : RGB(222, 222, 226))
#define P_TEXT      (PDark() ? RGBA(255, 255, 255, 0.85) : RGBA(0, 0, 0, 0.85))
#define P_DIM       (PDark() ? RGBA(255, 255, 255, 0.42) : RGBA(0, 0, 0, 0.42))
#define P_HEADER    (PDark() ? RGB(150, 157, 160) : RGB(120, 120, 124))

static NSDictionary *Attr(CGFloat size, BOOL bold, NSColor *col) { return @{ NSFontAttributeName: bold ? [NSFont boldSystemFontOfSize: size] : [NSFont systemFontOfSize: size], NSForegroundColorAttributeName: col }; }
static void Text(NSString *s, NSPoint left_center, CGFloat size, BOOL bold, NSColor *col, BOOL flipped)       /* the text's vertical centre at left_center.y */
{
	NSDictionary *a = Attr(size, bold, col); NSSize ts = [s sizeWithAttributes: a];
	[s drawAtPoint: NSMakePoint(left_center.x, left_center.y - ts.height / 2) withAttributes: a]; (void)flipped;
}
static void FillRound(NSRect r, CGFloat rad, NSColor *c) { [c setFill]; [[NSBezierPath bezierPathWithRoundedRect: r xRadius: rad yRadius: rad] fill]; }

/* ---- icons: a folder, a PDF, a plain document, drawn in a 16 pt box */
static void DrawFolder(NSRect r)
{
	NSBezierPath *b = [NSBezierPath bezierPathWithRoundedRect: NSMakeRect(r.origin.x, r.origin.y + 2.5, r.size.width, r.size.height - 4.5) xRadius: 2 yRadius: 2];
	[RGB(86, 176, 244) setFill]; [b fill];
	NSBezierPath *tab = [NSBezierPath bezierPathWithRoundedRect: NSMakeRect(r.origin.x, r.origin.y + 0.5, r.size.width * 0.45, 4) xRadius: 1.5 yRadius: 1.5]; [RGB(64, 150, 226) setFill]; [tab fill];
}
static void DrawDoc(NSRect r, BOOL pdf)
{
	NSRect d = NSInsetRect(r, 2.5, 0.5); FillRound(d, 1.5, pdf ? RGB(250, 250, 250) : RGB(236, 238, 240));
	if (pdf) { [RGB(214, 40, 40) setFill]; NSRectFill(NSMakeRect(d.origin.x + 1.5, d.origin.y + d.size.height * 0.45, d.size.width - 3, 3)); }
	else { [RGB(170, 176, 182) setFill]; for (int i = 0; i < 3; i++) NSRectFill(NSMakeRect(d.origin.x + 2, d.origin.y + 4 + i * 3, d.size.width - 5, 1)); }
}

/* ---- the entries of a directory, newest first, in the groups the Mac shows */
@interface WsdEntry : NSObject { @public NSString *name, *path; BOOL dir, enabled; NSDate *date; } @end
@implementation WsdEntry @end
static NSString *GroupOf(NSDate *d)
{
	NSCalendar *cal = [NSCalendar currentCalendar]; NSDate *now = [NSDate date]; NSTimeInterval age = [now timeIntervalSinceDate: d];
	NSDateComponents *a = [cal components: NSDayCalendarUnit | NSMonthCalendarUnit | NSYearCalendarUnit fromDate: d], *n = [cal components: NSDayCalendarUnit | NSMonthCalendarUnit | NSYearCalendarUnit fromDate: now];
	if ([a day] == [n day] && [a month] == [n month] && [a year] == [n year]) return @"Today";
	if (age < 2 * 86400 && [a day] != [n day]) return @"Yesterday";
	if (age < 7 * 86400) return @"Previous 7 Days";
	if (age < 30 * 86400) return @"Previous 30 Days";
	NSArray *months = @[ @"January", @"February", @"March", @"April", @"May", @"June", @"July", @"August", @"September", @"October", @"November", @"December" ];
	NSString *m = months[([a month] - 1) % 12];
	return [a year] == [n year] ? m : [NSString stringWithFormat: @"%@ %ld", m, (long)[a year]];
}

/* ---- one column of the browser */
@class WsdColumn;
@protocol WsdColumnDelegate - (void)column:(WsdColumn *)c clicked:(WsdEntry *)e doubleClick:(BOOL)dbl; @end
@interface WsdColumn : NSView { @public NSString *dir; NSMutableArray *rows; NSInteger selected; BOOL active; id<WsdColumnDelegate> delegate; NSArray *types; BOOL filesOK, dirsOK; NSString *filter; } @end
@implementation WsdColumn
- (BOOL)acceptsFirstResponder { return YES; }
- (BOOL)becomeFirstResponder { active = YES; [self setNeedsDisplay: YES]; return YES; }
- (BOOL)isFlipped { return YES; }
- (void)load
{
	rows = [NSMutableArray array]; NSFileManager *fm = [NSFileManager defaultManager]; NSMutableArray *ents = [NSMutableArray array];
	for (NSString *n in [fm contentsOfDirectoryAtPath: dir error: NULL]) {
		if ([n hasPrefix: @"."]) continue;
		if ([filter length] && [n rangeOfString: filter options: NSCaseInsensitiveSearch].location == NSNotFound) continue;
		WsdEntry *e = [WsdEntry new]; e->name = n; e->path = [dir stringByAppendingPathComponent: n]; BOOL d = NO; [fm fileExistsAtPath: e->path isDirectory: &d]; e->dir = d;
		e->date = [[fm attributesOfItemAtPath: e->path error: NULL] fileModificationDate] ?: [NSDate distantPast];
		e->enabled = d || (filesOK && (!types.count || [types containsObject: [[n pathExtension] lowercaseString]]));
		[ents addObject: e];
	}
	[ents sortUsingComparator: ^NSComparisonResult(WsdEntry *a, WsdEntry *b) { return [b->date compare: a->date]; }];
	NSString *last = nil;
	for (WsdEntry *e in ents) { NSString *g = GroupOf(e->date); if (![g isEqualToString: last]) { [rows addObject: g]; last = g; } [rows addObject: e]; }
	selected = -1;
	double h = 8; BOOL first = YES; for (id r in rows) { if ([r isKindOfClass: [NSString class]]) { h += first ? 26 : 48; first = NO; } else h += 22; }
	[self setFrameSize: NSMakeSize([self frame].size.width, fmax(h + 8, 40))];
}
- (NSRect)rectOfRow:(NSInteger)i
{
	double y = 0; BOOL first = YES;
	for (NSInteger k = 0; k <= i; k++) {
		id r = rows[k];
		if ([r isKindOfClass: [NSString class]]) { y += first ? 8 : 22; if (k == i) return NSMakeRect(0, y, [self bounds].size.width, 26); y += 26; first = NO; }
		else { if (k == i) return NSMakeRect(0, y, [self bounds].size.width, 22); y += 22; }
	}
	return NSZeroRect;
}
- (void)drawRect:(NSRect)dirty
{
	[P_CONTENT setFill]; NSRectFill(dirty);
	for (NSInteger i = 0; i < (NSInteger)[rows count]; i++) {
		NSRect rr = [self rectOfRow: i]; if (!NSIntersectsRect(rr, dirty)) continue; id r = rows[i];
		if ([r isKindOfClass: [NSString class]]) { Text(r, NSMakePoint(37, NSMinY(rr) + 14), 11, YES, P_HEADER, YES); continue; }
		WsdEntry *e = r; BOOL sel = i == selected;
		if (sel) FillRound(NSMakeRect(6, NSMinY(rr), rr.size.width - 12, 22), 6, active ? RGB(0, 122, 255) : P_SELECT);
		NSRect ic = NSMakeRect(17, NSMinY(rr) + 3, 16, 16);
		if (e->dir) DrawFolder(ic); else DrawDoc(ic, [[e->name pathExtension] caseInsensitiveCompare: @"pdf"] == NSOrderedSame);
		NSColor *tc = sel && active ? [NSColor whiteColor] : (e->enabled ? P_TEXT : P_DIM);
		Text(e->name, NSMakePoint(40, NSMidY(rr)), 13, NO, tc, YES);
		if (e->dir) { NSBezierPath *p = [NSBezierPath bezierPath]; double cx = rr.size.width - 20, cy = NSMidY(rr); [p setLineWidth: 1.3]; [p moveToPoint: NSMakePoint(cx, cy - 3.5)]; [p lineToPoint: NSMakePoint(cx + 3.5, cy)]; [p lineToPoint: NSMakePoint(cx, cy + 3.5)]; [(sel && active ? [NSColor whiteColor] : P_DIM) setStroke]; [p stroke]; }
	}
}
- (void)keyDown:(NSEvent *)ev
{
	NSString *k = [ev characters]; if (![k length]) return; unichar ch = [k characterAtIndex: 0];
	NSInteger n = (NSInteger)[rows count], i = selected;
	if (ch == NSDownArrowFunctionKey || ch == NSUpArrowFunctionKey) {
		NSInteger d = ch == NSDownArrowFunctionKey ? 1 : -1; i = i < 0 ? (d > 0 ? -1 : n) : i;
		for (i += d; i >= 0 && i < n; i += d) if (![rows[i] isKindOfClass: [NSString class]] && ((WsdEntry *)rows[i])->enabled) break;
		if (i < 0 || i >= n) return;
		selected = i; [self scrollRectToVisible: [self rectOfRow: i]]; [self setNeedsDisplay: YES]; [delegate column: self clicked: rows[i] doubleClick: NO];
	} else if (ch == NSRightArrowFunctionKey) [(id)delegate performSelector: @selector(focusNextColumnFrom:) withObject: self];
	else if (ch == NSLeftArrowFunctionKey) [(id)delegate performSelector: @selector(focusPreviousColumnFrom:) withObject: self];
	else [super keyDown: ev];
}
- (void)mouseDown:(NSEvent *)ev
{
	[[self window] makeFirstResponder: self];
	NSPoint p = [self convertPoint: [ev locationInWindow] fromView: nil];
	for (NSInteger i = 0; i < (NSInteger)[rows count]; i++) if (![rows[i] isKindOfClass: [NSString class]] && NSPointInRect(p, [self rectOfRow: i])) {
		WsdEntry *e = rows[i]; if (!e->enabled) return;
		selected = i; [self setNeedsDisplay: YES]; [delegate column: self clicked: e doubleClick: [ev clickCount] >= 2]; return;
	}
}
@end

/* ---- the sidebar */
@interface WsdSidebar : NSView { @public NSMutableArray *items; NSInteger selected; id target; SEL action; } @end
@implementation WsdSidebar
- (BOOL)isFlipped { return YES; }
- (void)setup
{
	NSString *home = NSHomeDirectory(); items = [NSMutableArray array];
	void (^add)(NSString *, NSString *, NSString *) = ^(NSString *kind, NSString *title, NSString *path) { [items addObject: @{ @"k": kind, @"t": title, @"p": path ?: @"" }]; };
	add(@"item", @"Recents", home); add(@"item", @"Shared", @"/Users");
	add(@"head", @"Favorites", nil); add(@"item", @"Applications", @"/Applications"); add(@"item", @"Desktop", [home stringByAppendingPathComponent: @"Desktop"]);
	add(@"item", @"Documents", [home stringByAppendingPathComponent: @"Documents"]); add(@"item", @"Downloads", [home stringByAppendingPathComponent: @"Downloads"]);
	add(@"head", @"Locations", nil); add(@"item", @"Macintosh HD", @"/"); add(@"item", [home lastPathComponent], home);
	selected = -1;
}
- (NSRect)rectOfItem:(NSInteger)i
{
	double y = 11;                                                                                                       /* measured: rows 30 high every 32, a header 24 high with 11 above and 21 to the next row's top */
	for (NSInteger k = 0; k <= i; k++) { BOOL head = [items[k][@"k"] isEqual: @"head"]; if (head) { y += 11; if (k == i) return NSMakeRect(0, y, 135, 24); y += 21; } else { if (k == i) return NSMakeRect(10, y, 108, 30); y += 32; } }
	return NSZeroRect;
}
- (void)drawRect:(NSRect)dirty
{
	[P_SIDEBAR setFill]; NSRectFill(dirty);
	for (NSInteger i = 0; i < (NSInteger)[items count]; i++) {
		NSDictionary *it = items[i]; NSRect r = [self rectOfItem: i];
		if ([it[@"k"] isEqual: @"head"]) { Text(it[@"t"], NSMakePoint(16, NSMidY(r)), 11, YES, P_HEADER, YES); continue; }
		if (i == selected) FillRound(r, 8, P_SELECT);
		NSRect ic = NSMakeRect(18, NSMidY(r) - 8, 18, 16); NSColor *tint = RGB(86, 176, 244);
		[tint setStroke]; [tint setFill];
		if ([it[@"t"] isEqual: @"Recents"] || [it[@"t"] isEqual: @"Shared"]) { [P_DIM setStroke]; NSBezierPath *c = [NSBezierPath bezierPathWithOvalInRect: NSInsetRect(ic, 1, 0)]; [c setLineWidth: 1.4]; [c stroke]; }
		else if ([it[@"p"] isEqual: @"/"]) { FillRound(NSMakeRect(ic.origin.x, ic.origin.y + 3, 18, 10), 3, P_DIM); }
		else DrawFolder(NSMakeRect(ic.origin.x, ic.origin.y, 17, 15));
		Text(it[@"t"], NSMakePoint(46, NSMidY(r)), 13, NO, P_TEXT, YES);
	}
}
- (void)mouseDown:(NSEvent *)ev
{
	NSPoint p = [self convertPoint: [ev locationInWindow] fromView: nil];
	for (NSInteger i = 0; i < (NSInteger)[items count]; i++) if (![items[i][@"k"] isEqual: @"head"] && NSPointInRect(p, [self rectOfItem: i])) { selected = i; [self setNeedsDisplay: YES]; [target performSelector: action withObject: items[i][@"p"]]; return; }
}
@end

/* ---- the toolbar: back / forward, view mode, grouping, the path pop-up, the search field */
@interface WsdToolbar : NSView { @public id target; BOOL canBack, canFwd; NSString *pathTitle; NSTextField *search; } @end
@implementation WsdToolbar
- (BOOL)isFlipped { return YES; }
- (void)drawRect:(NSRect)dirty
{
	[P_CONTENT setFill]; NSRectFill([self bounds]);
	[P_LINE setFill]; NSRectFill(NSMakeRect(0, 63, [self bounds].size.width, 1));
	double x0 = 20;                                                                                               /* measured in the panel's own coordinates minus the sidebar (135) */
	FillRound(NSMakeRect(x0, 20, 50, 24), 8, P_CONTROL);
	for (int k = 0; k < 2; k++) { NSBezierPath *p = [NSBezierPath bezierPath]; double cx = x0 + 13 + k * 24 + (k ? -2 : 2), cy = 32; [p setLineWidth: 1.5]; [p moveToPoint: NSMakePoint(cx + (k ? -3 : 3), cy - 5)]; [p lineToPoint: NSMakePoint(cx + (k ? 3 : -3), cy)]; [p lineToPoint: NSMakePoint(cx + (k ? -3 : 3), cy + 5)]; [((k ? canFwd : canBack) ? P_TEXT : P_DIM) setStroke]; [p stroke]; }
	FillRound(NSMakeRect(76, 20, 66, 24), 8, P_CONTROL); FillRound(NSMakeRect(150, 20, 66, 24), 8, P_CONTROL);
	[P_TEXT setFill]; for (int i = 0; i < 3; i++) NSRectFill(NSMakeRect(90 + i * 4.5, 27, 3, 10)); for (int i = 0; i < 9; i++) NSRectFill(NSMakeRect(163 + (i % 3) * 4.5, 27 + (i / 3) * 3.6, 2.5, 2.5));
	for (int k = 0; k < 2; k++) { double cx = (k ? 200 : 126); NSBezierPath *p = [NSBezierPath bezierPath]; [p setLineWidth: 1.4]; [p moveToPoint: NSMakePoint(cx - 3, 30)]; [p lineToPoint: NSMakePoint(cx, 33.5)]; [p lineToPoint: NSMakePoint(cx + 3, 30)]; [P_TEXT setStroke]; [p stroke]; }
	NSRect pp = NSMakeRect(258, 20, 229, 24); FillRound(pp, 8, P_CONTROL);                                         /* the path pop-up: a folder, the name, the up / down arrows */
	DrawFolder(NSMakeRect(268, 26, 14, 12)); Text(pathTitle ?: @"", NSMakePoint(287, 32), 13, NO, P_TEXT, YES);
	for (int k = 0; k < 2; k++) { NSBezierPath *p = [NSBezierPath bezierPath]; [p setLineWidth: 1.2]; double cx = NSMaxX(pp) - 14, cy = k ? 35 : 29; [p moveToPoint: NSMakePoint(cx - 3, cy + (k ? -2 : 2))]; [p lineToPoint: NSMakePoint(cx, cy + (k ? 1 : -1))]; [p lineToPoint: NSMakePoint(cx + 3, cy + (k ? -2 : 2))]; [P_TEXT setStroke]; [p stroke]; }
	NSBezierPath *lens = [NSBezierPath bezierPathWithOvalInRect: NSMakeRect(541, 26, 9, 9)]; [lens setLineWidth: 1.3]; [P_DIM setStroke]; [lens stroke];
	NSBezierPath *hd = [NSBezierPath bezierPath]; [hd setLineWidth: 1.3]; [hd moveToPoint: NSMakePoint(549, 35)]; [hd lineToPoint: NSMakePoint(552.5, 38.5)]; [hd stroke];
}
- (void)mouseDown:(NSEvent *)ev
{
	NSPoint p = [self convertPoint: [ev locationInWindow] fromView: nil];
	if (NSPointInRect(p, NSMakeRect(20, 20, 25, 24)) && canBack) [target performSelector: @selector(goBack)];
	else if (NSPointInRect(p, NSMakeRect(45, 20, 25, 24)) && canFwd) [target performSelector: @selector(goForward)];
	else if (NSPointInRect(p, NSMakeRect(258, 20, 229, 24))) [target performSelector: @selector(showPathMenu:) withObject: [NSValue valueWithPoint: NSMakePoint(258, 44)]];
}
@end

/* ---- the panel's content: the rounded background, the browser, the bottom bar, or the Save form */
/* the window's rounded corners: the views inside are square, this view on top cuts the corners out */
@interface WsdCorners : NSView { @public double radius; } @end
@implementation WsdCorners
- (BOOL)isFlipped { return YES; }
- (BOOL)isOpaque { return NO; }
- (NSView *)hitTest:(NSPoint)p { return nil; }
- (void)drawRect:(NSRect)r
{
	NSRect b = [self bounds]; double R = radius; NSGraphicsContext *g = [NSGraphicsContext currentContext]; [g saveGraphicsState]; [g setCompositingOperation: NSCompositeCopy];
	for (int k = 0; k < 4; k++) {
		double x = (k & 1) ? NSMaxX(b) : 0, y = (k & 2) ? NSMaxY(b) : 0, sx = (k & 1) ? -1 : 1, sy = (k & 2) ? -1 : 1;
		NSBezierPath *p = [NSBezierPath bezierPath]; [p moveToPoint: NSMakePoint(x, y)]; [p lineToPoint: NSMakePoint(x + sx * R, y)];
		for (int a = 0; a <= 16; a++) { double t = a / 16.0 * M_PI / 2; [p lineToPoint: NSMakePoint(x + sx * (R - R * sin(t)), y + sy * (R - R * cos(t)))]; }
		[p closePath]; [[NSColor clearColor] setFill]; [p fill];
	}
	[g restoreGraphicsState];
}
@end

@interface WsdPanelController : NSObject <WsdColumnDelegate> {
	@public NSPanel *win; NSView *root; WsdSidebar *sidebar; WsdToolbar *toolbar; NSMutableArray *cols; NSString *dir; NSMutableArray *history; NSInteger hpos;
	NSView *corners; NSString *searchText; BOOL isSave, filesOK, dirsOK, multiple; NSArray *types; NSString *chosen; NSButton *ok, *cancel; NSTextField *nameField; NSInteger result; NSString *message, *prompt;
}
@end
@interface WsdRoot : NSView { @public BOOL saveForm; id owner; NSString *whereTitle; } @end
@implementation WsdRoot
- (BOOL)isFlipped { return YES; }
- (void)drawRect:(NSRect)r
{
	[[NSColor clearColor] set]; NSRectFillUsingOperation(r, NSCompositeCopy); FillRound([self bounds], saveForm ? 18 : 22, P_CONTENT);
	if (!saveForm) return;
	NSRect pp = NSMakeRect(100, 116, 198, 24); FillRound(pp, 8, P_CONTROL); FillRound(NSMakeRect(308, 116, 22, 24), 8, P_CONTROL);   /* Where: the folder pop-up and the button that expands the browser */
	DrawFolder(NSMakeRect(110, 122, 14, 12)); Text(whereTitle ?: @"", NSMakePoint(129, 128), 13, NO, P_TEXT, YES);
	for (int k = 0; k < 2; k++) { NSBezierPath *p = [NSBezierPath bezierPath]; [p setLineWidth: 1.2]; double cx = NSMaxX(pp) - 14, cy = k ? 131 : 125; [p moveToPoint: NSMakePoint(cx - 3, cy + (k ? -2 : 2))]; [p lineToPoint: NSMakePoint(cx, cy + (k ? 1 : -1))]; [p lineToPoint: NSMakePoint(cx + 3, cy + (k ? -2 : 2))]; [P_TEXT setStroke]; [p stroke]; }
	NSBezierPath *ch = [NSBezierPath bezierPath]; [ch setLineWidth: 1.4]; [ch moveToPoint: NSMakePoint(314, 126)]; [ch lineToPoint: NSMakePoint(319, 130)]; [ch lineToPoint: NSMakePoint(324, 126)]; [P_TEXT setStroke]; [ch stroke];
}
- (void)mouseDown:(NSEvent *)ev
{
	if (!saveForm) return;
	NSPoint p = [self convertPoint: [ev locationInWindow] fromView: nil];
	if (NSPointInRect(p, NSMakeRect(100, 116, 198, 24))) [owner performSelector: @selector(showPathMenu:) withObject: [NSValue valueWithPoint: p]];
}
@end

@implementation WsdPanelController
- (void)column:(WsdColumn *)c clicked:(WsdEntry *)e doubleClick:(BOOL)dbl
{
	NSInteger idx = [cols indexOfObject: c];
	for (WsdColumn *x in cols) x->active = (x == c);
	while ((NSInteger)[cols count] > idx + 1) { NSScrollView *sv = [[cols lastObject] enclosingScrollView]; [sv setDocumentView: nil]; [sv removeFromSuperview]; [cols removeLastObject]; }
	chosen = e->path;
	if (e->dir) {
		if (dbl && !dirsOK) { [self navigate: e->path push: YES]; return; }
		[self addColumnFor: e->path];
	}
	if (dbl && ((e->dir && dirsOK) || (!e->dir && filesOK))) [self accept: nil];
	if (isSave && !e->dir) [nameField setStringValue: e->name];
	[self refresh];
}
- (void)focusNextColumnFrom:(WsdColumn *)c
{
	NSInteger i = [cols indexOfObject: c]; if (i + 1 >= (NSInteger)[cols count]) return; WsdColumn *n = cols[i + 1]; if (![n->rows count]) return;
	for (NSInteger k = 0; k < (NSInteger)[n->rows count]; k++) if (![n->rows[k] isKindOfClass: [NSString class]]) { n->selected = k; break; }
	[win makeFirstResponder: n]; for (WsdColumn *x in cols) { x->active = (x == n); [x setNeedsDisplay: YES]; } if (n->selected >= 0) [self column: n clicked: n->rows[n->selected] doubleClick: NO];
}
- (void)focusPreviousColumnFrom:(WsdColumn *)c
{
	NSInteger i = [cols indexOfObject: c]; if (i <= 0) return; WsdColumn *p = cols[i - 1]; [win makeFirstResponder: p]; for (WsdColumn *x in cols) { x->active = (x == p); [x setNeedsDisplay: YES]; }
}
- (void)addColumnFor:(NSString *)path
{
	WsdColumn *c = [[WsdColumn alloc] initWithFrame: NSMakeRect(0, 0, 228, 100)]; c->dir = path; c->types = types; c->filesOK = filesOK || isSave; c->dirsOK = dirsOK; c->delegate = self; c->filter = searchText; [c load];
	[cols addObject: c]; [self layoutColumns];
}
- (void)layoutColumns
{
	WsdRoot *rv = (WsdRoot *)root; double areaW = [rv bounds].size.width - 135, w = 228; NSInteger n = [cols count], vis = (NSInteger)(areaW / (w + 1)); NSInteger first = n > vis ? n - vis : 0;
	for (NSInteger i = 0; i < n; i++) {
		WsdColumn *c = cols[i]; NSScrollView *sv = (NSScrollView *)[c enclosingScrollView];
		if (!sv) { sv = [[NSScrollView alloc] initWithFrame: NSZeroRect]; [sv setHasVerticalScroller: YES]; [sv setBorderType: NSNoBorder]; [sv setAutohidesScrollers: YES]; [sv setDrawsBackground: NO]; [sv setDocumentView: c]; [rv addSubview: sv]; }
		[sv setHidden: i < first]; [sv setFrame: NSMakeRect(135 + (i - first) * (w + 1), 64, w, [rv bounds].size.height - 64 - 66)]; [c setFrameSize: NSMakeSize(w, [c frame].size.height)];
	}
	if (corners) { [corners removeFromSuperview]; [rv addSubview: corners]; }
	[rv setNeedsDisplay: YES];
}
- (void)navigate:(NSString *)path push:(BOOL)push
{
	if (!path) return;
	if (push) { while ((NSInteger)[history count] > hpos + 1) [history removeLastObject]; [history addObject: path]; hpos = (NSInteger)[history count] - 1; }
	for (WsdColumn *c in cols) { NSScrollView *sv = [c enclosingScrollView]; [sv setDocumentView: nil]; [sv removeFromSuperview]; } [cols removeAllObjects];
	dir = path; [self addColumnFor: path]; ((WsdColumn *)cols[0])->active = YES; chosen = nil; [self refresh];
}
- (void)sidebarGo:(NSString *)path { [self navigate: path push: YES]; }
- (void)goBack { if (hpos > 0) { hpos--; [self navigate: history[hpos] push: NO]; } }
- (void)goForward { if (hpos + 1 < (NSInteger)[history count]) { hpos++; [self navigate: history[hpos] push: NO]; } }
- (NSString *)currentDir { WsdColumn *c = [cols lastObject]; return c ? c->dir : dir; }
- (void)showPathMenu:(NSValue *)v
{
	NSMenu *m = [[NSMenu alloc] initWithTitle: @""]; NSString *p = [self currentDir]; NSMutableArray *chain = [NSMutableArray array];
	while ([p length] > 1) { [chain addObject: p]; p = [p stringByDeletingLastPathComponent]; } [chain addObject: @"/"];
	for (NSString *q in chain) { NSMenuItem *it = [m addItemWithTitle: [q isEqual: @"/"] ? @"Macintosh HD" : [q lastPathComponent] action: @selector(pathPicked:) keyEquivalent: @""]; [it setTarget: self]; [it setRepresentedObject: q]; }
	[m popUpMenuPositioningItem: nil atLocation: isSave ? NSMakePoint(100, 140) : NSMakePoint(135 + 258, 64 - 20) inView: root];
}
- (void)pathPicked:(NSMenuItem *)it { if (isSave) { WsdColumn *c = [WsdColumn new]; c->dir = [it representedObject]; [cols removeAllObjects]; [cols addObject: c]; [self refresh]; } else [self navigate: [it representedObject] push: YES]; }
- (void)refresh
{
	NSString *d = [self currentDir], *title = [d isEqual: @"/"] ? @"Macintosh HD" : [d lastPathComponent]; if (toolbar) { toolbar->pathTitle = title; toolbar->canBack = hpos > 0; toolbar->canFwd = hpos + 1 < (NSInteger)[history count]; }
	BOOL enable = chosen != nil;
	if (chosen) { BOOL isDir = NO; [[NSFileManager defaultManager] fileExistsAtPath: chosen isDirectory: &isDir]; enable = isDir ? dirsOK : filesOK; }
	if (isSave) enable = [[nameField stringValue] length] > 0;
	if (isSave) { ((WsdRoot *)root)->whereTitle = title; [root setNeedsDisplay: YES]; }
	[ok setEnabled: enable]; [toolbar setNeedsDisplay: YES]; [sidebar setNeedsDisplay: YES];
}
- (void)accept:(id)sender
{
	NSMutableArray *res = [NSMutableArray array];
	if (isSave) {
		NSString *n = [nameField stringValue]; if (![n length]) return;
		if (types.count && ![[n pathExtension] length]) n = [n stringByAppendingPathExtension: types[0]];
		[res addObject: [[self currentDir] stringByAppendingPathComponent: n]];
	} else if (chosen) [res addObject: chosen]; else if (dirsOK) [res addObject: [self currentDir]];
	if (![res count]) return;
	objc_setAssociatedObject(self->win, &kResult, res, OBJC_ASSOCIATION_RETAIN); result = 1; [NSApp stopModalWithCode: 1]; [win orderOut: nil];
}
- (void)cancelIt:(id)sender { result = 0; [NSApp stopModalWithCode: 0]; [win orderOut: nil]; }
- (void)controlTextDidChange:(NSNotification *)n
{
	if ([n object] == toolbar->search && toolbar) {                                                                    /* the search field filters the folders shown by name */
		searchText = [toolbar->search stringValue]; for (WsdColumn *c in cols) { c->filter = searchText; [c load]; [c setNeedsDisplay: YES]; }
	}
	[self refresh];
}
@end

@interface WsdFilePanelWindow : NSPanel @end
@implementation WsdFilePanelWindow
- (BOOL)canBecomeKeyWindow { return YES; }
- (BOOL)canBecomeMainWindow { return YES; }
- (void)cancelOperation:(id)s { [(WsdPanelController *)[self delegate] cancelIt: nil]; }
@end

static NSButton *Btn(NSString *title, NSRect f, id target, SEL action, BOOL def)
{
	NSButton *b = [[NSButton alloc] initWithFrame: f]; [b setTitle: title]; [b setBezelStyle: NSRoundedBezelStyle]; [b setTarget: target]; [b setAction: action]; if (def) [b setKeyEquivalent: @"\r"]; else if ([title isEqual: @"Cancel"]) [b setKeyEquivalent: @"\033"];
	return b;
}
static NSTextField *Field(NSRect f, NSString *val)
{
	NSTextField *t = [[NSTextField alloc] initWithFrame: f]; [t setBordered: NO]; [t setBezeled: NO]; [t setDrawsBackground: NO]; [t setStringValue: val ?: @""]; [t setFont: [NSFont systemFontOfSize: 13]]; [t setTextColor: P_TEXT]; [t setFocusRingType: NSFocusRingTypeNone];
	return t;
}

static NSInteger WsdRunPanel(NSSavePanel *sp)
{
	BOOL open = [sp isKindOfClass: [NSOpenPanel class]]; WsdPanelController *pc = [WsdPanelController new]; pc->isSave = !open;
	pc->filesOK = open ? [(NSOpenPanel *)sp canChooseFiles] : YES; pc->dirsOK = open ? [(NSOpenPanel *)sp canChooseDirectories] : NO; pc->multiple = open ? [(NSOpenPanel *)sp allowsMultipleSelection] : NO;
	NSMutableArray *ty = [NSMutableArray array]; for (NSString *t in [sp allowedFileTypes] ?: @[]) if ([t length]) [ty addObject: [t lowercaseString]]; pc->types = ty;
	NSString *nm = objc_getAssociatedObject(sp, "wsdname"); NSString *d = [sp directory]; if (![d length] || ![[NSFileManager defaultManager] fileExistsAtPath: d]) d = NSHomeDirectory();
	pc->cols = [NSMutableArray array]; pc->history = [NSMutableArray array];
	NSRect frame = open ? NSMakeRect(0, 0, 880, 448) : NSMakeRect(0, 0, 370, 204);
	NSScreen *sc = [NSScreen mainScreen]; NSRect sf = [sc frame]; frame.origin = NSMakePoint(floor((sf.size.width - frame.size.width) / 2), floor((sf.size.height - frame.size.height) / 2 + 30));
	WsdFilePanelWindow *w = [[WsdFilePanelWindow alloc] initWithContentRect: frame styleMask: NSBorderlessWindowMask backing: NSBackingStoreBuffered defer: NO];
	[w setOpaque: NO]; [w setBackgroundColor: [NSColor clearColor]]; [w setDelegate: (id)pc]; [w setReleasedWhenClosed: NO]; pc->win = w;
	WsdRoot *root = [[WsdRoot alloc] initWithFrame: NSMakeRect(0, 0, frame.size.width, frame.size.height)]; pc->root = root; root->owner = pc; root->saveForm = !open; [w setContentView: root];
	if (open) {
		WsdSidebar *sb = [[WsdSidebar alloc] initWithFrame: NSMakeRect(0, 0, 135, 448)]; [sb setup]; sb->target = pc; sb->action = @selector(sidebarGo:); pc->sidebar = sb; [root addSubview: sb];
		WsdToolbar *tb = [[WsdToolbar alloc] initWithFrame: NSMakeRect(135, 0, 745, 64)]; tb->target = pc; pc->toolbar = tb; [root addSubview: tb];
		NSTextField *sf2 = Field(NSMakeRect(135 + 529, 19, 196, 26), nil); [sf2 setBezeled: YES]; [sf2 setDelegate: (id)pc]; [[sf2 cell] setPlaceholderAttributedString: [[NSAttributedString alloc] initWithString: @"Search" attributes: Attr(13, NO, P_DIM)]]; [root addSubview: sf2]; tb->search = sf2;
		pc->cancel = Btn(@"Cancel", NSMakeRect(695, 448 - 43, 77, 22), pc, @selector(cancelIt:), NO); pc->ok = Btn(([sp prompt].length && ![[sp prompt] isEqual: @"Name:"]) ? [sp prompt] : @"Open", NSMakeRect(781, 448 - 43, 79, 22), pc, @selector(accept:), YES);
		[root addSubview: pc->cancel]; [root addSubview: pc->ok]; [pc->ok setEnabled: NO];
		[pc navigate: d push: YES]; for (NSInteger i = 0; i < (NSInteger)[sb->items count]; i++) if ([sb->items[i][@"p"] isEqual: d]) sb->selected = i;
	} else {
		NSString *title = [sp title] ?: @"Save"; NSTextField *t = Field(NSMakeRect(0, 8, 370, 20), title); [t setAlignment: NSCenterTextAlignment]; [t setTextColor: P_DIM]; [t setEditable: NO]; [root addSubview: t];
		NSTextField *l1 = Field(NSMakeRect(10, 41, 84, 20), @"Save As:"); [l1 setAlignment: NSRightTextAlignment]; [l1 setEditable: NO]; [l1 setTextColor: P_DIM]; [root addSubview: l1];
		NSTextField *l2 = Field(NSMakeRect(10, 79, 84, 20), @"Tags:"); [l2 setAlignment: NSRightTextAlignment]; [l2 setEditable: NO]; [l2 setTextColor: P_DIM]; [root addSubview: l2];
		NSTextField *l3 = Field(NSMakeRect(10, 116, 84, 20), @"Where:"); [l3 setAlignment: NSRightTextAlignment]; [l3 setEditable: NO]; [l3 setTextColor: P_DIM]; [root addSubview: l3];
		pc->nameField = Field(NSMakeRect(100, 41, 230, 25), nm ?: ([sp nameFieldStringValue] ?: @"")); [pc->nameField setBezeled: YES]; { NSTextField *tg = Field(NSMakeRect(100, 79, 230, 25), nil); [tg setBezeled: YES]; [root addSubview: tg]; } [pc->nameField setDelegate: (id)pc]; [root addSubview: pc->nameField];
		pc->cancel = Btn(@"Cancel", NSMakeRect(184, 160 - 0, 78, 24), pc, @selector(cancelIt:), NO); pc->ok = Btn(([sp prompt].length && ![[sp prompt] isEqual: @"Name:"]) ? [sp prompt] : @"Save", NSMakeRect(271, 160, 79, 24), pc, @selector(accept:), YES);
		[root addSubview: pc->cancel]; [root addSubview: pc->ok]; pc->dir = d; WsdColumn *c = [WsdColumn new]; c->dir = d; [pc->cols addObject: c]; [pc refresh];
		objc_setAssociatedObject(w, "dirpath", d, OBJC_ASSOCIATION_RETAIN);
	}
	{ WsdCorners *cv = [[WsdCorners alloc] initWithFrame: [root bounds]]; cv->radius = open ? 22 : 18; [root addSubview: cv]; pc->corners = cv; }
	[w makeKeyAndOrderFront: nil];
	if (open && [pc->cols count]) [w makeFirstResponder: pc->cols[0]];
	if (!open) [w makeFirstResponder: pc->nameField];
	NSInteger r = ((NSInteger (*)(id, SEL, NSWindow *))origRunModal)(NSApp, @selector(runModalForWindow:), w);
	NSArray *res = objc_getAssociatedObject(w, &kResult);
	objc_setAssociatedObject(sp, &kResult, r == 1 ? res : nil, OBJC_ASSOCIATION_RETAIN);
	[w orderOut: nil];
	return r == 1 ? NSOKButton : NSCancelButton;
}
/* the Save form draws its own fields (they are not NSControls with bezels): the Where pop-up and the expand button */
@interface WsdSaveFormDrawing : NSObject @end

static NSInteger wsdRunModalForWindow(id self, SEL _cmd, NSWindow *w)
{
	if ([w isKindOfClass: [NSSavePanel class]] && !getenv("WSD_NO_MACFILEPANEL")) return WsdRunPanel((NSSavePanel *)w);
	return ((NSInteger (*)(id, SEL, NSWindow *))origRunModal)(self, _cmd, w);
}
static NSInteger wsdRunModalRel(id self, SEL _cmd, NSWindow *w, NSWindow *rel)
{
	if ([w isKindOfClass: [NSSavePanel class]] && !getenv("WSD_NO_MACFILEPANEL")) return WsdRunPanel((NSSavePanel *)w);
	return ((NSInteger (*)(id, SEL, NSWindow *, NSWindow *))origRunModalRel)(self, _cmd, w, rel);
}
static void wsdBeginCompletion(id self, SEL _cmd, void (^handler)(NSInteger))
{
	if (getenv("WSD_NO_MACFILEPANEL")) { ((void (*)(id, SEL, id))origBeginCompletion)(self, _cmd, handler); return; }
	NSInteger r = WsdRunPanel((NSSavePanel *)self); if (handler) handler(r);
}
static NSString *wsdSaveFilename(id self, SEL _cmd)
{
	NSArray *r = objc_getAssociatedObject(self, &kResult); if ([r count]) return r[0];
	return ((NSString *(*)(id, SEL))origSaveFilename)(self, _cmd);
}
static NSArray *wsdOpenFilenames(id self, SEL _cmd)
{
	NSArray *r = objc_getAssociatedObject(self, &kResult); if (r) return r;
	return ((NSArray *(*)(id, SEL))origOpenFilenames)(self, _cmd);
}

static void wsdSetName(id self, SEL _cmd, NSString *v) { objc_setAssociatedObject(self, "wsdname", v, OBJC_ASSOCIATION_COPY); ((void (*)(id, SEL, id))origSetName)(self, _cmd, v); }
void WsdInstallFilePanel(void)
{
	if (origRunModal) return;
	Method m1 = class_getInstanceMethod([NSApplication class], @selector(runModalForWindow:)); if (m1) origRunModal = method_setImplementation(m1, (IMP)wsdRunModalForWindow);
	Method m2 = class_getInstanceMethod([NSApplication class], @selector(runModalForWindow:relativeToWindow:)); if (m2) origRunModalRel = method_setImplementation(m2, (IMP)wsdRunModalRel);
	Method m3 = class_getInstanceMethod([NSSavePanel class], @selector(beginWithCompletionHandler:)); if (m3) origBeginCompletion = method_setImplementation(m3, (IMP)wsdBeginCompletion);
	Method m6 = class_getInstanceMethod([NSSavePanel class], @selector(setNameFieldStringValue:)); if (m6) origSetName = method_setImplementation(m6, (IMP)wsdSetName);
	Method m4 = class_getInstanceMethod([NSSavePanel class], @selector(filename)); if (m4) origSaveFilename = method_setImplementation(m4, (IMP)wsdSaveFilename);
	Method m5 = class_getInstanceMethod([NSOpenPanel class], @selector(filenames)); if (m5) origOpenFilenames = method_setImplementation(m5, (IMP)wsdOpenFilenames);
}
