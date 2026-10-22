/* The Finder window: toolbar row, sidebar, icon view of the folder, path bar. The structure follows the real Finder (TBrowserWindowController, TSidebarViewController, TIconView ...); the internals are our own and
 * are replaced class by class by what the decompilation shows. Targets of the menu bar actions (cmdBack:, cmdGoHome: ... the selectors of the Finder's MenuBar nib) are implemented here and in TApplicationController. */
#import <AppKit/AppKit.h>
extern "C" NSImage *WsbsdCoreTypesIcon(NSString *file, CGFloat pt);

static NSImage *Icon(NSString *file, CGFloat pt) { return WsbsdCoreTypesIcon(file, pt); }
/* template icons (dark glyphs) in the colour of the text */
static NSImage *Tinted(NSImage *img, NSColor *c)
{
	if (!img) return nil; NSSize sz = [img size]; NSImage *out = [[NSImage alloc] initWithSize: sz]; [out lockFocus]; [img drawInRect: NSMakeRect(0, 0, sz.width, sz.height) fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1]; [c set]; NSRectFillUsingOperation(NSMakeRect(0, 0, sz.width, sz.height), NSCompositeSourceIn); [out unlockFocus]; return out;
}
static NSString *SizeString(unsigned long long b) { return [NSByteCountFormatter stringFromByteCount: (long long)b countStyle: NSByteCountFormatterCountStyleFile]; }

/* ---------- the icon view ---------- */
@protocol TIconViewDelegate <NSObject> - (void)iconViewOpenItem:(NSString *)path; - (void)iconViewSelectionChanged:(NSArray *)paths; @end
@interface TIconView : NSView { NSMutableArray<NSDictionary *> *_items; NSMutableIndexSet *_sel; NSInteger _anchor; CGFloat _iconSize; @public __weak id<TIconViewDelegate> delegate; }
- (void)setFolder:(NSString *)folder;
- (NSArray *)selectedPaths;
@end
@implementation TIconView
- (instancetype)initWithFrame:(NSRect)f { if ((self = [super initWithFrame: f])) { _items = [NSMutableArray array]; _sel = [NSMutableIndexSet indexSet]; _iconSize = 64; } return self; }
- (BOOL)isFlipped { return YES; } - (BOOL)acceptsFirstResponder { return YES; } - (BOOL)acceptsFirstMouse:(NSEvent *)e { return YES; }
- (void)setFolder:(NSString *)folder
{
	[_items removeAllObjects]; [_sel removeAllIndexes]; NSFileManager *fm = [NSFileManager defaultManager]; NSMutableArray *names = [NSMutableArray array];
	for (NSString *n in [fm contentsOfDirectoryAtPath: folder error: NULL]) if (![n hasPrefix: @"."]) [names addObject: n];
	for (NSString *n in [names sortedArrayUsingSelector: @selector(localizedStandardCompare:)]) {
		NSString *p = [folder stringByAppendingPathComponent: n]; NSDictionary *at = [fm attributesOfItemAtPath: p error: NULL]; BOOL dir = [at[NSFileType] isEqual: NSFileTypeDirectory] && ![[p pathExtension] isEqual: @"app"];
		[_items addObject: @{ @"name": n, @"path": p, @"dir": @(dir), @"info": dir ? @"" : SizeString([at[NSFileSize] unsignedLongLongValue]) }];
	}
	[self setFrameSize: [self _contentSize]]; [self setNeedsDisplay: YES]; [self _notify];
}
static const CGFloat kCW = 112, kCH = 112, kPad = 10;
- (NSSize)_contentSize { NSScrollView *sv = [self enclosingScrollView]; CGFloat w = sv ? [[sv contentView] bounds].size.width : [self bounds].size.width; NSInteger perRow = MAX(1, (NSInteger)((w - kPad) / kCW)); NSInteger rows = ((NSInteger)[_items count] + perRow - 1) / perRow; return NSMakeSize(w, MAX(rows * kCH + 2 * kPad, sv ? [[sv contentView] bounds].size.height : 100)); }
- (void)resizeWithOldSuperviewSize:(NSSize)o { [super resizeWithOldSuperviewSize: o]; [self setFrameSize: [self _contentSize]]; }
- (NSRect)_cell:(NSInteger)i { NSInteger perRow = MAX(1, (NSInteger)(([self bounds].size.width - kPad) / kCW)); return NSMakeRect(kPad + (i % perRow) * kCW, kPad + (i / perRow) * kCH, kCW, kCH); }
- (NSInteger)_index:(NSPoint)p { for (NSInteger i = 0; i < (NSInteger)[_items count]; i++) if (NSPointInRect(p, [self _cell: i])) return i; return -1; }
- (void)drawRect:(NSRect)r
{
	NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init]; [ps setAlignment: NSTextAlignmentCenter]; [ps setLineBreakMode: NSLineBreakByTruncatingMiddle];
	for (NSInteger i = 0; i < (NSInteger)[_items count]; i++) {
		NSRect c = [self _cell: i]; if (!NSIntersectsRect(c, r)) continue; NSDictionary *it = _items[i]; BOOL sel = [_sel containsIndex: i];
		NSRect ir = NSMakeRect(NSMidX(c) - _iconSize / 2, c.origin.y + 6, _iconSize, _iconSize); NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile: it[@"path"]];
		if (sel) { [[NSColor colorWithCalibratedWhite: 1 alpha: 0.12] setFill]; [[NSBezierPath bezierPathWithRoundedRect: NSInsetRect(ir, -6, -4) xRadius: 8 yRadius: 8] fill]; }
		if (icon) [icon drawInRect: ir fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1];
		NSRect lr = NSMakeRect(c.origin.x + 6, NSMaxY(ir) + 6, c.size.width - 12, 16); NSMutableDictionary *at = [@{ NSFontAttributeName: [NSFont systemFontOfSize: 12], NSForegroundColorAttributeName: [NSColor whiteColor], NSParagraphStyleAttributeName: ps } mutableCopy];
		if (sel) { NSSize ts = [it[@"name"] sizeWithAttributes: at]; NSRect hl = NSMakeRect(NSMidX(lr) - MIN(ts.width, lr.size.width) / 2 - 4, lr.origin.y - 1, MIN(ts.width, lr.size.width) + 8, 17); [[NSColor colorWithCalibratedRed: 0.1 green: 0.38 blue: 0.85 alpha: 1] setFill]; [[NSBezierPath bezierPathWithRoundedRect: hl xRadius: 4 yRadius: 4] fill]; }
		[it[@"name"] drawInRect: lr withAttributes: at];
		if ([it[@"info"] length]) { NSMutableDictionary *a2 = [at mutableCopy]; a2[NSFontAttributeName] = [NSFont systemFontOfSize: 10.5]; a2[NSForegroundColorAttributeName] = [NSColor colorWithCalibratedRed: 0.35 green: 0.6 blue: 1 alpha: 1]; [it[@"info"] drawInRect: NSMakeRect(lr.origin.x, NSMaxY(lr) + 2, lr.size.width, 14) withAttributes: a2]; }
	}
}
- (void)_notify { if ([delegate respondsToSelector: @selector(iconViewSelectionChanged:)]) [delegate iconViewSelectionChanged: [self selectedPaths]]; }
- (NSArray *)selectedPaths { NSMutableArray *a = [NSMutableArray array]; [_sel enumerateIndexesUsingBlock: ^(NSUInteger i, BOOL *s) { [a addObject: self->_items[i][@"path"]]; }]; return a; }
- (void)mouseDown:(NSEvent *)e
{
	[[self window] makeFirstResponder: self]; NSInteger i = [self _index: [self convertPoint: [e locationInWindow] fromView: nil]]; BOOL multi = ([e modifierFlags] & (NSCommandKeyMask | NSShiftKeyMask)) != 0;
	if (i < 0) { if (!multi) [_sel removeAllIndexes]; } else if ([e modifierFlags] & NSShiftKeyMask && _anchor >= 0) { [_sel removeAllIndexes]; [_sel addIndexesInRange: NSMakeRange(MIN(_anchor, i), labs(i - _anchor) + 1)]; } else if ([e modifierFlags] & NSCommandKeyMask) { if ([_sel containsIndex: i]) [_sel removeIndex: i]; else [_sel addIndex: i]; _anchor = i; } else { [_sel removeAllIndexes]; [_sel addIndex: i]; _anchor = i; }
	[self setNeedsDisplay: YES]; [self _notify];
	if (i >= 0 && [e clickCount] == 2 && [delegate respondsToSelector: @selector(iconViewOpenItem:)]) [delegate iconViewOpenItem: _items[i][@"path"]];
}
- (void)selectAll:(id)s { [_sel addIndexesInRange: NSMakeRange(0, [_items count])]; [self setNeedsDisplay: YES]; [self _notify]; }
- (void)keyDown:(NSEvent *)e
{
	NSString *k = [e charactersIgnoringModifiers]; if (![k length]) return; unichar c = [k characterAtIndex: 0]; NSInteger cur = [_sel count] ? (NSInteger)[_sel lastIndex] : -1, n = (NSInteger)[_items count], perRow = MAX(1, (NSInteger)(([self bounds].size.width - kPad) / kCW)), t = cur;
	if (c == NSLeftArrowFunctionKey) t = MAX(0, cur - 1); else if (c == NSRightArrowFunctionKey) t = MIN(n - 1, cur + 1); else if (c == NSUpArrowFunctionKey && !([e modifierFlags] & NSCommandKeyMask)) t = MAX(0, cur - perRow); else if (c == NSDownArrowFunctionKey && !([e modifierFlags] & NSCommandKeyMask)) t = MIN(n - 1, cur + perRow);
	else if (c == '\r' && cur >= 0) { [delegate iconViewOpenItem: _items[cur][@"path"]]; return; } else { [super keyDown: e]; return; }
	if (n) { [_sel removeAllIndexes]; [_sel addIndex: MAX(0, t)]; [self scrollRectToVisible: NSInsetRect([self _cell: MAX(0, t)], -4, -4)]; [self setNeedsDisplay: YES]; [self _notify]; }
}
@end

/* ---------- the sidebar ---------- */
@protocol TSidebarDelegate <NSObject> - (void)sidebarGoTo:(NSString *)path; @end
@interface TSidebarView : NSView { NSArray<NSDictionary *> *_rows; NSInteger _hover; @public NSString *current; __weak id<TSidebarDelegate> delegate; }
@end
@implementation TSidebarView
- (instancetype)initWithFrame:(NSRect)f
{
	if ((self = [super initWithFrame: f])) {
		NSString *home = NSHomeDirectory(); _hover = -1;
		_rows = @[ @{ @"head": @"Favorites" }, @{ @"t": @"Applications", @"i": @"SidebarApplicationsFolder.icns", @"p": @"/Applications" }, @{ @"t": @"Desktop", @"i": @"SidebarDesktopFolder.icns", @"p": [home stringByAppendingPathComponent: @"Desktop"] }, @{ @"t": @"Documents", @"i": @"SidebarDocumentsFolder.icns", @"p": [home stringByAppendingPathComponent: @"Documents"] }, @{ @"t": @"Downloads", @"i": @"SidebarDownloadsFolder.icns", @"p": [home stringByAppendingPathComponent: @"Downloads"] },
			@{ @"head": @"Locations" }, @{ @"t": NSUserName(), @"i": @"SidebarHomeFolder.icns", @"p": home }, @{ @"t": @"Macintosh HD", @"i": @"SidebarInternalDisk.icns", @"p": @"/" }, @{ @"t": @"Trash", @"i": @"TrashIcon.icns", @"p": [home stringByAppendingPathComponent: @".Trash"] } ];
	}
	return self;
}
- (BOOL)isFlipped { return YES; }
- (NSRect)_row:(NSInteger)i { return NSMakeRect(10, 40 + i * 32, [self bounds].size.width - 20, 30); }
- (void)drawRect:(NSRect)r
{
	[[NSColor colorWithCalibratedWhite: 0.16 alpha: 1] setFill]; NSRectFill([self bounds]);
	for (NSInteger i = 0; i < (NSInteger)[_rows count]; i++) {
		NSDictionary *row = _rows[i]; NSRect rr = [self _row: i];
		if (row[@"head"]) { [row[@"head"] drawAtPoint: NSMakePoint(rr.origin.x + 8, rr.origin.y + 8) withAttributes: @{ NSFontAttributeName: [NSFont boldSystemFontOfSize: 11], NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite: 0.55 alpha: 1] }]; continue; }
		BOOL cur = [current isEqual: row[@"p"]]; if (cur || i == _hover) { [[NSColor colorWithCalibratedWhite: cur ? 0.32 : 0.24 alpha: 1] setFill]; [[NSBezierPath bezierPathWithRoundedRect: rr xRadius: 8 yRadius: 8] fill]; }
		NSImage *ic = Tinted(Icon(row[@"i"], 18), [NSColor colorWithCalibratedRed: 0.45 green: 0.65 blue: 1 alpha: 1]); if (ic) [ic drawInRect: NSMakeRect(rr.origin.x + 8, rr.origin.y + 6, 18, 18) fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1];
		[row[@"t"] drawAtPoint: NSMakePoint(rr.origin.x + 34, rr.origin.y + 7) withAttributes: @{ NSFontAttributeName: [NSFont systemFontOfSize: 13], NSForegroundColorAttributeName: [NSColor whiteColor] }];
	}
}
- (NSInteger)_at:(NSPoint)p { for (NSInteger i = 0; i < (NSInteger)[_rows count]; i++) if (!_rows[i][@"head"] && NSPointInRect(p, [self _row: i])) return i; return -1; }
- (void)mouseDown:(NSEvent *)e { NSInteger i = [self _at: [self convertPoint: [e locationInWindow] fromView: nil]]; if (i >= 0) [delegate sidebarGoTo: _rows[i][@"p"]]; }
@end

/* ---------- the path bar ---------- */
@protocol TPathBarDelegate <NSObject> - (void)pathBarGoTo:(NSString *)path; @end
@interface TPathBarView : NSView { NSArray<NSString *> *_paths; @public NSString *path; __weak id<TPathBarDelegate> delegate; NSMutableArray<NSValue *> *_rects; }
@end
@implementation TPathBarView
- (BOOL)isFlipped { return YES; }
- (void)setPath:(NSString *)p { path = [p copy]; NSMutableArray *a = [NSMutableArray array]; NSString *q = p; while (YES) { [a insertObject: q atIndex: 0]; if ([q isEqual: @"/"]) break; q = [q stringByDeletingLastPathComponent]; if (![q length]) break; } _paths = a; [self setNeedsDisplay: YES]; }
- (void)drawRect:(NSRect)r
{
	[[NSColor colorWithCalibratedWhite: 0.12 alpha: 1] setFill]; NSRectFill([self bounds]); _rects = [NSMutableArray array]; CGFloat x = 12;
	for (NSString *p in _paths) {
		NSString *name = [p isEqual: @"/"] ? @"Macintosh HD" : [p lastPathComponent]; NSImage *ic = [[NSWorkspace sharedWorkspace] iconForFile: p]; NSDictionary *at = @{ NSFontAttributeName: [NSFont systemFontOfSize: 11], NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite: 0.8 alpha: 1] };
		NSSize ts = [name sizeWithAttributes: at]; if (ic) [ic drawInRect: NSMakeRect(x, 5, 16, 16) fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1]; [name drawAtPoint: NSMakePoint(x + 20, 6) withAttributes: at];
		[_rects addObject: [NSValue valueWithRect: NSMakeRect(x, 0, 24 + ts.width, 26)]]; x += 24 + ts.width; if (p != [_paths lastObject]) { [@"›" drawAtPoint: NSMakePoint(x + 4, 5) withAttributes: at]; x += 18; }
	}
}
- (void)mouseDown:(NSEvent *)e { NSPoint p = [self convertPoint: [e locationInWindow] fromView: nil]; for (NSUInteger i = 0; i < [_rects count]; i++) if (NSPointInRect(p, [_rects[i] rectValue])) { [delegate pathBarGoTo: _paths[i]]; return; } }
@end

/* ---------- the toolbar row ---------- */
@interface TToolbarView : NSView { @public NSString *title; NSImage *folderIcon; BOOL canBack, canForward; id target; NSSearchField *search; NSInteger mode; }
@end
@implementation TToolbarView
- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstMouse:(NSEvent *)e { return YES; }
- (void)drawRect:(NSRect)r
{
	[[NSColor colorWithCalibratedWhite: 0.19 alpha: 1] setFill]; NSRectFill([self bounds]); NSColor *w = [NSColor colorWithCalibratedWhite: 0.9 alpha: 1], *dim = [NSColor colorWithCalibratedWhite: 0.45 alpha: 1];
	/* back / forward */
	for (int k = 0; k < 2; k++) { BOOL en = k ? canForward : canBack; [(en ? w : dim) setStroke]; NSBezierPath *p = [NSBezierPath bezierPath]; CGFloat cx = 28 + k * 34, cy = 24; [p moveToPoint: NSMakePoint(cx + (k ? -4 : 4), cy - 8)]; [p lineToPoint: NSMakePoint(cx + (k ? 4 : -4), cy)]; [p lineToPoint: NSMakePoint(cx + (k ? -4 : 4), cy + 8)]; [p setLineWidth: 2]; [p setLineCapStyle: NSRoundLineCapStyle]; [p stroke]; }
	/* the title */
	NSDictionary *at = @{ NSFontAttributeName: [NSFont boldSystemFontOfSize: 14], NSForegroundColorAttributeName: w }; NSSize ts = [title sizeWithAttributes: at]; CGFloat tx = 110; if (folderIcon) { [folderIcon drawInRect: NSMakeRect(tx, 14, 20, 20) fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1]; tx += 26; } [title drawAtPoint: NSMakePoint(tx, 24 - ts.height / 2) withAttributes: at];
	/* the four views as small drawn glyphs */
	CGFloat vx = [self bounds].size.width - 360;
	for (int k = 0; k < 4; k++) { NSRect cell = NSMakeRect(vx + k * 34, 12, 32, 24); if (k == mode) { [[NSColor colorWithCalibratedWhite: 0.38 alpha: 1] setFill]; [[NSBezierPath bezierPathWithRoundedRect: cell xRadius: 6 yRadius: 6] fill]; } [w setStroke]; [w setFill]; NSRect g = NSInsetRect(cell, 9, 6);
		if (k == 0) for (int a = 0; a < 2; a++) for (int b = 0; b < 2; b++) [[NSBezierPath bezierPathWithRect: NSMakeRect(g.origin.x + a * 8, g.origin.y + b * 7, 5, 5)] fill];
		else if (k == 1) for (int a = 0; a < 3; a++) [[NSBezierPath bezierPathWithRect: NSMakeRect(g.origin.x, g.origin.y + a * 5, g.size.width, 2)] fill];
		else if (k == 2) { [[NSBezierPath bezierPathWithRect: g] stroke]; [[NSBezierPath bezierPathWithRect: NSMakeRect(g.origin.x + 4, g.origin.y, 1, g.size.height)] fill]; [[NSBezierPath bezierPathWithRect: NSMakeRect(g.origin.x + 9, g.origin.y, 1, g.size.height)] fill]; }
		else { [[NSBezierPath bezierPathWithRect: NSMakeRect(g.origin.x, g.origin.y, g.size.width, 8)] stroke]; [[NSBezierPath bezierPathWithRect: NSMakeRect(g.origin.x, g.origin.y + 11, 4, 3)] fill]; [[NSBezierPath bezierPathWithRect: NSMakeRect(g.origin.x + 7, g.origin.y + 11, 4, 3)] fill]; } }
}
- (void)mouseDown:(NSEvent *)e
{
	NSPoint p = [self convertPoint: [e locationInWindow] fromView: nil];
	if (p.x > 14 && p.x < 46 && canBack) [NSApp sendAction: @selector(cmdBack:) to: target from: self]; else if (p.x > 48 && p.x < 80 && canForward) [NSApp sendAction: @selector(cmdForward:) to: target from: self];
	CGFloat vx = [self bounds].size.width - 360; for (int k = 0; k < 4; k++) if (NSPointInRect(p, NSMakeRect(vx + k * 34, 12, 32, 24))) { SEL a[4] = { @selector(cmdViewAsIcons:), @selector(cmdViewAsList:), @selector(cmdViewAsColumns:), @selector(cmdViewAsGallery:) }; [NSApp sendAction: a[k] to: target from: self]; }
}
@end

/* ---------- the window controller ---------- */
@interface TBrowserWindowController : NSWindowController <TIconViewDelegate, TSidebarDelegate, TPathBarDelegate, NSWindowDelegate> { NSURL *_url; NSMutableArray<NSString *> *_history; NSInteger _hi; TToolbarView *_toolbar; TSidebarView *_sidebar; TIconView *_icons; TPathBarView *_pathBar; NSScrollView *_scroll; NSArray *_selection; }
+ (instancetype)newBrowserWithPath:(NSString *)path;
- (void)goToPath:(NSString *)path;
@end
static NSMutableArray *gBrowsers;
@implementation TBrowserWindowController
+ (instancetype)newBrowserWithPath:(NSString *)path
{
	TBrowserWindowController *c = [[self alloc] init]; [c _build]; [c goToPath: path ?: NSHomeDirectory()]; if (!gBrowsers) gBrowsers = [NSMutableArray array]; [gBrowsers addObject: c]; [[c window] makeKeyAndOrderFront: nil]; return c;
}
- (void)_build
{
	NSWindow *w = [[NSWindow alloc] initWithContentRect: NSMakeRect(160 + 24 * [gBrowsers count], 160, 1000, 600) styleMask: NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable backing: NSBackingStoreBuffered defer: NO];
	[w setReleasedWhenClosed: NO]; [w setMinSize: NSMakeSize(520, 320)]; [self setWindow: w]; [w setDelegate: self]; [w setWindowController: self]; NSView *cv = [w contentView]; NSRect b = [cv bounds];
	_toolbar = [[TToolbarView alloc] initWithFrame: NSMakeRect(0, b.size.height - 48, b.size.width, 48)]; [_toolbar setAutoresizingMask: NSViewWidthSizable | NSViewMinYMargin]; _toolbar->target = self; [cv addSubview: _toolbar];
	_sidebar = [[TSidebarView alloc] initWithFrame: NSMakeRect(0, 26, 220, b.size.height - 74)]; [_sidebar setAutoresizingMask: NSViewHeightSizable | NSViewMaxXMargin]; _sidebar->delegate = self; [cv addSubview: _sidebar];
	_scroll = [[NSScrollView alloc] initWithFrame: NSMakeRect(220, 26, b.size.width - 220, b.size.height - 74)]; [_scroll setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable]; [_scroll setHasVerticalScroller: YES]; [_scroll setDrawsBackground: YES]; [_scroll setBackgroundColor: [NSColor colorWithCalibratedWhite: 0.12 alpha: 1]];
	_icons = [[TIconView alloc] initWithFrame: [[_scroll contentView] bounds]]; _icons->delegate = self; [_icons setAutoresizingMask: NSViewWidthSizable]; [_scroll setDocumentView: _icons]; [cv addSubview: _scroll];
	_pathBar = [[TPathBarView alloc] initWithFrame: NSMakeRect(0, 0, b.size.width, 26)]; [_pathBar setAutoresizingMask: NSViewWidthSizable | NSViewMaxYMargin]; _pathBar->delegate = self; [cv addSubview: _pathBar]; _history = [NSMutableArray array]; _hi = -1;
}
- (void)_show:(NSString *)path
{
	_url = [NSURL fileURLWithPath: path]; NSString *name = [path isEqual: @"/"] ? @"Macintosh HD" : [path lastPathComponent]; [[self window] setTitle: name]; _toolbar->title = name; _toolbar->folderIcon = [[NSWorkspace sharedWorkspace] iconForFile: path];
	_toolbar->canBack = _hi > 0; _toolbar->canForward = _hi + 1 < (NSInteger)[_history count]; _sidebar->current = path; [_pathBar setPath: path]; [_icons setFolder: path]; [_toolbar setNeedsDisplay: YES]; [_sidebar setNeedsDisplay: YES];
}
- (void)goToPath:(NSString *)path { BOOL d = NO; if (![[NSFileManager defaultManager] fileExistsAtPath: path isDirectory: &d] || !d) return; if (_hi >= 0 && [_history[_hi] isEqual: path]) return; [_history removeObjectsInRange: NSMakeRange(_hi + 1, [_history count] - _hi - 1)]; [_history addObject: path]; _hi = [_history count] - 1; [self _show: path]; }
/* the menu bar actions */
- (void)cmdBack:(id)s { if (_hi > 0) { _hi--; [self _show: _history[_hi]]; } }
- (void)cmdForward:(id)s { if (_hi + 1 < (NSInteger)[_history count]) { _hi++; [self _show: _history[_hi]]; } }
- (void)cmdOpenParent:(id)s { [self goToPath: [[_url path] stringByDeletingLastPathComponent]]; }
- (void)cmdGoHome:(id)s { [self goToPath: NSHomeDirectory()]; }
- (void)cmdGoToDesktop:(id)s { [self goToPath: [NSHomeDirectory() stringByAppendingPathComponent: @"Desktop"]]; }
- (void)cmdGoToDocuments:(id)s { [self goToPath: [NSHomeDirectory() stringByAppendingPathComponent: @"Documents"]]; }
- (void)cmdGoToDownloads:(id)s { [self goToPath: [NSHomeDirectory() stringByAppendingPathComponent: @"Downloads"]]; }
- (void)cmdGoToApplications:(id)s { [self goToPath: @"/Applications"]; }
- (void)cmdGoToUtilities:(id)s { [self goToPath: @"/Applications/Utilities"]; }
- (void)cmdGoToComputer:(id)s { [self goToPath: @"/"]; }
- (void)cmdGoToUserLibrary:(id)s { [self goToPath: [NSHomeDirectory() stringByAppendingPathComponent: @"Library"]]; }
- (void)cmdOpen:(id)s { for (NSString *p in _selection) [self iconViewOpenItem: p]; }
- (void)cmdOpenWithDownArrow:(id)s { [self cmdOpen: s]; }
- (void)cmdViewAsIcons:(id)s { _toolbar->mode = 0; [_toolbar setNeedsDisplay: YES]; }
- (void)cmdViewAsList:(id)s { _toolbar->mode = 1; [_toolbar setNeedsDisplay: YES]; }
- (void)cmdViewAsColumns:(id)s { _toolbar->mode = 2; [_toolbar setNeedsDisplay: YES]; }
- (void)cmdViewAsGallery:(id)s { _toolbar->mode = 3; [_toolbar setNeedsDisplay: YES]; }
- (void)cmdTogglePathBar:(id)s { [_pathBar setHidden: ![_pathBar isHidden]]; }
- (void)cmdToggleSidebar:(id)s { [_sidebar setHidden: ![_sidebar isHidden]]; NSRect b = [[[self window] contentView] bounds]; CGFloat sw = [_sidebar isHidden] ? 0 : 220; [_scroll setFrame: NSMakeRect(sw, [_pathBar isHidden] ? 0 : 26, b.size.width - sw, b.size.height - 48 - ([_pathBar isHidden] ? 0 : 26))]; }
- (BOOL)validateMenuItem:(NSMenuItem *)i
{
	SEL a = [i action]; if (a == @selector(cmdBack:)) return _hi > 0; if (a == @selector(cmdForward:)) return _hi + 1 < (NSInteger)[_history count]; if (a == @selector(cmdOpen:) || a == @selector(cmdOpenWithDownArrow:)) return [_selection count] > 0;
	if (a == @selector(cmdTogglePathBar:)) { [i setTitle: [_pathBar isHidden] ? @"Show Path Bar" : @"Hide Path Bar"]; return YES; } if (a == @selector(cmdToggleSidebar:)) { [i setTitle: [_sidebar isHidden] ? @"Show Sidebar" : @"Hide Sidebar"]; return YES; }
	return [self respondsToSelector: a];
}
/* delegates */
- (void)iconViewOpenItem:(NSString *)path { BOOL d = NO; [[NSFileManager defaultManager] fileExistsAtPath: path isDirectory: &d]; if (d && ![[path pathExtension] isEqual: @"app"]) [self goToPath: path]; else [[NSWorkspace sharedWorkspace] openFile: path]; }
- (void)iconViewSelectionChanged:(NSArray *)paths { _selection = paths; }
- (void)sidebarGoTo:(NSString *)path { [self goToPath: path]; }
- (void)pathBarGoTo:(NSString *)path { [self goToPath: path]; }
- (void)windowWillClose:(NSNotification *)n { [gBrowsers removeObject: self]; }
@end
