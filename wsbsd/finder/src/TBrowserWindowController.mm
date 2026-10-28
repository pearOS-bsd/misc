/* The Finder window: toolbar row, sidebar, icon view of the folder, path bar. The structure follows the real Finder (TBrowserWindowController, TSidebarViewController, TIconView ...); the internals are our own and
 * are replaced class by class by what the decompilation shows. Targets of the menu bar actions (cmdBack:, cmdGoHome: ... the selectors of the Finder's MenuBar nib) are implemented here and in TApplicationController. */
#import <Cocoa/Cocoa.h>
#import <CoreServices/CoreServices.h>
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
extern "C" NSImage *WsbsdCoreTypesIcon(NSString *file, CGFloat pt);

#import "TFinderViews.h"
#include <sys/stat.h>
#import <objc/runtime.h>
static BOOL _searchBar_skipLib(NSString *root);
#define SizeString TFSizeString
#define DateString TFDateString
#define KindString TFKindString
@interface NSObject (TFDrag) - (BOOL)isDragPoint:(NSPoint)p; @end
@interface NSObject (TFSupport) + (void)roundWindow:(NSWindow *)w radius:(int)r; @end

/* ---------- the window controller ---------- */
@interface TBrowserWindowController : NSWindowController <TIconViewDelegate, TSidebarDelegate, TPathBarDelegate, NSWindowDelegate> { NSURL *_url; TPreviewPane *_preview; BOOL _showPane; NSMutableArray<NSString *> *_history; NSInteger _hi; TToolbarView *_toolbar; TSidebarView *_sidebar; TIconView *_icons; TListView *_list; TColumnView *_cols; TGalleryView *_gallery; TPathBarView *_pathBar; TWindowTrim *_trim; TStatusBarView *_status; BOOL _showStatus; TSearchBar *_searchBar; TTabBar *_tabBar; NSMutableArray *_tabs; NSInteger _tabIx; BOOL _forceTabBar; NSString *_lastGroup; NSArray *_found; NSInteger _searchGen; BOOL _searchStarted; NSMenu *_ctxMenu; NSString *_filter, *_tag; NSMutableArray *_undo, *_redo; long long _watchedMod; NSTimer *_watcher; NSArray *_cutPaths; NSArray *_selection; NSInteger _mode; }
+ (instancetype)newBrowserWithPath:(NSString *)path;
- (void)goToPath:(NSString *)path;
@end
static NSMutableArray *gBrowsers;
static NSString *TrashPath(void) { return [NSHomeDirectory() stringByAppendingPathComponent: @".Trash"]; }
static NSString *UniquePath(NSString *dir, NSString *base, NSString *ext)
{
	NSFileManager *fm = [NSFileManager defaultManager]; NSString *p = [dir stringByAppendingPathComponent: [ext length] ? [base stringByAppendingPathExtension: ext] : base];
	for (int n = 2; [fm fileExistsAtPath: p]; n++) p = [dir stringByAppendingPathComponent: [ext length] ? [[NSString stringWithFormat: @"%@ %d", base, n] stringByAppendingPathExtension: ext] : [NSString stringWithFormat: @"%@ %d", base, n]];
	return p;
}
@implementation TBrowserWindowController
+ (instancetype)newBrowserWithPath:(NSString *)path
{
	TBrowserWindowController *c = [[self alloc] init]; [c _build]; [c goToPath: path ?: NSHomeDirectory()]; [c _restoreStyleAndWindow: YES]; if (!gBrowsers) gBrowsers = [NSMutableArray array]; [gBrowsers addObject: c]; [[c window] makeKeyAndOrderFront: nil]; [NSClassFromString(@"WsdFinderSupport") roundWindow: [c window] radius: 16]; return c;
}
- (void)_build
{
	NSWindow *w = [[TFinderWindow alloc] initWithContentRect: NSMakeRect(160 + 24 * [gBrowsers count], 160, 1022, 552) styleMask: NSWindowStyleMaskBorderless backing: NSBackingStoreBuffered defer: NO];
	[w setReleasedWhenClosed: NO]; [w setOpaque: NO]; [w setBackgroundColor: [NSColor clearColor]]; [w setMinSize: NSMakeSize(560, 320)]; [w setContentView: [[TFinderRoot alloc] initWithFrame: NSMakeRect(0, 0, 1022, 552)]]; [self setWindow: w]; [w setDelegate: self]; [w setWindowController: self]; NSView *cv = [w contentView];
	_icons = [[TIconView alloc] initWithFrame: NSZeroRect]; _icons->delegate = self; [cv addSubview: _icons];
	_list = [[TListView alloc] initWithFrame: NSZeroRect]; _list->delegate = self; [_list setHidden: YES]; [cv addSubview: _list];
	_cols = [[TColumnView alloc] initWithFrame: NSZeroRect]; _cols->delegate = self; [_cols setHidden: YES]; [cv addSubview: _cols];
	_gallery = [[TGalleryView alloc] initWithFrame: NSZeroRect]; _gallery->delegate = self; [_gallery setHidden: YES]; [cv addSubview: _gallery];
	_sidebar = [[TSidebarView alloc] initWithFrame: NSZeroRect]; _sidebar->delegate = self; [cv addSubview: _sidebar];
	_toolbar = [[TToolbarView alloc] initWithFrame: NSZeroRect]; _toolbar->target = self; [cv addSubview: _toolbar];
	_pathBar = [[TPathBarView alloc] initWithFrame: NSZeroRect]; _pathBar->delegate = self; [cv addSubview: _pathBar]; _history = [NSMutableArray array]; _hi = -1;
	_status = [[TStatusBarView alloc] initWithFrame: NSZeroRect]; _status->target = self; [_status setHidden: YES]; [cv addSubview: _status];
	_tabBar = [[TTabBar alloc] initWithFrame: NSZeroRect]; _tabBar->target = self; [_tabBar setHidden: YES]; [cv addSubview: _tabBar]; _tabs = [NSMutableArray array];
	_searchBar = [[TSearchBar alloc] initWithFrame: NSZeroRect]; _searchBar->target = self; [_searchBar setHidden: YES]; [cv addSubview: _searchBar];
	_trim = [[TWindowTrim alloc] initWithFrame: NSZeroRect]; [cv addSubview: _trim];
	NSMenu *m = [[NSMenu alloc] initWithTitle: @""];
	for (NSArray *e in @[ @[ @"Open", @"cmdOpen:", @"" ], @[ @"Open With", @"", @"" ], @[ @"-", @"", @"" ], @[ @"Move to Trash", @"cmdMoveToTrash:", @"trash" ], @[ @"Put Back", @"cmdPutBack:", @"" ], @[ @"-", @"", @"" ], @[ @"Get Info", @"cmdShowStaticInfo:", @"" ], @[ @"Rename", @"cmdRename:", @"" ], @[ @"Compress", @"cmdCompress:", @"" ], @[ @"Duplicate", @"cmdDuplicate:", @"" ], @[ @"Make Alias", @"cmdMakeAlias:", @"" ], @[ @"Quick Look", @"cmdQuickLook:", @"" ], @[ @"Copy", @"copy:", @"" ], @[ @"-", @"", @"" ], @[ @"Share…", @"cmdShare:", @"square.and.arrow.up" ], @[ @"-", @"", @"" ] ]) {
		if ([e[0] isEqual: @"-"]) { [m addItem: [NSMenuItem separatorItem]]; continue; } NSMenuItem *it = [m addItemWithTitle: e[0] action: [e[1] length] ? NSSelectorFromString(e[1]) : NULL keyEquivalent: @""]; [it setTarget: self]; if ([e[2] length]) [it setToolTip: [@"sym:" stringByAppendingString: e[2]]]; if (![e[1] length]) [it setSubmenu: [[NSMenu alloc] initWithTitle: @"Open With"]]; }
	{ NSMenuItem *dots = [m addItemWithTitle: @"Tag colours" action: @selector(cmdToggleTag:) keyEquivalent: @""]; [dots setTarget: self]; [dots setTag: 2]; [dots setRepresentedObject: [NSClassFromString(@"WsdFinderSupport") tagNames]]; NSMenuItem *tg = [m addItemWithTitle: @"Tags…" action: @selector(cmdTagsPopup:) keyEquivalent: @""]; [tg setTarget: self]; [tg setToolTip: @"sym:tag"]; [m addItem: [NSMenuItem separatorItem]]; NSMenuItem *qa = [m addItemWithTitle: @"Quick Actions" action: NULL keyEquivalent: @""]; [qa setToolTip: @"sym:gearshape"]; NSMenu *qs = [[NSMenu alloc] initWithTitle: @"Quick Actions"]; NSMenuItem *cz = [qs addItemWithTitle: @"Customize…" action: @selector(cmdOpenQuickActionsPrefPane:) keyEquivalent: @""]; [cz setTarget: self]; [qa setSubmenu: qs]; }
	_watcher = [NSTimer scheduledTimerWithTimeInterval: 1 target: self selector: @selector(_watch:) userInfo: nil repeats: YES]; _ctxMenu = m; [_icons setMenu: m]; [_list setMenu: m]; [_gallery setMenu: m]; [_cols setMenu: m]; [self _layout];
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter]; [nc addObserver: self selector: @selector(_keyChanged:) name: NSWindowDidBecomeKeyNotification object: w]; [nc addObserver: self selector: @selector(_keyChanged:) name: NSWindowDidResignKeyNotification object: w];
}
/* the folder shown follows what happens to it (the Mac uses FSEvents): its modification time is looked at every second and the view refreshed, selection and scroll position kept */
- (void)_watch:(NSTimer *)t
{
	if (_tag || !_url || ![[self window] isVisible]) return; struct stat sb; if (stat([[_url path] fileSystemRepresentation], &sb)) return; long long m = (long long)sb.st_mtime * 1000000000LL + sb.st_mtim.tv_nsec;
	if (_watchedMod && m != _watchedMod) { _watchedMod = m; if (_mode == 0) [_icons reloadKeepingSelection]; else { NSArray *keep = _selection; [self reload]; (void)keep; } [self _updateStatus]; } else _watchedMod = m;
}
- (void)_redrawAll { for (NSView *v in [[[self window] contentView] subviews]) [v setNeedsDisplay: YES]; }
- (void)_keyChanged:(NSNotification *)n { [self _redrawAll]; [self performSelector: @selector(_redrawAll) withObject: nil afterDelay: 0.06]; }
- (void)windowDidResize:(NSNotification *)n { [self _layout]; [self _scheduleBoundsSave]; }
- (void)windowDidMove:(NSNotification *)n { [self _scheduleBoundsSave]; }
/* what the Finder keeps per folder in .DS_Store: the view style (vstl) and the window (bwsp) */
static NSString *StyleName(NSInteger m) { return @[ @"icnv", @"Nlsv", @"clmv", @"glyv" ][MAX(0, MIN(3, m))]; }
- (void)_scheduleBoundsSave { [NSObject cancelPreviousPerformRequestsWithTarget: self selector: @selector(_saveWindow) object: nil]; [self performSelector: @selector(_saveWindow) withObject: nil afterDelay: 0.8]; }
- (void)_saveWindow
{
	if (_tag || ![_url path] || ![[self window] isVisible]) return; TDSStore *ds = [TDSStore storeForFolder: [_url path]]; NSMutableDictionary *bw = [ds plistForName: @"." sid: @"bwsp"] ?: [NSMutableDictionary dictionary]; NSRect f = [[self window] frame]; CGFloat sh = [[NSScreen mainScreen] frame].size.height;
	bw[@"WindowBounds"] = [NSString stringWithFormat: @"{{%d, %d}, {%d, %d}}", (int)f.origin.x, (int)(sh - f.origin.y - f.size.height), (int)f.size.width, (int)f.size.height]; bw[@"ShowSidebar"] = @(![_sidebar isHidden]); bw[@"ContainerShowSidebar"] = @(![_sidebar isHidden]); bw[@"ShowToolbar"] = @(![_toolbar isHidden]); bw[@"ShowStatusBar"] = @(_showStatus); bw[@"ShowPathbar"] = @(![_pathBar isHidden]); bw[@"ShowTabView"] = @NO;
	[ds setPlist: bw forName: @"." sid: @"bwsp"]; [ds setValue: StyleName(_mode) type: @"type" forName: @"." sid: @"vstl"]; if (![ds valueForName: @"." sid: @"vSrn"]) [ds setValue: @1 type: @"long" forName: @"." sid: @"vSrn"]; [ds write];
}
- (void)_restoreStyleAndWindow:(BOOL)window
{
	if (_tag) return; TDSStore *ds = [TDSStore storeForFolder: [_url path]]; NSString *st = [ds valueForName: @"." sid: @"vstl"]; NSInteger m = [@[ @"icnv", @"Nlsv", @"clmv", @"glyv" ] indexOfObject: st ?: @""]; if (m != NSNotFound && m != _mode) [self _setMode: m];
	NSDictionary *bw = [ds plistForName: @"." sid: @"bwsp"]; if (!bw) return; if (bw[@"ShowStatusBar"] && [bw[@"ShowStatusBar"] boolValue] != _showStatus) [self cmdToggleStatusBar: nil];
	if (window && [bw[@"WindowBounds"] length]) { NSRect r = NSRectFromString([bw[@"WindowBounds"] stringByReplacingOccurrencesOfString: @"{{" withString: @"{"]); (void)r; int x, y, w, h; if (sscanf([bw[@"WindowBounds"] UTF8String], "{{%d, %d}, {%d, %d}}", &x, &y, &w, &h) == 4 && w >= 560 && h >= 320) { CGFloat sh = [[NSScreen mainScreen] frame].size.height; [[self window] setFrame: NSMakeRect(x, sh - y - h, w, h) display: YES]; [self _layout]; } }
}
- (void)cmdTagsPopup:(id)s { if (![[self _targets] count]) return; TFShowTagsPopover([self _targets], [_toolbar buttonRect: 1], _toolbar, self); }
- (void)cmdOpenQuickActionsPrefPane:(id)s {}
/* the menu of the empty space of an icon view, as the real Finder's Action menu shows it without a selection (read from its accessibility tree: 233 wide; New Folder, Open in New Tab, Get Info, Quick Look "folder", Use Groups, Sort By, Clean Up, Clean Up By, Show View Options; "Import from iPhone" only appears with a phone connected and is left out) */
/* the background menu of the list view, as the real Finder shows it (AX of the open menu on the Mac): New Folder, Get Info, View, Use Groups, Sort By (the columns), the two options toggles; the Mac adds Import from iPhone and the Services of the folder (Folder Actions Setup, New Terminal at Folder...), which are not here */
- (NSMenu *)_listBackgroundMenu
{
	NSMenu *m = [[NSMenu alloc] initWithTitle: @""];
	NSMenuItem *(^Add)(NSMenu *, NSString *, SEL, id) = ^NSMenuItem *(NSMenu *menu, NSString *t, SEL a, id rep) { NSMenuItem *i = [menu addItemWithTitle: t action: a keyEquivalent: @""]; [i setTarget: self]; if (rep) [i setRepresentedObject: rep]; return i; };
	Add(m, @"New Folder", @selector(cmdNewFolder:), nil); [m addItem: [NSMenuItem separatorItem]];
	Add(m, @"Get Info", @selector(cmdShowStaticInfo:), nil); [m addItem: [NSMenuItem separatorItem]];
	NSMenuItem *vw = Add(m, @"View", NULL, nil); NSMenu *vs = [[NSMenu alloc] initWithTitle: @"View"]; int vi = 0;
	for (NSArray *k in @[ @[ @"as Icons", @"cmdViewAsIcons:" ], @[ @"as List", @"cmdViewAsList:" ], @[ @"as Columns", @"cmdViewAsColumns:" ], @[ @"as Gallery", @"cmdViewAsGallery:" ] ]) { NSMenuItem *x = Add(vs, k[0], NSSelectorFromString(k[1]), nil); if (vi++ == _mode) [x setState: NSOnState]; }
	[vw setSubmenu: vs];
	NSMenuItem *ug = Add(m, @"Use Groups", @selector(cmdUseGroupsOrStacks:), nil); [ug setState: [_list->_group length] ? NSOnState : NSOffState];
	NSMenuItem *sb = Add(m, @"Sort By", NULL, nil); NSMenu *ss = [[NSMenu alloc] initWithTitle: @"Sort By"]; NSString *cur = _list->_colKey ?: @"name";
	for (NSArray *k in @[ @[ @"Name", @"name" ], @[ @"Kind", @"kind" ], @[ @"Date Last Opened", @"dateLastOpened" ], @[ @"Date Added", @"dateAdded" ], @[ @"Date Modified", @"dateModified" ], @[ @"Date Created", @"dateCreated" ], @[ @"Size", @"size" ], @[ @"Tags", @"label" ] ]) { NSMenuItem *x = Add(ss, k[0], @selector(cmdListSortBy:), k[1]); if ([cur isEqual: k[1]]) [x setState: NSOnState]; }
	[sb setSubmenu: ss];
	Add(m, @"Show View Options", @selector(cmdToggleViewOptions:), nil); Add(m, @"Show Preview Options", @selector(cmdTogglePreviewOptions:), nil);
	return m;
}
- (void)cmdListSortBy:(NSMenuItem *)it { [_list sortByColumn: [it representedObject]]; }
- (NSMenu *)backgroundContextMenu
{
	if (_mode == 1 && !_tag && !_filter) return [self _listBackgroundMenu];
	if (_mode != 0 || _tag || _filter) return nil; NSMenu *m = [[NSMenu alloc] initWithTitle: @""]; NSString *fn = [[_url path] isEqual: @"/"] ? @"Macintosh HD" : [[_url path] lastPathComponent];
	NSMenuItem *(^Add)(NSMenu *, NSString *, SEL, id) = ^NSMenuItem *(NSMenu *menu, NSString *t, SEL a, id rep) { NSMenuItem *i = [menu addItemWithTitle: t action: a keyEquivalent: @""]; [i setTarget: self]; if (rep) [i setRepresentedObject: rep]; return i; };
	Add(m, @"New Folder", @selector(cmdNewFolder:), nil); Add(m, @"Open in New Tab", @selector(cmdNewTab:), nil); [m addItem: [NSMenuItem separatorItem]];
	Add(m, @"Get Info", @selector(cmdShowStaticInfo:), nil); Add(m, [NSString stringWithFormat: @"Quick Look “%@”", fn], @selector(cmdQuickLook:), nil); [m addItem: [NSMenuItem separatorItem]];
	NSMenuItem *ug = Add(m, @"Use Groups", @selector(cmdUseGroupsOrStacks:), nil); [ug setState: _icons->_group ? NSOnState : NSOffState];
	NSMenuItem *sb = Add(m, @"Sort By", NULL, nil); NSMenu *ss = [[NSMenu alloc] initWithTitle: @"Sort By"]; NSString *cur = _icons->_arrange;
	NSMenuItem *none = Add(ss, @"None", @selector(cmdSortByKey:), @""); [none setState: ([cur length] || _icons->_snap) ? NSOffState : NSOnState]; [ss addItem: [NSMenuItem separatorItem]]; [Add(ss, @"Snap to Grid", @selector(cmdSnapToGrid:), nil) setState: _icons->_snap ? NSOnState : NSOffState]; [ss addItem: [NSMenuItem separatorItem]];
	for (NSArray *k in @[ @[ @"Name", @"name" ], @[ @"Kind", @"kind" ], @[ @"Date Last Opened", @"opened" ], @[ @"Date Added", @"created" ], @[ @"Date Modified", @"modified" ], @[ @"Date Created", @"created" ], @[ @"Size", @"size" ], @[ @"Tags", @"tags" ] ]) { NSMenuItem *x = Add(ss, k[0], @selector(cmdSortByKey:), k[1]); if ([cur isEqual: k[1]] && ![k[0] isEqual: @"Date Added"]) [x setState: NSOnState]; }
	[sb setSubmenu: ss]; Add(m, @"Clean Up", @selector(cmdCleanUp:), nil);
	NSMenuItem *cb = Add(m, @"Clean Up By", NULL, nil); NSMenu *cs = [[NSMenu alloc] initWithTitle: @"Clean Up By"]; for (NSArray *k in @[ @[ @"Name", @"cmdCleanUpByName:" ], @[ @"Kind", @"cmdCleanUpByKind:" ], @[ @"Date Modified", @"cmdCleanUpByModDate:" ], @[ @"Date Created", @"cmdCleanUpByCreationDate:" ], @[ @"Size", @"cmdCleanUpByPhysicalSize:" ], @[ @"Tags", @"cmdCleanUpByLabel:" ] ]) Add(cs, k[0], NSSelectorFromString(k[1]), nil); [cb setSubmenu: cs];
	Add(m, @"Show View Options", @selector(cmdToggleViewOptions:), nil);
	return m;
}
- (void)cmdSnapToGrid:(id)s { [_icons setSnapToGrid: !_icons->_snap]; }
- (void)prepareContextMenu:(NSMenu *)m
{
	NSString *one = [_selection count] == 1 ? [_selection[0] lastPathComponent] : nil; NSString *ext = [[_selection firstObject] pathExtension].lowercaseString; BOOL arch = [@[ @"zip", @"gz", @"tgz", @"bz2", @"xz", @"7z", @"rar", @"dmg", @"tar" ] containsObject: ext];
	for (NSMenuItem *it in [m itemArray]) { if ([NSStringFromSelector([it action]) isEqual: @"cmdQuickLook:"]) [it setTitle: one ? [NSString stringWithFormat: @"Quick Look “%@”", one] : [NSString stringWithFormat: @"Quick Look %lu Items", (unsigned long)[_selection count]]]; if ([NSStringFromSelector([it action]) isEqual: @"cmdCompress:"]) { [it setTitle: one ? [NSString stringWithFormat: @"Compress “%@”", one] : [NSString stringWithFormat: @"Compress %lu Items", (unsigned long)[_selection count]]]; [it setHidden: arch && [_selection count] == 1]; } }
	if (getenv("FINDER_DEBUG")) for (NSMenuItem *it in [m itemArray]) NSLog(@"ctx item %@ action %@ sel %lu", [it title], NSStringFromSelector([it action]), (unsigned long)[_selection count]);
	/* Quick Actions: what applies to the selection (images can be turned), then Customize… */
	for (NSMenuItem *it in [m itemArray]) if ([[it title] isEqual: @"Quick Actions"] && [it submenu]) { NSMenu *sub = [it submenu]; while ([sub numberOfItems]) [sub removeItemAtIndex: 0]; BOOL imgs = [_selection count] > 0; for (NSString *p in _selection) if (![@[ @"png", @"jpg", @"jpeg", @"tif", @"tiff", @"gif", @"bmp" ] containsObject: [[p pathExtension] lowercaseString]]) imgs = NO;
		if (imgs) { NSMenuItem *r = [sub addItemWithTitle: @"Rotate Left" action: @selector(cmdRotateLeft:) keyEquivalent: @""]; [r setTarget: self]; [r setToolTip: @"sym:rotate.left"]; [sub addItem: [NSMenuItem separatorItem]]; }
		NSMenuItem *cz = [sub addItemWithTitle: @"Customize…" action: @selector(cmdOpenQuickActionsPrefPane:) keyEquivalent: @""]; [cz setTarget: self]; }
	for (NSMenuItem *it in [m itemArray]) if ([[it title] isEqual: @"Open With"]) { NSMenu *sub = [it submenu]; while ([sub numberOfItems]) [sub removeItemAtIndex: 0]; NSString *p = [_selection firstObject]; if (!p) return;
		/* as the real menu is (read from its accessibility tree): the default application with "(default)", a separator, the others by name, a separator, "App Store…" and "Other…" */
		NSArray *apps = TFAppsForFile(p); NSUInteger ai = 0; for (NSDictionary *a in apps) { NSString *t = ai == 0 ? [a[@"name"] stringByAppendingString: @" (default)"] : a[@"name"]; NSMenuItem *x = [sub addItemWithTitle: t action: @selector(cmdOpenWithApp:) keyEquivalent: @""]; [x setTarget: self]; [x setRepresentedObject: a[@"path"]]; if (ai++ == 0 && [apps count] > 1) [sub addItem: [NSMenuItem separatorItem]]; }
		if ([apps count]) [sub addItem: [NSMenuItem separatorItem]]; NSMenuItem *st = [sub addItemWithTitle: @"App Store…" action: @selector(cmdOpenWithAppStore:) keyEquivalent: @""]; [st setTarget: self];
		NSMenuItem *o = [sub addItemWithTitle: @"Other…" action: @selector(cmdOpenWithOther:) keyEquivalent: @""]; [o setTarget: self]; }
}
- (void)cmdOpenWithApp:(NSMenuItem *)it { NSString *app = [it representedObject]; for (NSString *p in _selection) [[NSWorkspace sharedWorkspace] openFile: p withApplication: app]; }
- (void)cmdOpenWithAppStore:(id)s { for (NSString *a in @[ @"/System/Applications/App Store.app", @"/Applications/App Store.app" ]) if ([[NSFileManager defaultManager] fileExistsAtPath: a]) { [[NSWorkspace sharedWorkspace] launchApplication: a]; return; } NSBeep(); }
- (void)cmdOpenWithOther:(id)s { NSOpenPanel *op = [NSOpenPanel openPanel]; [op setDirectoryURL: [NSURL fileURLWithPath: @"/Applications"]]; [op setAllowedFileTypes: @[ @"app" ]]; if ([op runModal] == NSOKButton) for (NSString *p in _selection) [[NSWorkspace sharedWorkspace] openFile: p withApplication: [[[op URLs] firstObject] path]]; }
- (NSMenu *)actionMenu { return _ctxMenu; }
- (NSMenu *)groupMenu                                                                         /* the toolbar's Group button, as measured on the Mac: None, line, then the keys (156 wide) */
{
	NSString *cur = _mode == 1 ? _list->_group : _mode == 0 ? _icons->_group : nil; NSMenu *m = [[NSMenu alloc] initWithTitle: @""];
	NSArray *o = @[ @[ @"None", @"" ], @[ @"-", @"" ], @[ @"Name", @"name" ], @[ @"Kind", @"kind" ], @[ @"Application", @"application" ], @[ @"Date Last Opened", @"dateLastOpened" ], @[ @"Date Added", @"dateAdded" ], @[ @"Date Modified", @"dateModified" ], @[ @"Date Created", @"dateCreated" ], @[ @"Size", @"size" ], @[ @"Tags", @"tags" ] ];
	for (NSArray *a in o) { if ([a[0] isEqual: @"-"]) { [m addItem: [NSMenuItem separatorItem]]; continue; } NSMenuItem *it = [m addItemWithTitle: a[0] action: @selector(cmdGroupByKey:) keyEquivalent: @""]; [it setTarget: self]; [it setRepresentedObject: a[1]]; [it setState: [a[1] isEqual: cur ?: @""] ? NSOnState : NSOffState]; }
	return m;
}
- (NSMenu *)tagMenu { NSMenu *m = [[NSMenu alloc] initWithTitle: @"Tags"]; [self _fillTagMenu: m]; return m; }
- (void)_markTagMenu:(NSMenu *)m { for (NSMenuItem *i in [m itemArray]) { BOOL all = [_selection count] > 0; for (NSString *p in _selection) if (![TFTagsOf(p) containsObject: [i representedObject]]) all = NO; [i setState: all ? NSOnState : NSOffState]; } }
- (void)_fillTagMenu:(NSMenu *)m
{
	Class sp = NSClassFromString(@"WsdFinderSupport"); for (NSString *n in [sp tagNames]) {
		NSMenuItem *it = [m addItemWithTitle: n action: @selector(cmdToggleTag:) keyEquivalent: @""]; [it setTarget: self]; [it setRepresentedObject: n]; [it setTag: 1]; NSImage *dot = [[NSImage alloc] initWithSize: NSMakeSize(12, 12)]; [dot lockFocus]; [[sp colorOfTag: n] setFill]; [[NSBezierPath bezierPathWithOvalInRect: NSMakeRect(0, 0, 12, 12)] fill]; [dot unlockFocus]; [it setImage: dot];
	}
}
- (void)cmdToggleTag:(NSMenuItem *)it
{
	NSString *n = [it representedObject]; NSArray *t = [self _targets]; BOOL all = [t count] > 0; for (NSString *p in t) if (![TFTagsOf(p) containsObject: n]) all = NO;
	for (NSString *p in t) { NSMutableArray *cur = [TFTagsOf(p) mutableCopy]; if (all) [cur removeObject: n]; else if (![cur containsObject: n]) [cur addObject: n]; TFSetTags(cur, p); }
	if (_mode == 0 && !_tag) [_icons reloadKeepingSelection]; else [self reload];
}
- (void)cmdToggleSearch:(id)s { [_toolbar setSearching: !_toolbar->searching]; if (!_toolbar->searching) { _searchStarted = NO; [self searchChanged: @""]; } }
- (void)searchChanged:(NSString *)text
{
	_filter = [text length] ? text : nil; _icons->filter = nil; _list->filter = nil; _gallery->filter = nil; _searchGen++; _searchBar->folderName = [[_url path] isEqual: @"/"] ? @"Macintosh HD" : [[_url path] lastPathComponent];
	if (!_filter) { _found = nil; [self _layout]; [self reload]; return; }
	if (_searchBar->scope == 0 && !_searchStarted) { _searchStarted = YES; _searchBar->scope = [TFPref(@"FXDefaultSearchScope", @"SCev") isEqual: @"SCcf"] ? 1 : 0; }
	[self _layout]; [NSObject cancelPreviousPerformRequestsWithTarget: self selector: @selector(_startSearch) object: nil]; [self performSelector: @selector(_startSearch) withObject: nil afterDelay: 0.25];
}
- (void)saveSearch
{
	if (!_filter) return; NSString *dir = [NSHomeDirectory() stringByAppendingPathComponent: @"Library/Saved Searches"]; [[NSFileManager defaultManager] createDirectoryAtPath: dir withIntermediateDirectories: YES attributes: nil error: NULL];
	NSString *file = [dir stringByAppendingPathComponent: [[_filter stringByReplacingOccurrencesOfString: @"/" withString: @"-"] stringByAppendingPathExtension: @"savedSearch"]]; NSDictionary *pl = @{ @"RawQuery": _filter, @"SearchCriteria": @{ @"FXScope": _searchBar->scope == 0 ? @"This Mac" : [_url path], @"FXKind": _searchBar->kind ?: @"Any" } };
	[pl writeToFile: file atomically: YES]; _searchBar->info = [NSString stringWithFormat: @"Saved as %@", [file lastPathComponent]]; [_searchBar setNeedsDisplay: YES];
}
- (void)searchScopeChanged:(NSNumber *)n { [self _startSearch]; }
- (void)_startSearch
{
	NSString *q = _filter; if (!q) return; NSString *kindF = _searchBar->kind; NSInteger gen = _searchGen; NSString *root = _searchBar->scope == 0 ? NSHomeDirectory() : [_url path]; _searchBar->info = @"Searching…"; [_searchBar setNeedsDisplay: YES]; __weak TBrowserWindowController *me = self;
	NSThread *th = [[NSThread alloc] initWithBlock: ^{ @autoreleasepool {
		NSMutableArray *toks = [NSMutableArray array]; for (NSString *w in [q componentsSeparatedByString: @" "]) if ([w length]) [toks addObject: w]; NSMutableArray *res = [NSMutableArray array]; NSFileManager *fm = [NSFileManager defaultManager]; NSMutableArray *stack = [NSMutableArray arrayWithObject: root]; NSDate *end = [NSDate dateWithTimeIntervalSinceNow: 6]; NSUInteger n = 0;
		while ([stack count] && [res count] < 3000) {
			NSString *dir = [stack lastObject]; [stack removeLastObject]; TBrowserWindowController *s = me; if (!s || s->_searchGen != gen) return;
			for (NSString *nm in [fm contentsOfDirectoryAtPath: dir error: NULL]) {
				if ([nm hasPrefix: @"."]) continue; NSString *full = [dir stringByAppendingPathComponent: nm]; n++;
				BOOL all = YES; for (NSString *tk in toks) if ([nm rangeOfString: tk options: NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch].location == NSNotFound) { all = NO; break; } if (all && kindF) { BOOL d = NO; [fm fileExistsAtPath: full isDirectory: &d]; all = [TFKindCategory(full, d && !TFIsPackage(full)) isEqual: kindF]; } if (all) [res addObject: full];
				NSDictionary *at = [fm attributesOfItemAtPath: full error: NULL]; if ([at[NSFileType] isEqual: NSFileTypeDirectory] && !([dir isEqual: root] && [nm isEqual: @"Library"] && _searchBar_skipLib(root))) [stack addObject: full]; }
			if ([end timeIntervalSinceNow] < 0) break; }
		if (getenv("FINDER_DEBUG")) NSLog(@"Finder: search %@ in %@: %lu enumerated, %lu found, gen %ld", q, root, (unsigned long)n, (unsigned long)[res count], (long)gen);
		dispatch_async(dispatch_get_main_queue(), ^{ TBrowserWindowController *s = me; if (!s || s->_searchGen != gen) return; s->_found = res; s->_searchBar->info = [NSString stringWithFormat: @"%lu result%s", (unsigned long)[res count], [res count] == 1 ? "" : "s"]; [s->_searchBar setNeedsDisplay: YES]; [s _showFound]; }); } }]; [th start];
}
static BOOL _searchBar_skipLib(NSString *root) { return [root isEqual: NSHomeDirectory()]; }
- (void)_showFound { if (_mode == 1) [_list setPaths: _found]; else if (_mode == 3) [_gallery setPaths: _found]; else [_icons setPaths: _found]; _selection = @[]; }

- (id)_view { return _mode == 1 ? (id)_list : _mode == 2 ? (id)_cols : _mode == 3 ? (id)_gallery : (id)_icons; }
- (void)_show:(NSString *)path
{
	if (_filter) { [_toolbar setSearching: NO]; _filter = nil; _found = nil; _searchStarted = NO; _searchGen++; [self _layout]; } BOOL airdrop = [path isEqual: @"airdrop://"]; BOOL recents = [path isEqual: @"recents://"]; BOOL tagged = [path hasPrefix: @"tag://"] || recents || airdrop; _tag = airdrop ? @"\1airdrop" : recents ? @"\1recents" : tagged ? [path substringFromIndex: 6] : nil; _url = [NSURL fileURLWithPath: tagged ? NSHomeDirectory() : path]; NSString *name = airdrop ? @"AirDrop" : recents ? @"Recents" : tagged ? _tag : TFDisplayName(path); [[self window] setTitle: name]; _toolbar->title = name; _toolbar->trashMode = [[_url path] isEqual: [NSHomeDirectory() stringByAppendingPathComponent: @".Trash"]]; [_toolbar setNeedsDisplay: YES];
	_toolbar->canBack = _hi > 0; _toolbar->canForward = _hi + 1 < (NSInteger)[_history count]; _sidebar->current = path; _watchedMod = 0; if (!tagged) { NSMutableArray *rf = [TFPref(@"FXRecentFolders", @[]) mutableCopy]; [rf removeObject: path]; [rf insertObject: path atIndex: 0]; while ([rf count] > 10) [rf removeLastObject]; TFSetPref(@"FXRecentFolders", rf); } if ([_tabs count]) [self _syncTabBar]; [_pathBar setPath: [_url path]]; [self reload]; [self _restoreStyleAndWindow: NO]; [self _updateStatus]; [_toolbar setNeedsDisplay: YES]; [_sidebar setNeedsDisplay: YES];
}
- (void)reload { if (_filter && _found) { [self _showFound]; return; } NSString *p = [_url path]; _icons->emptyMessage = [_tag isEqual: @"\1airdrop"] ? @"AirDrop lets you share instantly with people nearby." : nil; if (_tag) { NSArray *ps = [_tag isEqual: @"\1airdrop"] ? @[] : [_tag isEqual: @"\1recents"] ? TFRecentPaths() : TFPathsTagged(_tag); if (_mode == 1) [_list setPaths: ps]; else if (_mode == 3) [_gallery setPaths: ps]; else [_icons setPaths: ps]; _selection = @[]; [[self window] makeFirstResponder: [self _view]]; return; } if (_mode == 1) [_list setFolder: p]; else if (_mode == 2) [_cols setFolder: p]; else if (_mode == 3) [_gallery setFolder: p]; else [_icons setFolder: p]; _selection = @[]; [[self window] makeFirstResponder: [self _view]]; }
- (void)goToPath:(NSString *)path { BOOL d = NO; if (![path hasPrefix: @"tag://"] && ![path isEqual: @"recents://"] && ![path isEqual: @"airdrop://"] && (![[NSFileManager defaultManager] fileExistsAtPath: path isDirectory: &d] || !d)) return; if (_hi >= 0 && [_history[_hi] isEqual: path]) return; [_history removeObjectsInRange: NSMakeRange(_hi + 1, [_history count] - _hi - 1)]; [_history addObject: path]; _hi = [_history count] - 1; [self _show: path]; }
- (void)_setMode:(NSInteger)m { BOOL changed = m != _mode; _mode = m; [self _updateStatus]; if (changed) [self _scheduleBoundsSave]; _toolbar->mode = m; [_icons setHidden: m != 0]; [_list setHidden: m != 1]; [_cols setHidden: m != 2]; [_gallery setHidden: m != 3]; [self reload]; [_toolbar setNeedsDisplay: YES]; }  /* the column and gallery views come later: the icon view stands in */
/* navigation */
- (void)cmdBack:(id)s { if (_hi > 0) { _hi--; [self _show: _history[_hi]]; } }
- (void)cmdForward:(id)s { if (_hi + 1 < (NSInteger)[_history count]) { _hi++; [self _show: _history[_hi]]; } }
- (void)cmdOpenParent:(id)s { [self goToPath: [[_url path] stringByDeletingLastPathComponent]]; }
- (void)cmdGoHome:(id)s { [self goToPath: NSHomeDirectory()]; }
- (void)cmdGoToDesktop:(id)s { [self goToPath: [NSHomeDirectory() stringByAppendingPathComponent: @"Desktop"]]; }
- (void)cmdGoToDocuments:(id)s { [self goToPath: [NSHomeDirectory() stringByAppendingPathComponent: @"Documents"]]; }
- (void)cmdGoToDownloads:(id)s { [self goToPath: [NSHomeDirectory() stringByAppendingPathComponent: @"Downloads"]]; }
- (void)cmdGoToApplications:(id)s { [self goToPath: @"/Applications"]; }
- (void)cmdGoToICloud:(id)s { NSString *p = [NSHomeDirectory() stringByAppendingPathComponent: @"Library/Mobile Documents/com~apple~CloudDocs"]; [[NSFileManager defaultManager] createDirectoryAtPath: p withIntermediateDirectories: YES attributes: nil error: NULL]; [self goToPath: p]; }
- (void)cmdGoToICloudProviders:(id)s { [self cmdGoToICloud: s]; }
- (void)cmdGoToAirDrop:(id)s { [self goToPath: @"airdrop://"]; }
- (void)cmdGoToNetwork:(id)s { [self goToPath: @"/Volumes"]; }
- (void)cmdGoToAllMyFiles:(id)s { [self goToPath: @"recents://"]; }
- (void)cmdConnectToServer:(id)s
{
	__weak TBrowserWindowController *me = self;
	TFConnectToServer(TFPref(@"LastServer", @"smb://"), ^(NSString *a) { TBrowserWindowController *w = me; if (!w || ![a length]) return; if ([a hasPrefix: @"/"]) [w goToPath: a]; else [w _connectServer: a user: @"" password: @""]; });
}
- (void)_connectServer:(NSString *)address user:(NSString *)user password:(NSString *)pw
{
	TFSetPref(@"LastServer", address); NSURL *u = [NSURL URLWithString: address]; NSString *scheme = [[u scheme] lowercaseString], *host = [u host], *path = [[u path] length] ? [u path] : @"/"; if (![host length]) { NSBeep(); return; }
	NSString *name = [[[path lastPathComponent] length] ? [path lastPathComponent] : host stringByReplacingOccurrencesOfString: @"/" withString: @""]; NSString *mnt = [@"/Volumes" stringByAppendingPathComponent: name]; [[NSFileManager defaultManager] createDirectoryAtPath: mnt withIntermediateDirectories: YES attributes: nil error: NULL];
	NSString *login = [user length] ? user : ([u user] ?: NSUserName()); NSString *secret = [pw length] ? [@":" stringByAppendingString: pw] : ([u password] ? [@":" stringByAppendingString: [u password]] : @"");
	NSTask *t = [[NSTask alloc] init]; if ([scheme isEqual: @"nfs"]) { [t setLaunchPath: @"/sbin/mount"]; [t setArguments: @[ @"-t", @"nfs", [NSString stringWithFormat: @"%@:%@", host, path], mnt ]]; }
	else if ([scheme isEqual: @"smb"] || [scheme isEqual: @"cifs"]) { [t setLaunchPath: @"/usr/sbin/mount_smbfs"]; [t setArguments: @[ @"-N", [NSString stringWithFormat: @"//%@%@@%@%@", login, secret, host, path], mnt ]]; } else { NSBeep(); return; }
	@try { [t launch]; [t waitUntilExit]; } @catch (NSException *x) {}
	if ([t terminationStatus] == 0) [self goToPath: mnt]; else { rmdir([mnt fileSystemRepresentation]); NSAlert *e = [[NSAlert alloc] init]; [e setMessageText: @"The server could not be connected."]; [e setInformativeText: @"Check the address, the name and the password and try again."]; [e runModal]; }
}
- (void)cmdGoToUtilities:(id)s { [self goToPath: @"/Applications/Utilities"]; }
- (void)cmdGoToComputer:(id)s { [self goToPath: @"/"]; }
- (void)cmdGoToUserLibrary:(id)s { [self goToPath: [NSHomeDirectory() stringByAppendingPathComponent: @"Library"]]; }
- (void)cmdOpen:(id)s { for (NSString *p in _selection) [self iconViewOpenItem: p]; }
- (void)cmdOpenWithDownArrow:(id)s { [self cmdOpen: s]; }
- (void)cmdViewAsIcons:(id)s { [self _setMode: 0]; }
- (void)cmdViewAsList:(id)s { [self _setMode: 1]; }
- (void)cmdViewAsColumns:(id)s { [self _setMode: 2]; }
- (void)cmdViewAsGallery:(id)s { [self _setMode: 3]; }
- (void)cmdTogglePathBar:(id)s { [_pathBar setHidden: ![_pathBar isHidden]]; [self _layout]; }
- (void)cmdToggleSidebar:(id)s { [_sidebar setHidden: ![_sidebar isHidden]]; [self _layout]; }
- (void)_layout
{
	NSRect b = [[[self window] contentView] bounds]; CGFloat W = b.size.width, H = b.size.height, sw = [_sidebar isHidden] ? 0 : 238, pb = [_pathBar isHidden] ? 0 : 30, sb = _showStatus ? 28 : 0;
	NSRect (^R)(CGFloat, CGFloat, CGFloat, CGFloat) = ^NSRect(CGFloat x, CGFloat top, CGFloat w, CGFloat h) { return NSMakeRect(x, H - top - h, w, h); };
	[_sidebar setFrame: R(0, 0, sw, H)]; [_toolbar setFrame: R(sw, 0, W - sw, 52)]; BOOL showTabs = [_tabs count] > 1 || _forceTabBar; CGFloat tbh = showTabs ? 28 : 0; [_tabBar setHidden: !showTabs]; [_tabBar setFrame: R(sw, 52, W - sw, tbh)]; BOOL srch = _filter != nil; CGFloat sbh = srch ? 34 : 0; [_searchBar setHidden: !srch]; [_searchBar setFrame: R(sw, 52 + tbh, W - sw, sbh)]; NSRect c = R(sw, 52 + tbh + sbh, W - sw, H - 52 - tbh - sbh - pb - sb); [_status setHidden: !_showStatus]; [_status setFrame: R(sw, H - pb - sb, W - sw, sb)]; BOOL pane = _showPane && _mode != 2 && _mode != 3; if (!_preview) { _preview = [[TPreviewPane alloc] initWithFrame: NSZeroRect]; [[[self window] contentView] addSubview: _preview positioned: NSWindowBelow relativeTo: _trim]; } [_preview setHidden: !pane]; if (pane) { CGFloat pw = 310; [_preview setFrame: NSMakeRect(NSMaxX(c) - pw, c.origin.y, pw, c.size.height)]; c.size.width -= pw; } [_icons setFrame: c]; [_list setFrame: c]; [_cols setFrame: c]; [_gallery setFrame: c]; [_pathBar setFrame: R(sw, H - pb, W - sw, pb)]; [_trim setFrame: b];
	for (NSView *v in @[ _sidebar, _toolbar, _icons, _list, _cols, _gallery, _pathBar, _status, _searchBar, _tabBar, _trim ]) [v setNeedsDisplay: YES];
}
/* what the file operations act on */
- (NSArray *)_targets { return [_selection count] ? _selection : @[]; }
- (void)_changed:(NSString *)selectPath { [self reload]; (void)selectPath; for (TBrowserWindowController *c in gBrowsers) if (c != self) { NSString *p = [c->_url path]; [c reload]; (void)p; } }
/* the Trash: what was moved in remembers where it came from (the Mac keeps that in the .DS_Store of the Trash; here a plist beside the items) */
static NSString *PutBackFile(void) { return [TrashPath() stringByAppendingPathComponent: @".wsbsd-putback.plist"]; }
static void RememberOrigin(NSString *inTrash, NSString *origin) { NSMutableDictionary *d = [[NSDictionary dictionaryWithContentsOfFile: PutBackFile()] mutableCopy] ?: [NSMutableDictionary dictionary]; d[[inTrash lastPathComponent]] = origin; [d writeToFile: PutBackFile() atomically: YES]; }
- (BOOL)_confirm:(NSString *)msg info:(NSString *)info button:(NSString *)b { NSAlert *a = [[NSAlert alloc] init]; [a setMessageText: msg]; [a setInformativeText: info]; [a addButtonWithTitle: b]; [a addButtonWithTitle: @"Cancel"]; return [a runModal] == NSAlertFirstButtonReturn; }
- (void)cmdEmptyTrashSilently:(id)s
{
	NSFileManager *fm = [NSFileManager defaultManager]; for (NSString *n in [fm contentsOfDirectoryAtPath: TrashPath() error: NULL]) [fm removeItemAtPath: [TrashPath() stringByAppendingPathComponent: n] error: NULL];
	[self _changed: nil]; [_sidebar setNeedsDisplay: YES];
}
- (void)cmdEmptyTrash:(id)s { if (!TFPrefBool(@"WarnOnEmptyTrash", YES)) { [self cmdEmptyTrashSilently: s]; return; } if ([self _confirm: @"Are you sure you want to permanently erase the items in the Trash?" info: @"You can’t undo this action." button: @"Empty Trash"]) [self cmdEmptyTrashSilently: s]; }
- (void)cmdDeleteImmediately:(id)s
{
	if (![[self _targets] count] || ![self _confirm: @"Are you sure you want to permanently erase the selected items?" info: @"You can’t undo this action." button: @"Delete"]) return;
	for (NSString *p in [self _targets]) [[NSFileManager defaultManager] removeItemAtPath: p error: NULL]; [self _changed: nil];
}
- (void)cmdDuplicateExactly:(id)s { [self cmdDuplicate: s]; }
- (void)cmdQuickLook:(id)s { NSArray *t = [self _targets]; if ([t count]) TFOpenQuickLook(t[0]); else if (_url) TFOpenQuickLook([_url path]); }
/* tabs: each keeps its folder, history and view; the views of the window show the one selected */
- (NSMutableDictionary *)_tabState { return [@{ @"url": _url ?: [NSURL fileURLWithPath: NSHomeDirectory()], @"history": [_history mutableCopy] ?: [NSMutableArray array], @"hi": @(_hi), @"mode": @(_mode) } mutableCopy]; }
- (void)_syncTabBar { NSMutableArray *t = [NSMutableArray array]; for (NSUInteger i = 0; i < [_tabs count]; i++) { NSURL *u = (NSInteger)i == _tabIx ? _url : _tabs[i][@"url"]; NSString *p = [u path]; [t addObject: [p isEqual: @"/"] ? @"Macintosh HD" : [p lastPathComponent]]; } _tabBar->titles = t; _tabBar->selected = _tabIx; [_tabBar setNeedsDisplay: YES]; [self _layout]; }
- (void)_loadTab:(NSInteger)i
{
	NSDictionary *st = _tabs[i]; _tabIx = i; _history = [st[@"history"] mutableCopy]; _hi = [st[@"hi"] integerValue]; NSInteger m = [st[@"mode"] integerValue]; _mode = m; _toolbar->mode = m; [_icons setHidden: m != 0]; [_list setHidden: m != 1]; [_cols setHidden: m != 2]; [_gallery setHidden: m != 3];
	NSString *p = [st[@"url"] path]; [self _show: _hi >= 0 && _hi < (NSInteger)[_history count] ? _history[_hi] : p]; [self _syncTabBar];
}
- (void)cmdNewTab:(id)s
{
	if (![_tabs count]) [_tabs addObject: [self _tabState]]; else _tabs[_tabIx] = [self _tabState];
	NSMutableDictionary *n = [self _tabState]; [_tabs insertObject: n atIndex: _tabIx + 1]; [self _loadTab: _tabIx + 1];
}
- (void)selectTabAt:(NSNumber *)n { NSInteger i = [n integerValue]; if (i == _tabIx || i < 0 || i >= (NSInteger)[_tabs count]) return; _tabs[_tabIx] = [self _tabState]; [self _loadTab: i]; }
- (void)closeTabAt:(NSNumber *)n { NSInteger i = [n integerValue]; if ([_tabs count] < 2 || i < 0 || i >= (NSInteger)[_tabs count]) return; if (i == _tabIx) { [_tabs removeObjectAtIndex: i]; [self _loadTab: MIN(i, (NSInteger)[_tabs count] - 1)]; } else { _tabs[_tabIx] = [self _tabState]; [_tabs removeObjectAtIndex: i]; _tabIx = i < _tabIx ? _tabIx - 1 : _tabIx; [self _syncTabBar]; } }
- (BOOL)windowShouldClose:(id)w { if ([_tabs count] > 1) { [self closeTabAt: @(_tabIx)]; return NO; } return YES; }
- (void)cmdOpenInNewTab:(id)s { for (NSString *p in [self _targets]) { BOOL d = NO; [[NSFileManager defaultManager] fileExistsAtPath: p isDirectory: &d]; if (d) { [self cmdNewTab: nil]; [self goToPath: p]; } } }
- (void)cmdCompress:(id)s { NSArray *t = [self _targets]; if (![t count]) return; NSString *base = [t count] == 1 ? [t[0] lastPathComponent] : @"Archive"; NSString *zip = UniquePath([_url path], base, @"zip"); NSMutableArray *args = [NSMutableArray arrayWithObjects: @"-a", @"-cf", zip, nil]; for (NSString *p in t) { [args addObject: @"-C"]; [args addObject: [p stringByDeletingLastPathComponent]]; [args addObject: [p lastPathComponent]]; } NSTask *tk = [[NSTask alloc] init]; [tk setLaunchPath: @"/usr/bin/tar"]; [tk setArguments: args]; @try { [tk launch]; [tk waitUntilExit]; } @catch (NSException *x) {} [self _changed: nil]; }
- (void)cmdShowOriginal:(id)s { for (NSString *p in [self _targets]) { NSString *o = [[NSFileManager defaultManager] destinationOfSymbolicLinkAtPath: p error: NULL]; if (o) { if (![o hasPrefix: @"/"]) o = [[p stringByDeletingLastPathComponent] stringByAppendingPathComponent: o]; [self goToPath: [o stringByDeletingLastPathComponent]]; } } }
- (void)cmdMakeAlias:(id)s { NSFileManager *fm = [NSFileManager defaultManager]; for (NSString *p in [self _targets]) { NSString *dest = UniquePath([p stringByDeletingLastPathComponent], [[p lastPathComponent] stringByAppendingString: @" alias"], nil); [fm createSymbolicLinkAtPath: dest withDestinationPath: p error: NULL]; } [self _changed: nil]; }
- (void)cmdCopyAsPathname:(id)s { NSPasteboard *pb = [NSPasteboard generalPasteboard]; [pb declareTypes: @[ NSStringPboardType ] owner: nil]; [pb setString: [[self _targets] componentsJoinedByString: @"\n"] forType: NSStringPboardType]; }
- (void)copy:(id)s { NSPasteboard *pb = [NSPasteboard generalPasteboard]; [pb declareTypes: @[ NSFilenamesPboardType ] owner: nil]; [pb setPropertyList: [self _targets] forType: NSFilenamesPboardType]; }
/* undo: every change of the files is a list of steps (move, copy, mkdir) that can be run backwards and forwards again */
- (void)_record:(NSString *)name ops:(NSArray *)ops { if (!_undo) { _undo = [NSMutableArray array]; _redo = [NSMutableArray array]; } [_undo addObject: @{ @"name": name, @"ops": ops }]; [_redo removeAllObjects]; }
- (void)_run:(NSDictionary *)e reverse:(BOOL)rev
{
	NSFileManager *fm = [NSFileManager defaultManager]; NSArray *ops = e[@"ops"]; if (rev) ops = [[ops reverseObjectEnumerator] allObjects];
	for (NSDictionary *o in ops) {
		NSString *t = o[@"t"], *a = o[@"a"], *b = o[@"b"];
		if ([t isEqual: @"move"]) { if (rev) [fm moveItemAtPath: b toPath: a error: NULL]; else [fm moveItemAtPath: a toPath: b error: NULL]; }
		else if ([t isEqual: @"copy"]) { if (rev) [fm removeItemAtPath: b error: NULL]; else [fm copyItemAtPath: a toPath: b error: NULL]; }
		else if ([t isEqual: @"mkdir"]) { if (rev) [fm removeItemAtPath: a error: NULL]; else [fm createDirectoryAtPath: a withIntermediateDirectories: YES attributes: nil error: NULL]; }
	}
	[self _changed: nil]; [_sidebar setNeedsDisplay: YES];
}
- (void)undo:(id)s { NSDictionary *e = [_undo lastObject]; if (!e) return; [_undo removeLastObject]; [self _run: e reverse: YES]; [_redo addObject: e]; }
- (void)redo:(id)s { NSDictionary *e = [_redo lastObject]; if (!e) return; [_redo removeLastObject]; [self _run: e reverse: NO]; [_undo addObject: e]; }
- (void)cmdNewFolder:(id)s { if ([s isKindOfClass: [NSMenuItem class]] && [[s title] hasPrefix: @"New Folder with"]) { [self cmdNewFolderWithSelection: s]; return; } NSString *p = UniquePath([_url path], @"untitled folder", nil); NSError *e = nil; if ([[NSFileManager defaultManager] createDirectoryAtPath: p withIntermediateDirectories: NO attributes: nil error: &e]) { [self _record: @"New Folder" ops: @[ @{ @"t": @"mkdir", @"a": p } ]]; [self reload]; _selection = @[ p ]; [self _renamePath: p]; } else NSBeep(); }
- (void)cmdNewFolderWithSelection:(id)s
{
	NSArray *t = [self _targets]; if (![t count]) return; NSFileManager *fm = [NSFileManager defaultManager]; NSString *dir = UniquePath([_url path], @"New Folder With Items", nil); NSMutableArray *ops = [NSMutableArray arrayWithObject: @{ @"t": @"mkdir", @"a": dir }];
	if (![fm createDirectoryAtPath: dir withIntermediateDirectories: NO attributes: nil error: NULL]) return;
	for (NSString *p in t) { NSString *to = [dir stringByAppendingPathComponent: [p lastPathComponent]]; if ([fm moveItemAtPath: p toPath: to error: NULL]) [ops addObject: @{ @"t": @"move", @"a": p, @"b": to }]; }
	[self _record: @"New Folder With Items" ops: ops]; [self _changed: nil];
}
- (void)cmdMoveToTrash:(id)s
{
	NSFileManager *fm = [NSFileManager defaultManager]; [fm createDirectoryAtPath: TrashPath() withIntermediateDirectories: YES attributes: nil error: NULL]; NSMutableArray *ops = [NSMutableArray array];
	for (NSString *p in [self _targets]) { NSString *dest = UniquePath(TrashPath(), [[p lastPathComponent] stringByDeletingPathExtension], [p pathExtension]); if ([fm moveItemAtPath: p toPath: dest error: NULL]) { RememberOrigin(dest, p); [ops addObject: @{ @"t": @"move", @"a": p, @"b": dest }]; } }
	if ([ops count]) [self _record: @"Move to Trash" ops: ops]; [self _changed: nil]; [_sidebar setNeedsDisplay: YES];
}
- (void)cmdPutBack:(id)s
{
	NSFileManager *fm = [NSFileManager defaultManager]; NSMutableDictionary *d = [[NSDictionary dictionaryWithContentsOfFile: PutBackFile()] mutableCopy] ?: [NSMutableDictionary dictionary]; NSMutableArray *ops = [NSMutableArray array];
	for (NSString *p in [self _targets]) { NSString *o = d[[p lastPathComponent]]; if (!o) continue; [fm createDirectoryAtPath: [o stringByDeletingLastPathComponent] withIntermediateDirectories: YES attributes: nil error: NULL]; NSString *to = [fm fileExistsAtPath: o] ? UniquePath([o stringByDeletingLastPathComponent], [[o lastPathComponent] stringByDeletingPathExtension], [o pathExtension]) : o; if ([fm moveItemAtPath: p toPath: to error: NULL]) { [d removeObjectForKey: [p lastPathComponent]]; [ops addObject: @{ @"t": @"move", @"a": p, @"b": to }]; } }
	[d writeToFile: PutBackFile() atomically: YES]; if ([ops count]) [self _record: @"Put Back" ops: ops]; [self _changed: nil]; [_sidebar setNeedsDisplay: YES];
}
- (void)cmdDuplicate:(id)s { NSArray *t = [self _targets]; if (![t count]) return; __weak TBrowserWindowController *me = self; TFCopyItems(t, [_url path], NO, ^(NSArray *ops) { TBrowserWindowController *x = me; if (!x) return; if ([ops count]) [x _record: @"Duplicate" ops: ops]; [x _changed: nil]; }); }
- (void)cut:(id)s { [self copy: s]; _cutPaths = [[self _targets] copy]; }
- (void)_pasteMoving:(BOOL)move
{
	NSArray *files = [[NSPasteboard generalPasteboard] propertyListForType: NSFilenamesPboardType]; if (![files count]) return; BOOL cut = move || (_cutPaths && [_cutPaths isEqual: files]); _cutPaths = nil; __weak TBrowserWindowController *me = self;
	NSMutableArray *todo = [NSMutableArray array]; for (NSString *p in files) { if (cut && [[p stringByDeletingLastPathComponent] isEqual: [_url path]]) continue; [todo addObject: p]; } if (![todo count]) return;
	TFCopyItems(todo, [_url path], cut, ^(NSArray *ops) { TBrowserWindowController *s = me; if (!s) return; if ([ops count]) [s _record: cut ? @"Move" : @"Paste" ops: ops]; [s _changed: nil]; });
}
- (void)paste:(id)s { [self _pasteMoving: NO]; }
- (void)cmdMoveItemsHere:(id)s { [self _pasteMoving: YES]; }
- (void)cmdPasteExactly:(id)s { [self _pasteMoving: NO]; }
- (void)_commitRename:(NSString *)path to:(NSString *)nn
{
	if (![nn length] || [nn containsString: @"/"] || [nn isEqual: [path lastPathComponent]]) return; NSString *dest = [[path stringByDeletingLastPathComponent] stringByAppendingPathComponent: nn]; NSString *oe = [path pathExtension], *ne = [dest pathExtension];
	if ([oe length] && ![oe isEqual: ne] && TFPrefBool(@"FXEnableExtensionChangeWarning", YES)) { NSAlert *w = [[NSAlert alloc] init]; [w setMessageText: [NSString stringWithFormat: @"Are you sure you want to change the extension from “.%@” to “%@”?", oe, [ne length] ? [@"." stringByAppendingString: ne] : @"nothing"]]; [w setInformativeText: @"If you make this change, your document may open in a different application."]; [w addButtonWithTitle: [NSString stringWithFormat: @"Keep .%@", oe]]; [w addButtonWithTitle: [ne length] ? [@"Use ." stringByAppendingString: ne] : @"Use no extension"]; if ([w runModal] == NSAlertFirstButtonReturn) dest = [[dest stringByDeletingPathExtension] stringByAppendingPathExtension: oe]; }
	if ([[NSFileManager defaultManager] fileExistsAtPath: dest]) { NSAlert *w = [[NSAlert alloc] init]; [w setMessageText: [NSString stringWithFormat: @"The name “%@” is already taken. Please choose a different name.", [dest lastPathComponent]]]; [w runModal]; return; }
	if ([[NSFileManager defaultManager] moveItemAtPath: path toPath: dest error: NULL]) { [self _record: @"Rename" ops: @[ @{ @"t": @"move", @"a": path, @"b": dest } ]]; [self _changed: dest]; }
}
- (void)iconViewRename:(NSString *)path to:(NSString *)name { [self _commitRename: path to: name]; }
- (void)_renamePath:(NSString *)path { id v = [self _view]; if ([v respondsToSelector: @selector(beginRename:)] && [v beginRename: path]) return; NSAlert *a = [[NSAlert alloc] init]; [a setMessageText: @"Rename"]; NSTextField *f = [[NSTextField alloc] initWithFrame: NSMakeRect(0, 0, 260, 24)]; [f setStringValue: [path lastPathComponent]]; [a setAccessoryView: f]; [a addButtonWithTitle: @"OK"]; [a addButtonWithTitle: @"Cancel"]; if ([a runModal] == NSAlertFirstButtonReturn) [self _commitRename: path to: [f stringValue]]; }
- (void)cmdGoTo:(id)s
{
	if (getenv("FINDER_DEBUG")) NSLog(@"cmdGoTo");
	__weak TBrowserWindowController *me = self;
	TFAsk(@"Go to the folder:", @"", @[ @{ @"label": @"Path", @"value": @"/" } ], @"Go", ^(NSArray *v) { TBrowserWindowController *w = me; if (!w || !v) return; NSString *p = [[v[0] stringByExpandingTildeInPath] copy]; BOOL d = NO;
		if ([[NSFileManager defaultManager] fileExistsAtPath: p isDirectory: &d]) [w goToPath: d ? p : [p stringByDeletingLastPathComponent]]; else { NSAlert *e = [[NSAlert alloc] init]; [e setMessageText: @"The folder can’t be found."]; [e runModal]; } });
}
- (void)cmdSetFocusToSearchField:(id)s { if (!_toolbar->searching) [_toolbar setSearching: YES]; }
- (void)cmdSearchFromToolbar:(id)s { [self cmdToggleSearch: s]; }
- (void)cmdRename:(id)s
{
	if ([_selection count] == 1) { [self _renamePath: _selection[0]]; return; } if ([_selection count] < 2) return; [self performSelector: @selector(_bulkRename) withObject: nil afterDelay: 0.1];      /* after the pop-up menu is gone, which would take the clicks of the dialog */
}
- (void)_bulkRename
{
	__weak TBrowserWindowController *me = self;
	TFBulkRename([_selection copy], ^(NSArray *changes) { NSFileManager *fm = [NSFileManager defaultManager]; if (getenv("FINDER_DEBUG")) NSLog(@"bulk rename: %@", changes); NSMutableArray *ops = [NSMutableArray array]; @try { for (NSUInteger ci = 0; ci < [changes count]; ci++) { NSArray *pr = changes[ci]; NSError *er = nil; if (![fm fileExistsAtPath: pr[1]] && [fm moveItemAtPath: pr[0] toPath: pr[1] error: &er]) { [ops addObject: @{ @"t": @"move", @"a": pr[0], @"b": pr[1] }]; if (getenv("FINDER_DEBUG")) NSLog(@"bulk rename moved %@", pr); } else if (getenv("FINDER_DEBUG")) NSLog(@"bulk rename failed %@: %@", pr, er); } } @catch (NSException *x) { NSLog(@"bulk rename exception %@ %@", x, [x reason]); }
		TBrowserWindowController *s = me; if (s && [ops count]) { [s _record: @"Rename" ops: ops]; [s _changed: nil]; } });
}
- (void)cmdShowStaticInfo:(id)s { NSArray *t = [self _targets]; if (![t count] && _url && !_tag) t = @[ [_url path] ]; for (NSString *p in t) TFOpenInfoWindow(p); }
- (void)cmdShowInfo:(id)s { [self cmdShowStaticInfo: s]; }
- (BOOL)validateMenuItem:(NSMenuItem *)i
{
	if ([[i title] isEqual: @"Open With"] && [i submenu]) return [_selection count] > 0;
	{ SEL q0 = [i action]; if ((sel_isEqual(q0, @selector(cmdShowStaticInfo:)) || sel_isEqual(q0, @selector(cmdQuickLook:))) && ![_selection count] && _url && !_tag) return YES; }      /* without a selection they are about the folder */
	{ SEL q = [i action]; if (sel_isEqual(q, @selector(cmdGroupAsFolder:)) || sel_isEqual(q, @selector(cmdOpenAltBrowse:)) || sel_isEqual(q, @selector(cmdOpenOptionBrowse:)) || sel_isEqual(q, @selector(cmdShowInspector:)) || sel_isEqual(q, @selector(cmdShowStaticInfoSummary:)) || sel_isEqual(q, @selector(cmdEditTags:)) || sel_isEqual(q, @selector(cmdCopyAsLink:)) || sel_isEqual(q, @selector(cmdEject:))) return [_selection count] > 0; if (sel_isEqual(q, @selector(cmdOpenParentAltBrowse:)) || sel_isEqual(q, @selector(cmdGoToRecent:)) || sel_isEqual(q, @selector(cmdConnectTo:)) || sel_isEqual(q, @selector(cmdSelectStartupDisk:)) || sel_isEqual(q, @selector(cmdFindFile:)) || sel_isEqual(q, @selector(cmdAlternateFindFile:)) || sel_isEqual(q, @selector(cmdNewSmartFolder:)) || sel_isEqual(q, @selector(cmdNewBurnableFolder:)) || sel_isEqual(q, @selector(cmdEjectAll:)) || sel_isEqual(q, @selector(cmdShowClipboard:))) return YES; }
	if ([i action] == @selector(cmdOpenWithApp:) || [i action] == @selector(cmdOpenWithOther:)) return [_selection count] > 0;
	SEL a = [i action]; BOOL has = [_selection count] > 0;
	if (sel_isEqual(a, @selector(cmdToggleTag:))) { BOOL all = has; for (NSString *p in _selection) if (![TFTagsOf(p) containsObject: [i representedObject]]) all = NO; [i setState: all ? NSOnState : NSOffState]; return has; }
	if (sel_isEqual(a, @selector(cmdBack:))) return _hi > 0; if (sel_isEqual(a, @selector(cmdForward:))) return _hi + 1 < (NSInteger)[_history count];
	if (sel_isEqual(a, @selector(cmdOpen:)) || sel_isEqual(a, @selector(cmdOpenWithDownArrow:)) || sel_isEqual(a, @selector(cmdMoveToTrash:)) || sel_isEqual(a, @selector(cmdDuplicate:)) || sel_isEqual(a, @selector(cmdMakeAlias:)) || sel_isEqual(a, @selector(copy:)) || sel_isEqual(a, @selector(cmdShowStaticInfo:)) || sel_isEqual(a, @selector(cmdCopyAsPathname:))) return has;
	if (sel_isEqual(a, @selector(cmdRename:))) { [i setTitle: [_selection count] > 1 ? [NSString stringWithFormat: @"Rename %lu Items…", (unsigned long)[_selection count]] : @"Rename"]; return [_selection count] >= 1; } if (sel_isEqual(a, @selector(paste:))) return [[NSPasteboard generalPasteboard] propertyListForType: NSFilenamesPboardType] != nil;
	if (sel_isEqual(a, @selector(undo:))) { NSDictionary *e = [_undo lastObject]; [i setTitle: e ? [@"Undo " stringByAppendingString: e[@"name"]] : @"Undo"]; return e != nil; }
	if (sel_isEqual(a, @selector(redo:))) { NSDictionary *e = [_redo lastObject]; [i setTitle: e ? [@"Redo " stringByAppendingString: e[@"name"]] : @"Redo"]; return e != nil; }
	if (sel_isEqual(a, @selector(cut:)) || sel_isEqual(a, @selector(cmdNewFolderWithSelection:)) || sel_isEqual(a, @selector(cmdArchive:)) || sel_isEqual(a, @selector(cmdSlideshow:)) || sel_isEqual(a, @selector(cmdShare:)) || sel_isEqual(a, @selector(cmdShowPackageContents:))) return has;
	if (sel_isEqual(a, @selector(cmdNewFolder:)) && [i isKindOfClass: [NSMenuItem class]] && [[i title] hasPrefix: @"New Folder with"]) return has;
	if (sel_isEqual(a, @selector(cmdIncreaseIconSize:)) || sel_isEqual(a, @selector(cmdDecreaseIconSize:))) return _mode == 0;
	if (sel_isEqual(a, @selector(cmdMoveItemsHere:)) || sel_isEqual(a, @selector(cmdPasteExactly:))) return [[NSPasteboard generalPasteboard] propertyListForType: NSFilenamesPboardType] != nil;
	if (sel_isEqual(a, @selector(cmdPutBack:))) return has && [[[_url path] stringByStandardizingPath] hasPrefix: TrashPath()];
	if (sel_isEqual(a, @selector(cmdDeleteImmediately:)) || sel_isEqual(a, @selector(cmdCompress:)) || sel_isEqual(a, @selector(cmdQuickLook:)) || sel_isEqual(a, @selector(cmdOpenInNewTab:)) || sel_isEqual(a, @selector(cmdDuplicateExactly:)) || sel_isEqual(a, @selector(cmdShowOriginal:))) return has;
	if (sel_isEqual(a, @selector(cmdEmptyTrash:)) || sel_isEqual(a, @selector(cmdEmptyTrashSilently:))) return [[[NSFileManager defaultManager] contentsOfDirectoryAtPath: TrashPath() error: NULL] count] > 0;
	if (sel_isEqual(a, @selector(cmdAddToSidebar:))) { BOOL ok = NO; for (NSString *p in _selection) { BOOL d = NO; [[NSFileManager defaultManager] fileExistsAtPath: p isDirectory: &d]; if (d) ok = YES; } return ok; }
	if (sel_isEqual(a, @selector(cmdTogglePreviewPane:))) { [i setTitle: _showPane ? @"Hide Preview" : @"Show Preview"]; return _mode != 2 && _mode != 3; }
	if (sel_isEqual(a, @selector(cmdToggleStatusBar:))) { [i setTitle: _showStatus ? @"Hide Status Bar" : @"Show Status Bar"]; return YES; }
	if (sel_isEqual(a, @selector(cmdArrangeByNone:)) || sel_isEqual(a, @selector(cmdArrangeByName:)) || sel_isEqual(a, @selector(cmdArrangeByKind:)) || sel_isEqual(a, @selector(cmdArrangeByDateModified:)) || sel_isEqual(a, @selector(cmdArrangeByDateCreated:)) || sel_isEqual(a, @selector(cmdArrangeBySize:)) || sel_isEqual(a, @selector(cmdArrangeByFinderTags:))) { NSString *k = _icons->_arrange; NSDictionary *m = @{ @"cmdArrangeByName:": @"name", @"cmdArrangeByKind:": @"kind", @"cmdArrangeByDateModified:": @"modified", @"cmdArrangeByDateCreated:": @"created", @"cmdArrangeBySize:": @"size", @"cmdArrangeByFinderTags:": @"tags" }; NSString *mine = m[NSStringFromSelector(a)]; [i setState: (mine ? [mine isEqual: k] : ![k length]) ? NSOnState : NSOffState]; return _mode != 1; }
	if (sel_isEqual(a, @selector(cmdTogglePathBar:))) { [i setTitle: [_pathBar isHidden] ? @"Show Path Bar" : @"Hide Path Bar"]; return YES; } if (sel_isEqual(a, @selector(cmdToggleSidebar:))) { [i setTitle: [_sidebar isHidden] ? @"Show Sidebar" : @"Hide Sidebar"]; return YES; }
	if (sel_isEqual(a, @selector(cmdViewAsIcons:))) { [i setState: _mode == 0]; return YES; } if (sel_isEqual(a, @selector(cmdViewAsList:))) { [i setState: _mode == 1]; return YES; }
	return [self respondsToSelector: a];
}
/* delegates */
/* a smart folder (.savedSearch, the Mac's format: RawQuery and SearchCriteria with FXScope and FXKind) opens as the search it holds */
- (void)openSavedSearch:(NSString *)path
{
	NSDictionary *pl = [NSDictionary dictionaryWithContentsOfFile: path]; NSString *q = pl[@"RawQuery"]; if (![q length]) { NSBeep(); return; } NSDictionary *cr = pl[@"SearchCriteria"]; NSString *scope = cr[@"FXScope"], *kind = cr[@"FXKind"];
	if ([scope length] && ![scope isEqual: @"This Mac"] && [scope hasPrefix: @"/"]) [self goToPath: scope];
	[_toolbar setSearching: YES]; [_toolbar->search setStringValue: q]; _searchStarted = YES; _searchBar->scope = ([scope length] && ![scope isEqual: @"This Mac"]) ? 1 : 0; _searchBar->kind = ([kind length] && ![kind isEqual: @"Any"]) ? kind : nil; [self searchChanged: q];
}
- (void)iconViewOpenItem:(NSString *)path { if ([[[path pathExtension] lowercaseString] isEqual: @"savedsearch"]) { [self openSavedSearch: path]; return; } BOOL d = NO; [[NSFileManager defaultManager] fileExistsAtPath: path isDirectory: &d]; if (d && !TFIsPackage(path)) [self goToPath: path]; else TFOpenPath(path); }
- (void)iconViewSelectionChanged:(NSArray *)paths { _selection = paths; if ([paths count] == 1) [_pathBar setPath: paths[0]]; else [_pathBar setPath: [_url path]]; [self _updateStatus]; [self _refreshPane]; }
- (void)_updateStatus
{
	if (!_showStatus) return; NSFileManager *fm = [NSFileManager defaultManager]; NSUInteger n = 0; if (_tag) n = [([_tag isEqual: @"\1recents"] ? TFRecentPaths() : TFPathsTagged(_tag)) count]; else for (NSString *s in [fm contentsOfDirectoryAtPath: [_url path] error: NULL]) if (![s hasPrefix: @"."]) n++;
	unsigned long long free = [[fm attributesOfFileSystemForPath: [_url path] error: NULL][NSFileSystemFreeSize] unsignedLongLongValue]; NSString *avail = free >= 1000000000ULL ? [NSString stringWithFormat: @"%.2f GB", free / 1e9] : TFSizeString(free);
	_status->text = [_selection count] ? [NSString stringWithFormat: @"%lu of %lu selected, %@ available", (unsigned long)[_selection count], (unsigned long)n, avail] : [NSString stringWithFormat: @"%lu item%s, %@ available", (unsigned long)n, n == 1 ? "" : "s", avail]; _status->showSlider = _mode == 0; _status->value = ([_icons iconSize] - 16) / 240.0; [_status setNeedsDisplay: YES];
}
- (void)sliderChanged:(NSNumber *)v { [_icons setIconSize: 16 + round([v doubleValue] * 240 / 8) * 8]; }
/* View > Show Status Bar, Sort By, Clean Up */
- (void)cmdToggleStatusBar:(id)s { _showStatus = !_showStatus; [self _layout]; [self _updateStatus]; }
- (void)_arrange:(NSString *)k { if (_mode == 1) { [self reload]; return; } [_icons arrangeBy: k]; }
- (void)cmdArrangeByNone:(id)s { [self _arrange: nil]; }
- (void)cmdArrangeByName:(id)s { [self _arrange: @"name"]; }
- (void)cmdArrangeByKind:(id)s { [self _arrange: @"kind"]; }
- (void)cmdArrangeByDateModified:(id)s { [self _arrange: @"modified"]; }
- (void)cmdArrangeByDateCreated:(id)s { [self _arrange: @"created"]; }
- (void)cmdArrangeBySize:(id)s { [self _arrange: @"size"]; }
- (void)cmdArrangeByFinderTags:(id)s { [self _arrange: @"tags"]; }
- (void)cmdIncreaseIconSize:(id)s { [_icons setIconSize: [_icons iconSize] + 16]; [self _updateStatus]; }
- (void)cmdDecreaseIconSize:(id)s { [_icons setIconSize: [_icons iconSize] - 16]; [self _updateStatus]; }
- (void)cmdArchive:(id)s { [self cmdCompress: s]; }
- (void)cmdSlideshow:(id)s { [self cmdQuickLook: s]; }
/* the Share menu: the services of the Mac; each one opens the file in the application of that name when it is installed, AirDrop goes to the AirDrop window */
/* Quick Action Rotate Left: the picture turned a quarter to the left, written back in its own format */
- (void)cmdRotateLeft:(id)s
{
	for (NSString *p in [_selection copy]) { NSImage *src = [[NSImage alloc] initWithContentsOfFile: p]; if (!src) continue; NSBitmapImageRep *rep = nil; for (NSImageRep *r in [src representations]) if ([r isKindOfClass: [NSBitmapImageRep class]]) { rep = (NSBitmapImageRep *)r; break; } if (!rep) continue;
		NSInteger w = [rep pixelsWide], h = [rep pixelsHigh]; NSBitmapImageRep *out = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes: NULL pixelsWide: h pixelsHigh: w bitsPerSample: 8 samplesPerPixel: 4 hasAlpha: YES isPlanar: NO colorSpaceName: NSDeviceRGBColorSpace bytesPerRow: h * 4 bitsPerPixel: 32]; if (!out) continue;
		for (NSInteger y = 0; y < h; y++) for (NSInteger x = 0; x < w; x++) { NSUInteger px[4] = { 0, 0, 0, 255 }; [rep getPixel: px atX: x y: y]; NSInteger nx = y, ny = w - 1 - x; NSUInteger o[4]; for (int k = 0; k < 4; k++) o[k] = px[k]; if ([rep samplesPerPixel] < 4) { o[3] = 255; if ([rep samplesPerPixel] < 3) { o[1] = o[2] = o[0]; } } [out setPixel: o atX: nx y: ny]; }
		NSString *e = [[p pathExtension] lowercaseString]; NSBitmapImageFileType t = [e hasPrefix: @"jp"] ? NSJPEGFileType : [e hasPrefix: @"ti"] ? NSTIFFFileType : [e isEqual: @"gif"] ? NSGIFFileType : [e isEqual: @"bmp"] ? NSBMPFileType : NSPNGFileType;
		NSData *d = [out representationUsingType: t properties: @{}]; if (d) [d writeToFile: p atomically: YES]; }
	[self _changed: nil];
}
- (void)cmdShare:(id)s { if (![[self _targets] count]) return; NSRect r = [_toolbar buttonRect: 0]; TFShowSharePopover([self _targets], r, _toolbar, self); }
- (void)_shareVia:(NSMenuItem *)it
{
	NSString *n = [it title]; if ([n isEqual: @"AirDrop"]) { [self cmdGoToAirDrop: nil]; return; }
	for (NSString *d in @[ @"/Applications", @"/System/Applications" ]) { NSString *a = [[d stringByAppendingPathComponent: n] stringByAppendingPathExtension: @"app"]; if ([[NSFileManager defaultManager] fileExistsAtPath: a]) { for (NSString *f in [self _targets]) [[NSWorkspace sharedWorkspace] openFile: f withApplication: a]; return; } }
	NSBeep();
}
- (void)cmdAddToSidebar:(id)s { NSMutableArray *f = [TFPref(@"SidebarFavorites", @[]) mutableCopy]; for (NSString *p in [self _targets]) { BOOL d = NO; [[NSFileManager defaultManager] fileExistsAtPath: p isDirectory: &d]; if (d && ![f containsObject: p]) [f addObject: p]; } TFSetPref(@"SidebarFavorites", f); }
- (void)cmdToggleViewOptions:(id)s { if (_mode != 0) return; __weak TBrowserWindowController *me = self; TFOpenViewOptions(_icons, [[_url path] isEqual: @"/"] ? @"Macintosh HD" : [[_url path] lastPathComponent], ^{ [me _updateStatus]; }); }
- (void)toggleFullScreen:(id)s { [[self window] performZoom: s]; }
- (void)toggleTabBar:(id)s { _forceTabBar = !_forceTabBar; [_tabBar setHidden: !_forceTabBar && [_tabs count] < 2]; if (![_tabs count]) { [_tabs addObject: [self _tabState]]; _tabIx = 0; } [self _syncTabBar]; }
- (void)cmdShowPackageContents:(id)s { for (NSString *p in [self _targets]) if (TFIsPackage(p)) [self goToPath: p]; }
- (void)cmdToggleToolbar:(id)s { [_toolbar setHidden: ![_toolbar isHidden]]; }
/* the rest of the menu bar's actions (docs/desktop/Finder.menu-actions.txt) */
- (void)cmdGroupAsFolder:(id)s { [self cmdNewFolderWithSelection: s]; }
- (void)cmdNewSmartFolder:(id)s { [self cmdToggleSearch: s]; }
- (void)cmdNewBurnableFolder:(id)s { NSString *p = UniquePath([_url path], @"Untitled Burn Folder", nil); if ([[NSFileManager defaultManager] createDirectoryAtPath: p withIntermediateDirectories: NO attributes: nil error: NULL]) { [self _record: @"New Folder" ops: @[ @{ @"t": @"mkdir", @"a": p } ]]; [self reload]; } }
- (void)cmdOpenAltBrowse:(id)s { for (NSString *p in [self _targets]) { BOOL d = NO; [[NSFileManager defaultManager] fileExistsAtPath: p isDirectory: &d]; if (d && !TFIsPackage(p)) [TBrowserWindowController newBrowserWithPath: p]; else [[NSWorkspace sharedWorkspace] openFile: p]; } }
- (void)cmdOpenOptionBrowse:(id)s { [self cmdOpenAltBrowse: s]; [[self window] performClose: nil]; }
- (void)cmdOpenParentAltBrowse:(id)s { [TBrowserWindowController newBrowserWithPath: [[_url path] stringByDeletingLastPathComponent]]; }
- (void)cmdOpenWith:(id)s {}
- (void)cmdAlwaysOpenWith:(id)s {}
- (void)cmdShowInspector:(id)s { [self cmdShowStaticInfo: s]; }
- (void)cmdShowStaticInfoSummary:(id)s { [self cmdShowStaticInfo: s]; }
- (void)cmdEditTags:(id)s { NSView *v = [self _view]; NSMenu *tm = [self tagMenu]; [self _markTagMenu: tm]; TFPopupMenu(v, NSMakePoint([v bounds].size.width / 2, 60), tm); }
- (void)cmdEject:(id)s { for (NSString *p in [self _targets]) for (NSDictionary *v in TFVolumes()) if ([v[@"path"] isEqual: p] && [v[@"eject"] boolValue]) TFEject(p); }
- (void)cmdEjectOne:(id)s { [self cmdEject: s]; }
- (void)cmdEjectAll:(id)s { for (NSDictionary *v in TFVolumes()) if ([v[@"eject"] boolValue]) TFEject(v[@"path"]); }
- (void)cmdCopyAsLink:(id)s { NSPasteboard *pb = [NSPasteboard generalPasteboard]; NSMutableArray *u = [NSMutableArray array]; for (NSString *p in [self _targets]) [u addObject: [[NSURL fileURLWithPath: p] absoluteString]]; [pb declareTypes: @[ NSStringPboardType ] owner: nil]; [pb setString: [u componentsJoinedByString: @"\n"] forType: NSStringPboardType]; }
- (void)cmdShowClipboard:(id)s { NSString *t = [[NSPasteboard generalPasteboard] stringForType: NSStringPboardType] ?: @"(empty)"; NSAlert *a = [[NSAlert alloc] init]; [a setMessageText: @"Clipboard"]; [a setInformativeText: t]; [a runModal]; }
- (void)cmdFindFile:(id)s { [self cmdSetFocusToSearchField: s]; }
- (void)cmdAlternateFindFile:(id)s { [self cmdSetFocusToSearchField: s]; }
- (void)cmdSortBy:(id)s {}
- (NSString *)currentGroup { return _mode == 1 ? _list->_group : _icons->_group; }
- (NSString *)currentSort { return _icons->_arrange; }
- (void)cmdUseGroupsOrStacks:(id)s { if (_mode == 1) { [_list setGroup: _list->_group ? nil : (_lastGroup ?: @"kind")]; if (_list->_group) _lastGroup = _list->_group; return; } if (_mode != 0) return; [_icons setGroup: _icons->_group ? nil : (_lastGroup ?: @"kind")]; if (_icons->_group) _lastGroup = _icons->_group; }
- (void)cmdGroupByKey:(NSMenuItem *)it { NSString *k = [it representedObject]; if (_mode == 1) { _lastGroup = [k length] ? k : _lastGroup; [_list setGroup: k]; return; } if (_mode != 0) return; _lastGroup = [k length] ? k : _lastGroup; [_icons setGroup: k]; }
- (void)cmdSortByKey:(NSMenuItem *)it { NSString *k = [it representedObject]; [self _arrange: [k length] ? k : nil]; }
- (void)cmdTogglePreviewPane:(id)s { _showPane = !_showPane; [self _layout]; [self _refreshPane]; }
- (void)_refreshPane { if (!_preview) return; if (![_preview->paths isEqual: _selection]) _preview->_scroll = 0; _preview->paths = _selection; _preview->folder = [_url path]; [_preview setNeedsDisplay: YES]; }
- (void)cmdTogglePreviewOptions:(id)s { __weak TBrowserWindowController *me = self; TFTogglePreviewOptions(nil, ^{ TBrowserWindowController *w = me; [w->_preview setNeedsDisplay: YES]; }); }
- (void)cmdCleanUpByLastOpenDate:(id)s { [self cmdCleanUpByModDate: s]; }
- (void)cmdCleanUpByDateAdded:(id)s { [self cmdCleanUpByCreationDate: s]; }
- (void)toggleTabOverview:(id)s { _forceTabBar = YES; [self _syncTabBar]; }
- (void)cmdSelectStartupDisk:(id)s { [self goToPath: @"/"]; }
- (void)cmdGoToDataSeparatedICloud:(id)s { [self cmdGoToICloud: s]; }
- (void)cmdGoToSharedDocuments:(id)s { [self goToPath: @"/Users/Shared"]; }
- (void)cmdConnectTo:(id)s { [self cmdConnectToServer: s]; }
- (void)cmdGoToRecent:(NSMenuItem *)it { [self goToPath: [it representedObject]]; }
- (void)cmdToggleCopyProgressWindow:(id)s {}
- (void)cmdMacUserGuide:(id)s {}
- (void)cmdTipsForYourMac:(id)s {}
- (void)cmdArchiveWithPassword:(id)s {}
- (void)cmdCreateOrCopyiCloudLink:(id)s {}
- (void)cmdManageSharedItem:(id)s {}
- (void)cmdBurn:(id)s {}
- (void)cmdAddToDock:(id)s {}
- (void)cmdPrintItems:(id)s {}
- (void)cmdCustomizeFolderPopover:(id)s {}
- (void)cmdRotateClockwise:(id)s {}
- (void)cmdRotateCounterclockwise:(id)s {}
- (void)cmdArrange:(id)s {} - (void)cmdCleanUpBy:(id)s {} - (void)cmdUseGroups:(id)s {} - (void)cmdGroupBy:(id)s {}
- (void)cmdCleanUp:(id)s { [_icons cleanUp: NO]; }
- (void)cmdCleanUpSelection:(id)s { [_icons cleanUp: YES]; }
- (void)cmdCleanUpByName:(id)s { _icons->_arrange = @"name"; [_icons cleanUp: NO]; }
- (void)cmdCleanUpByKind:(id)s { _icons->_arrange = @"kind"; [_icons cleanUp: NO]; }
- (void)cmdCleanUpByModDate:(id)s { _icons->_arrange = @"modified"; [_icons cleanUp: NO]; }
- (void)cmdCleanUpByCreationDate:(id)s { _icons->_arrange = @"created"; [_icons cleanUp: NO]; }
- (void)cmdCleanUpByPhysicalSize:(id)s { _icons->_arrange = @"size"; [_icons cleanUp: NO]; }
- (void)cmdCleanUpByLabel:(id)s { _icons->_arrange = @"tags"; [_icons cleanUp: NO]; }
/* drag and drop of icons: into a folder, onto the sidebar, into another Finder window */
/* files dragged in from another program are copied: into the folder of the sidebar row or of the Finder window they were dropped on */
- (void)finderExternalDropPaths:(NSArray *)paths atWindowPoint:(NSPoint)wp
{
	NSString *dest = [_sidebar dropPathAtWindowPoint: wp]; if (![dest length]) dest = _tag ? nil : [_url path]; if (![dest length]) return; __weak TBrowserWindowController *me = self;
	TFCopyItems(paths, dest, NO, ^(NSArray *ops) { TBrowserWindowController *s = me; if (!s) return; if ([ops count]) [s _record: @"Copy" ops: ops]; [s _changed: nil]; });
}
- (BOOL)iconViewDropPaths:(NSArray *)paths intoFolder:(NSString *)folder atWindowPoint:(NSPoint)wp copy:(BOOL)copy
{
	if (!folder && ![_sidebar dropPathAtWindowPoint: wp]) { BOOL onFinder = NO; NSPoint m = [NSEvent mouseLocation]; for (TBrowserWindowController *o in gBrowsers) if (o != self && NSPointInRect(m, [[o window] frame])) onFinder = YES; if (!onFinder && !NSPointInRect(wp, [[[self window] contentView] bounds]) && [NSClassFromString(@"WsdFinderSupport") dropFiles: paths atScreenPoint: [[self window] convertBaseToScreen: wp]]) return YES; }
	NSString *dest = folder; if (!dest) dest = [_sidebar dropPathAtWindowPoint: wp];
	if (!dest) { NSPoint m = [NSEvent mouseLocation]; for (TBrowserWindowController *o in gBrowsers) if (o != self && NSPointInRect(m, [[o window] frame]) && !o->_tag) { dest = [o->_url path]; break; } }
	if (![dest length]) return NO; NSMutableArray *todo = [NSMutableArray array]; for (NSString *p in paths) { if ([[p stringByDeletingLastPathComponent] isEqual: dest] && !copy) continue; if ([dest hasPrefix: [p stringByAppendingString: @"/"]] || [dest isEqual: p]) continue; [todo addObject: p]; } if (![todo count]) return NO;
	__weak TBrowserWindowController *me = self; TFCopyItems(todo, dest, !copy, ^(NSArray *ops) { TBrowserWindowController *s = me; if (!s) return; if ([ops count]) [s _record: copy ? @"Copy" : @"Move" ops: ops]; [s _changed: nil]; }); return YES;
}
- (void)sidebarGoTo:(NSString *)path { [self goToPath: path]; }
- (void)pathBarGoTo:(NSString *)path { [self goToPath: path]; }
- (void)windowWillClose:(NSNotification *)n { [_watcher invalidate]; _watcher = nil; [gBrowsers removeObject: self]; }
@end
