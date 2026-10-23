/* The Finder window: toolbar row, sidebar, icon view of the folder, path bar. The structure follows the real Finder (TBrowserWindowController, TSidebarViewController, TIconView ...); the internals are our own and
 * are replaced class by class by what the decompilation shows. Targets of the menu bar actions (cmdBack:, cmdGoHome: ... the selectors of the Finder's MenuBar nib) are implemented here and in TApplicationController. */
#import <Cocoa/Cocoa.h>
#import <CoreServices/CoreServices.h>
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
extern "C" NSImage *WsbsdCoreTypesIcon(NSString *file, CGFloat pt);

#import "TFinderViews.h"
#include <sys/stat.h>
#define SizeString TFSizeString
#define DateString TFDateString
#define KindString TFKindString
@interface NSObject (TFDrag) - (BOOL)isDragPoint:(NSPoint)p; @end
@interface NSObject (TFSupport) + (void)roundWindow:(NSWindow *)w radius:(int)r; @end

/* ---------- the window controller ---------- */
@interface TBrowserWindowController : NSWindowController <TIconViewDelegate, TSidebarDelegate, TPathBarDelegate, NSWindowDelegate> { NSURL *_url; NSMutableArray<NSString *> *_history; NSInteger _hi; TToolbarView *_toolbar; TSidebarView *_sidebar; TIconView *_icons; TListView *_list; TColumnView *_cols; TGalleryView *_gallery; TPathBarView *_pathBar; TWindowTrim *_trim; TStatusBarView *_status; BOOL _showStatus; NSMenu *_ctxMenu; NSString *_filter, *_tag; NSMutableArray *_undo, *_redo; long long _watchedMod; NSTimer *_watcher; NSArray *_cutPaths; NSArray *_selection; NSInteger _mode; }
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
	[w setReleasedWhenClosed: NO]; [w setOpaque: NO]; [w setBackgroundColor: [NSColor clearColor]]; [w setMinSize: NSMakeSize(560, 320)]; [self setWindow: w]; [w setDelegate: self]; [w setWindowController: self]; NSView *cv = [w contentView];
	_icons = [[TIconView alloc] initWithFrame: NSZeroRect]; _icons->delegate = self; [cv addSubview: _icons];
	_list = [[TListView alloc] initWithFrame: NSZeroRect]; _list->delegate = self; [_list setHidden: YES]; [cv addSubview: _list];
	_cols = [[TColumnView alloc] initWithFrame: NSZeroRect]; _cols->delegate = self; [_cols setHidden: YES]; [cv addSubview: _cols];
	_gallery = [[TGalleryView alloc] initWithFrame: NSZeroRect]; _gallery->delegate = self; [_gallery setHidden: YES]; [cv addSubview: _gallery];
	_sidebar = [[TSidebarView alloc] initWithFrame: NSZeroRect]; _sidebar->delegate = self; [cv addSubview: _sidebar];
	_toolbar = [[TToolbarView alloc] initWithFrame: NSZeroRect]; _toolbar->target = self; [cv addSubview: _toolbar];
	_pathBar = [[TPathBarView alloc] initWithFrame: NSZeroRect]; _pathBar->delegate = self; [cv addSubview: _pathBar]; _history = [NSMutableArray array]; _hi = -1;
	_status = [[TStatusBarView alloc] initWithFrame: NSZeroRect]; _status->target = self; [_status setHidden: YES]; [cv addSubview: _status];
	_trim = [[TWindowTrim alloc] initWithFrame: NSZeroRect]; [cv addSubview: _trim];
	NSMenu *m = [[NSMenu alloc] initWithTitle: @""]; for (NSArray *e in @[ @[ @"Open", @"cmdOpen:" ], @[ @"Get Info", @"cmdShowStaticInfo:" ], @[ @"Rename", @"cmdRename:" ], @[ @"Move to Trash", @"cmdMoveToTrash:" ], @[ @"Put Back", @"cmdPutBack:" ], @[ @"Duplicate", @"cmdDuplicate:" ], @[ @"Compress", @"cmdCompress:" ], @[ @"Quick Look", @"cmdQuickLook:" ], @[ @"Make Alias", @"cmdMakeAlias:" ], @[ @"Copy", @"copy:" ], @[ @"Copy as Pathname", @"cmdCopyAsPathname:" ] ]) { NSMenuItem *it = [m addItemWithTitle: e[0] action: NSSelectorFromString(e[1]) keyEquivalent: @""]; [it setTarget: self]; }
	{ NSMenuItem *ti = [m addItemWithTitle: @"Tags" action: NULL keyEquivalent: @""]; NSMenu *sub = [[NSMenu alloc] initWithTitle: @"Tags"]; [self _fillTagMenu: sub]; [ti setSubmenu: sub]; }
	_watcher = [NSTimer scheduledTimerWithTimeInterval: 1 target: self selector: @selector(_watch:) userInfo: nil repeats: YES]; _ctxMenu = m; [_icons setMenu: m]; [_list setMenu: m]; [self _layout];
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
- (NSMenu *)actionMenu { return _ctxMenu; }
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
- (void)cmdToggleSearch:(id)s { [_toolbar setSearching: !_toolbar->searching]; if (!_toolbar->searching) [self searchChanged: @""]; }
- (void)searchChanged:(NSString *)text { _filter = [text length] ? text : nil; _icons->filter = _filter; _list->filter = _filter; _gallery->filter = _filter; [self reload]; }
- (id)_view { return _mode == 1 ? (id)_list : _mode == 2 ? (id)_cols : _mode == 3 ? (id)_gallery : (id)_icons; }
- (void)_show:(NSString *)path
{
	BOOL tagged = [path hasPrefix: @"tag://"]; _tag = tagged ? [path substringFromIndex: 6] : nil; _url = [NSURL fileURLWithPath: tagged ? NSHomeDirectory() : path]; NSString *name = tagged ? _tag : [path isEqual: @"/"] ? @"Macintosh HD" : [path lastPathComponent]; [[self window] setTitle: name]; _toolbar->title = name;
	_toolbar->canBack = _hi > 0; _toolbar->canForward = _hi + 1 < (NSInteger)[_history count]; _sidebar->current = path; _watchedMod = 0; [_pathBar setPath: [_url path]]; [self reload]; [self _restoreStyleAndWindow: NO]; [self _updateStatus]; [_toolbar setNeedsDisplay: YES]; [_sidebar setNeedsDisplay: YES];
}
- (void)reload { NSString *p = [_url path]; if (_tag) { NSArray *ps = TFPathsTagged(_tag); if (_mode == 1) [_list setPaths: ps]; else if (_mode == 3) [_gallery setPaths: ps]; else [_icons setPaths: ps]; _selection = @[]; [[self window] makeFirstResponder: [self _view]]; return; } if (_mode == 1) [_list setFolder: p]; else if (_mode == 2) [_cols setFolder: p]; else if (_mode == 3) [_gallery setFolder: p]; else [_icons setFolder: p]; _selection = @[]; [[self window] makeFirstResponder: [self _view]]; }
- (void)goToPath:(NSString *)path { BOOL d = NO; if (![path hasPrefix: @"tag://"] && (![[NSFileManager defaultManager] fileExistsAtPath: path isDirectory: &d] || !d)) return; if (_hi >= 0 && [_history[_hi] isEqual: path]) return; [_history removeObjectsInRange: NSMakeRange(_hi + 1, [_history count] - _hi - 1)]; [_history addObject: path]; _hi = [_history count] - 1; [self _show: path]; }
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
	[_sidebar setFrame: R(0, 0, sw, H)]; [_toolbar setFrame: R(sw, 0, W - sw, 52)]; NSRect c = R(sw, 52, W - sw, H - 52 - pb - sb); [_status setHidden: !_showStatus]; [_status setFrame: R(sw, H - pb - sb, W - sw, sb)]; [_icons setFrame: c]; [_list setFrame: c]; [_cols setFrame: c]; [_gallery setFrame: c]; [_pathBar setFrame: R(sw, H - pb, W - sw, pb)]; [_trim setFrame: b];
	for (NSView *v in @[ _sidebar, _toolbar, _icons, _list, _cols, _gallery, _pathBar, _status, _trim ]) [v setNeedsDisplay: YES];
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
- (void)cmdQuickLook:(id)s { NSArray *t = [self _targets]; if ([t count]) TFOpenQuickLook(t[0]); }
- (void)cmdNewTab:(id)s { [TBrowserWindowController newBrowserWithPath: [_url path]]; }
- (void)cmdOpenInNewTab:(id)s { for (NSString *p in [self _targets]) { BOOL d = NO; [[NSFileManager defaultManager] fileExistsAtPath: p isDirectory: &d]; if (d) [TBrowserWindowController newBrowserWithPath: p]; } }
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
- (void)cmdDuplicate:(id)s { NSFileManager *fm = [NSFileManager defaultManager]; NSMutableArray *ops = [NSMutableArray array]; for (NSString *p in [self _targets]) { NSString *dest = UniquePath([p stringByDeletingLastPathComponent], [[[p lastPathComponent] stringByDeletingPathExtension] stringByAppendingString: @" copy"], [p pathExtension]); if ([fm copyItemAtPath: p toPath: dest error: NULL]) [ops addObject: @{ @"t": @"copy", @"a": p, @"b": dest }]; } if ([ops count]) [self _record: @"Duplicate" ops: ops]; [self _changed: nil]; }
- (void)cut:(id)s { [self copy: s]; _cutPaths = [[self _targets] copy]; }
- (void)_pasteMoving:(BOOL)move
{
	NSArray *files = [[NSPasteboard generalPasteboard] propertyListForType: NSFilenamesPboardType]; NSFileManager *fm = [NSFileManager defaultManager]; NSMutableArray *ops = [NSMutableArray array]; BOOL cut = move || (_cutPaths && [_cutPaths isEqual: files]);
	for (NSString *p in files) { NSString *dest = [[_url path] stringByAppendingPathComponent: [p lastPathComponent]]; if ([fm fileExistsAtPath: dest]) { if (cut && [[p stringByDeletingLastPathComponent] isEqual: [_url path]]) continue; dest = UniquePath([_url path], [[p lastPathComponent] stringByDeletingPathExtension], [p pathExtension]); }
		if (cut ? [fm moveItemAtPath: p toPath: dest error: NULL] : [fm copyItemAtPath: p toPath: dest error: NULL]) [ops addObject: @{ @"t": cut ? @"move" : @"copy", @"a": p, @"b": dest }]; }
	if (cut) _cutPaths = nil; if ([ops count]) [self _record: cut ? @"Move" : @"Paste" ops: ops]; [self _changed: nil];
}
- (void)paste:(id)s { [self _pasteMoving: NO]; }
- (void)cmdMoveItemsHere:(id)s { [self _pasteMoving: YES]; }
- (void)cmdPasteExactly:(id)s { [self _pasteMoving: NO]; }
- (void)_renamePath:(NSString *)path
{
	NSAlert *a = [[NSAlert alloc] init]; [a setMessageText: @"Rename"]; NSTextField *f = [[NSTextField alloc] initWithFrame: NSMakeRect(0, 0, 260, 24)]; [f setStringValue: [path lastPathComponent]]; [a setAccessoryView: f]; [a addButtonWithTitle: @"OK"]; [a addButtonWithTitle: @"Cancel"];
	if ([a runModal] == NSAlertFirstButtonReturn && [[f stringValue] length] && ![[f stringValue] containsString: @"/"]) { NSString *dest = [[path stringByDeletingLastPathComponent] stringByAppendingPathComponent: [f stringValue]]; NSString *oe = [path pathExtension], *ne = [dest pathExtension]; if ([oe length] && ![oe isEqual: ne] && TFPrefBool(@"FXEnableExtensionChangeWarning", YES)) { NSAlert *w = [[NSAlert alloc] init]; [w setMessageText: [NSString stringWithFormat: @"Are you sure you want to change the extension from “.%@” to “%@”?", oe, [ne length] ? [@"." stringByAppendingString: ne] : @"nothing"]]; [w setInformativeText: @"If you make this change, your document may open in a different application."]; [w addButtonWithTitle: [NSString stringWithFormat: @"Keep .%@", oe]]; [w addButtonWithTitle: [ne length] ? [@"Use ." stringByAppendingString: ne] : @"Use no extension"]; if ([w runModal] == NSAlertFirstButtonReturn) dest = [[dest stringByDeletingPathExtension] stringByAppendingPathExtension: oe]; } if ([[NSFileManager defaultManager] moveItemAtPath: path toPath: dest error: NULL]) { [self _record: @"Rename" ops: @[ @{ @"t": @"move", @"a": path, @"b": dest } ]]; [self _changed: dest]; } }
}
- (void)cmdGoTo:(id)s
{
	NSAlert *a = [[NSAlert alloc] init]; [a setMessageText: @"Go to the folder:"]; NSTextField *f = [[NSTextField alloc] initWithFrame: NSMakeRect(0, 0, 320, 24)]; [f setStringValue: @"/"]; [a setAccessoryView: f]; [a addButtonWithTitle: @"Go"]; [a addButtonWithTitle: @"Cancel"];
	if ([a runModal] == NSAlertFirstButtonReturn) { NSString *p = [[f stringValue] stringByExpandingTildeInPath]; BOOL d = NO; if ([[NSFileManager defaultManager] fileExistsAtPath: p isDirectory: &d]) [self goToPath: d ? p : [p stringByDeletingLastPathComponent]]; else { NSAlert *e = [[NSAlert alloc] init]; [e setMessageText: @"The folder can’t be found."]; [e runModal]; } }
}
- (void)cmdSetFocusToSearchField:(id)s { if (!_toolbar->searching) [_toolbar setSearching: YES]; }
- (void)cmdSearchFromToolbar:(id)s { [self cmdToggleSearch: s]; }
- (void)selectAll:(id)s { [(id)[self _view] selectAll: s]; }
- (void)cmdDeselectAll:(id)s { _selection = @[]; [self reload]; }
- (void)cmdRename:(id)s { if ([_selection count] == 1) [self _renamePath: _selection[0]]; }
- (void)cmdShowStaticInfo:(id)s { for (NSString *p in [self _targets]) TFOpenInfoWindow(p); }
- (void)cmdShowInfo:(id)s { [self cmdShowStaticInfo: s]; }
- (BOOL)validateMenuItem:(NSMenuItem *)i
{
	SEL a = [i action]; BOOL has = [_selection count] > 0;
	if (a == @selector(cmdToggleTag:)) { BOOL all = has; for (NSString *p in _selection) if (![TFTagsOf(p) containsObject: [i representedObject]]) all = NO; [i setState: all ? NSOnState : NSOffState]; return has; }
	if (a == @selector(cmdBack:)) return _hi > 0; if (a == @selector(cmdForward:)) return _hi + 1 < (NSInteger)[_history count];
	if (a == @selector(cmdOpen:) || a == @selector(cmdOpenWithDownArrow:) || a == @selector(cmdMoveToTrash:) || a == @selector(cmdDuplicate:) || a == @selector(cmdMakeAlias:) || a == @selector(copy:) || a == @selector(cmdShowStaticInfo:) || a == @selector(cmdCopyAsPathname:)) return has;
	if (a == @selector(cmdRename:)) return [_selection count] == 1; if (a == @selector(paste:)) return [[NSPasteboard generalPasteboard] propertyListForType: NSFilenamesPboardType] != nil;
	if (a == @selector(undo:)) { NSDictionary *e = [_undo lastObject]; [i setTitle: e ? [@"Undo " stringByAppendingString: e[@"name"]] : @"Undo"]; return e != nil; }
	if (a == @selector(redo:)) { NSDictionary *e = [_redo lastObject]; [i setTitle: e ? [@"Redo " stringByAppendingString: e[@"name"]] : @"Redo"]; return e != nil; }
	if (a == @selector(cut:) || a == @selector(cmdNewFolderWithSelection:) || a == @selector(cmdArchive:) || a == @selector(cmdSlideshow:) || a == @selector(cmdShare:) || a == @selector(cmdShowPackageContents:)) return has;
	if (a == @selector(cmdNewFolder:) && [i isKindOfClass: [NSMenuItem class]] && [[i title] hasPrefix: @"New Folder with"]) return has;
	if (a == @selector(cmdIncreaseIconSize:) || a == @selector(cmdDecreaseIconSize:)) return _mode == 0;
	if (a == @selector(cmdMoveItemsHere:) || a == @selector(cmdPasteExactly:)) return [[NSPasteboard generalPasteboard] propertyListForType: NSFilenamesPboardType] != nil;
	if (a == @selector(cmdPutBack:)) return has && [[[_url path] stringByStandardizingPath] hasPrefix: TrashPath()];
	if (a == @selector(cmdDeleteImmediately:) || a == @selector(cmdCompress:) || a == @selector(cmdQuickLook:) || a == @selector(cmdOpenInNewTab:) || a == @selector(cmdDuplicateExactly:) || a == @selector(cmdShowOriginal:)) return has;
	if (a == @selector(cmdEmptyTrash:) || a == @selector(cmdEmptyTrashSilently:)) return [[[NSFileManager defaultManager] contentsOfDirectoryAtPath: TrashPath() error: NULL] count] > 0;
	if (a == @selector(cmdToggleStatusBar:)) { [i setTitle: _showStatus ? @"Hide Status Bar" : @"Show Status Bar"]; return YES; }
	if (a == @selector(cmdArrangeByNone:) || a == @selector(cmdArrangeByName:) || a == @selector(cmdArrangeByKind:) || a == @selector(cmdArrangeByDateModified:) || a == @selector(cmdArrangeByDateCreated:) || a == @selector(cmdArrangeBySize:) || a == @selector(cmdArrangeByFinderTags:)) { NSString *k = _icons->_arrange; NSDictionary *m = @{ @"cmdArrangeByName:": @"name", @"cmdArrangeByKind:": @"kind", @"cmdArrangeByDateModified:": @"modified", @"cmdArrangeByDateCreated:": @"created", @"cmdArrangeBySize:": @"size", @"cmdArrangeByFinderTags:": @"tags" }; NSString *mine = m[NSStringFromSelector(a)]; [i setState: (mine ? [mine isEqual: k] : ![k length]) ? NSOnState : NSOffState]; return _mode != 1; }
	if (a == @selector(cmdTogglePathBar:)) { [i setTitle: [_pathBar isHidden] ? @"Show Path Bar" : @"Hide Path Bar"]; return YES; } if (a == @selector(cmdToggleSidebar:)) { [i setTitle: [_sidebar isHidden] ? @"Show Sidebar" : @"Hide Sidebar"]; return YES; }
	if (a == @selector(cmdViewAsIcons:)) { [i setState: _mode == 0]; return YES; } if (a == @selector(cmdViewAsList:)) { [i setState: _mode == 1]; return YES; }
	return [self respondsToSelector: a];
}
/* delegates */
- (void)iconViewOpenItem:(NSString *)path { BOOL d = NO; [[NSFileManager defaultManager] fileExistsAtPath: path isDirectory: &d]; if (d && ![[path pathExtension] isEqual: @"app"]) [self goToPath: path]; else [[NSWorkspace sharedWorkspace] openFile: path]; }
- (void)iconViewSelectionChanged:(NSArray *)paths { _selection = paths; [self _updateStatus]; }
- (void)_updateStatus
{
	if (!_showStatus) return; NSFileManager *fm = [NSFileManager defaultManager]; NSUInteger n = 0; if (_tag) n = [TFPathsTagged(_tag) count]; else for (NSString *s in [fm contentsOfDirectoryAtPath: [_url path] error: NULL]) if (![s hasPrefix: @"."]) n++;
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
- (void)cmdShare:(id)s { NSArray *t = [self _targets]; if ([t count]) [self cmdCopyAsPathname: s]; }
- (void)toggleTabBar:(id)s {}
- (void)cmdShowPackageContents:(id)s { for (NSString *p in [self _targets]) if ([[p pathExtension] isEqual: @"app"]) [self goToPath: p]; }
- (void)cmdToggleToolbar:(id)s { [_toolbar setHidden: ![_toolbar isHidden]]; }
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
- (BOOL)iconViewDropPaths:(NSArray *)paths intoFolder:(NSString *)folder atWindowPoint:(NSPoint)wp copy:(BOOL)copy
{
	NSString *dest = folder; if (!dest) dest = [_sidebar dropPathAtWindowPoint: wp];
	if (!dest) { NSPoint m = [NSEvent mouseLocation]; for (TBrowserWindowController *o in gBrowsers) if (o != self && NSPointInRect(m, [[o window] frame]) && !o->_tag) { dest = [o->_url path]; break; } }
	if (![dest length]) return NO; NSFileManager *fm = [NSFileManager defaultManager]; BOOL any = NO; NSMutableArray *dops = [NSMutableArray array];
	for (NSString *p in paths) {
		if ([[p stringByDeletingLastPathComponent] isEqual: dest] && !copy) continue; if ([dest hasPrefix: [p stringByAppendingString: @"/"]] || [dest isEqual: p]) continue;
		NSString *to = [dest stringByAppendingPathComponent: [p lastPathComponent]]; if ([fm fileExistsAtPath: to]) to = UniquePath(dest, [[p lastPathComponent] stringByDeletingPathExtension], [p pathExtension]);
		if (copy ? [fm copyItemAtPath: p toPath: to error: NULL] : [fm moveItemAtPath: p toPath: to error: NULL]) { any = YES; [dops addObject: @{ @"t": copy ? @"copy" : @"move", @"a": p, @"b": to }]; }
	}
	if (any) { [self _record: copy ? @"Copy" : @"Move" ops: dops]; [self _changed: nil]; } return any;
}
- (void)sidebarGoTo:(NSString *)path { [self goToPath: path]; }
- (void)pathBarGoTo:(NSString *)path { [self goToPath: path]; }
- (void)windowWillClose:(NSNotification *)n { [_watcher invalidate]; _watcher = nil; [gBrowsers removeObject: self]; }
@end
