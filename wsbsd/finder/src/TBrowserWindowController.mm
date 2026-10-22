/* The Finder window: toolbar row, sidebar, icon view of the folder, path bar. The structure follows the real Finder (TBrowserWindowController, TSidebarViewController, TIconView ...); the internals are our own and
 * are replaced class by class by what the decompilation shows. Targets of the menu bar actions (cmdBack:, cmdGoHome: ... the selectors of the Finder's MenuBar nib) are implemented here and in TApplicationController. */
#import <Cocoa/Cocoa.h>
#import <CoreServices/CoreServices.h>
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
extern "C" NSImage *WsbsdCoreTypesIcon(NSString *file, CGFloat pt);

#import "TFinderViews.h"
#define SizeString TFSizeString
#define DateString TFDateString
#define KindString TFKindString
@interface NSObject (TFDrag) - (BOOL)isDragPoint:(NSPoint)p; @end
@interface NSObject (TFSupport) + (void)roundWindow:(NSWindow *)w radius:(int)r; @end

/* ---------- the window controller ---------- */
@interface TBrowserWindowController : NSWindowController <TIconViewDelegate, TSidebarDelegate, TPathBarDelegate, NSWindowDelegate> { NSURL *_url; NSMutableArray<NSString *> *_history; NSInteger _hi; TToolbarView *_toolbar; TSidebarView *_sidebar; TIconView *_icons; TListView *_list; TPathBarView *_pathBar; TWindowTrim *_trim; NSMenu *_ctxMenu; NSString *_filter; NSArray *_selection; NSInteger _mode; }
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
	TBrowserWindowController *c = [[self alloc] init]; [c _build]; [c goToPath: path ?: NSHomeDirectory()]; if (!gBrowsers) gBrowsers = [NSMutableArray array]; [gBrowsers addObject: c]; [[c window] makeKeyAndOrderFront: nil]; [NSClassFromString(@"WsdFinderSupport") roundWindow: [c window] radius: 16]; return c;
}
- (void)_build
{
	NSWindow *w = [[TFinderWindow alloc] initWithContentRect: NSMakeRect(160 + 24 * [gBrowsers count], 160, 1022, 552) styleMask: NSWindowStyleMaskBorderless backing: NSBackingStoreBuffered defer: NO];
	[w setReleasedWhenClosed: NO]; [w setOpaque: NO]; [w setBackgroundColor: [NSColor clearColor]]; [w setMinSize: NSMakeSize(560, 320)]; [self setWindow: w]; [w setDelegate: self]; [w setWindowController: self]; NSView *cv = [w contentView];
	_icons = [[TIconView alloc] initWithFrame: NSZeroRect]; _icons->delegate = self; [cv addSubview: _icons];
	_list = [[TListView alloc] initWithFrame: NSZeroRect]; _list->delegate = self; [_list setHidden: YES]; [cv addSubview: _list];
	_sidebar = [[TSidebarView alloc] initWithFrame: NSZeroRect]; _sidebar->delegate = self; [cv addSubview: _sidebar];
	_toolbar = [[TToolbarView alloc] initWithFrame: NSZeroRect]; _toolbar->target = self; [cv addSubview: _toolbar];
	_pathBar = [[TPathBarView alloc] initWithFrame: NSZeroRect]; _pathBar->delegate = self; [cv addSubview: _pathBar]; _history = [NSMutableArray array]; _hi = -1;
	_trim = [[TWindowTrim alloc] initWithFrame: NSZeroRect]; [cv addSubview: _trim];
	NSMenu *m = [[NSMenu alloc] initWithTitle: @""]; for (NSArray *e in @[ @[ @"Open", @"cmdOpen:" ], @[ @"Get Info", @"cmdShowStaticInfo:" ], @[ @"Rename", @"cmdRename:" ], @[ @"Move to Trash", @"cmdMoveToTrash:" ], @[ @"Duplicate", @"cmdDuplicate:" ], @[ @"Make Alias", @"cmdMakeAlias:" ], @[ @"Copy", @"copy:" ], @[ @"Copy as Pathname", @"cmdCopyAsPathname:" ] ]) { NSMenuItem *it = [m addItemWithTitle: e[0] action: NSSelectorFromString(e[1]) keyEquivalent: @""]; [it setTarget: self]; }
	_ctxMenu = m; [_icons setMenu: m]; [_list setMenu: m]; [self _layout];
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter]; [nc addObserver: self selector: @selector(_keyChanged:) name: NSWindowDidBecomeKeyNotification object: w]; [nc addObserver: self selector: @selector(_keyChanged:) name: NSWindowDidResignKeyNotification object: w];
}
- (void)_keyChanged:(NSNotification *)n { for (NSView *v in [[[self window] contentView] subviews]) [v setNeedsDisplay: YES]; }
- (void)windowDidResize:(NSNotification *)n { [self _layout]; }
- (NSMenu *)actionMenu { return _ctxMenu; }
- (void)cmdToggleSearch:(id)s { [_toolbar setSearching: !_toolbar->searching]; if (!_toolbar->searching) [self searchChanged: @""]; }
- (void)searchChanged:(NSString *)text { _filter = [text length] ? text : nil; _icons->filter = _filter; _list->filter = _filter; [self reload]; }
- (id)_view { return _mode == 1 ? (id)_list : (id)_icons; }
- (void)_show:(NSString *)path
{
	_url = [NSURL fileURLWithPath: path]; NSString *name = [path isEqual: @"/"] ? @"Macintosh HD" : [path lastPathComponent]; [[self window] setTitle: name]; _toolbar->title = name;
	_toolbar->canBack = _hi > 0; _toolbar->canForward = _hi + 1 < (NSInteger)[_history count]; _sidebar->current = path; [_pathBar setPath: path]; [self reload]; [_toolbar setNeedsDisplay: YES]; [_sidebar setNeedsDisplay: YES];
}
- (void)reload { NSString *p = [_url path]; if (_mode == 1) [_list setFolder: p]; else [_icons setFolder: p]; _selection = @[]; [[self window] makeFirstResponder: [self _view]]; }
- (void)goToPath:(NSString *)path { BOOL d = NO; if (![[NSFileManager defaultManager] fileExistsAtPath: path isDirectory: &d] || !d) return; if (_hi >= 0 && [_history[_hi] isEqual: path]) return; [_history removeObjectsInRange: NSMakeRange(_hi + 1, [_history count] - _hi - 1)]; [_history addObject: path]; _hi = [_history count] - 1; [self _show: path]; }
- (void)_setMode:(NSInteger)m { _mode = m; _toolbar->mode = m; [_icons setHidden: m == 1]; [_list setHidden: m != 1]; [self reload]; [_toolbar setNeedsDisplay: YES]; }  /* the column and gallery views come later: the icon view stands in */
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
	NSRect b = [[[self window] contentView] bounds]; CGFloat W = b.size.width, H = b.size.height, sw = [_sidebar isHidden] ? 0 : 238, pb = [_pathBar isHidden] ? 0 : 30;
	NSRect (^R)(CGFloat, CGFloat, CGFloat, CGFloat) = ^NSRect(CGFloat x, CGFloat top, CGFloat w, CGFloat h) { return NSMakeRect(x, H - top - h, w, h); };
	[_sidebar setFrame: R(0, 0, sw, H)]; [_toolbar setFrame: R(sw, 0, W - sw, 52)]; NSRect c = R(sw, 52, W - sw, H - 52 - pb); [_icons setFrame: c]; [_list setFrame: c]; [_pathBar setFrame: R(sw, H - pb, W - sw, pb)]; [_trim setFrame: b];
	for (NSView *v in @[ _sidebar, _toolbar, _icons, _list, _pathBar, _trim ]) [v setNeedsDisplay: YES];
}
/* what the file operations act on */
- (NSArray *)_targets { return [_selection count] ? _selection : @[]; }
- (void)_changed:(NSString *)selectPath { [self reload]; (void)selectPath; for (TBrowserWindowController *c in gBrowsers) if (c != self) { NSString *p = [c->_url path]; [c reload]; (void)p; } }
- (void)cmdNewFolder:(id)s { NSString *p = UniquePath([_url path], @"untitled folder", nil); NSError *e = nil; if ([[NSFileManager defaultManager] createDirectoryAtPath: p withIntermediateDirectories: NO attributes: nil error: &e]) { [self reload]; _selection = @[ p ]; [self _renamePath: p]; } else NSBeep(); }
- (void)cmdMoveToTrash:(id)s
{
	NSFileManager *fm = [NSFileManager defaultManager]; [fm createDirectoryAtPath: TrashPath() withIntermediateDirectories: YES attributes: nil error: NULL];
	for (NSString *p in [self _targets]) { NSString *dest = UniquePath(TrashPath(), [[p lastPathComponent] stringByDeletingPathExtension], [p pathExtension]); [fm moveItemAtPath: p toPath: dest error: NULL]; }
	[self _changed: nil];
}
- (void)cmdEmptyTrash:(id)s { NSFileManager *fm = [NSFileManager defaultManager]; for (NSString *n in [fm contentsOfDirectoryAtPath: TrashPath() error: NULL]) [fm removeItemAtPath: [TrashPath() stringByAppendingPathComponent: n] error: NULL]; [self _changed: nil]; }
- (void)cmdEmptyTrashSilently:(id)s { [self cmdEmptyTrash: s]; }
- (void)cmdDuplicate:(id)s { NSFileManager *fm = [NSFileManager defaultManager]; for (NSString *p in [self _targets]) { NSString *dest = UniquePath([p stringByDeletingLastPathComponent], [[[p lastPathComponent] stringByDeletingPathExtension] stringByAppendingString: @" copy"], [p pathExtension]); [fm copyItemAtPath: p toPath: dest error: NULL]; } [self _changed: nil]; }
- (void)cmdMakeAlias:(id)s { NSFileManager *fm = [NSFileManager defaultManager]; for (NSString *p in [self _targets]) { NSString *dest = UniquePath([p stringByDeletingLastPathComponent], [[p lastPathComponent] stringByAppendingString: @" alias"], nil); [fm createSymbolicLinkAtPath: dest withDestinationPath: p error: NULL]; } [self _changed: nil]; }
- (void)cmdCopyAsPathname:(id)s { NSPasteboard *pb = [NSPasteboard generalPasteboard]; [pb declareTypes: @[ NSStringPboardType ] owner: nil]; [pb setString: [[self _targets] componentsJoinedByString: @"\n"] forType: NSStringPboardType]; }
- (void)copy:(id)s { NSPasteboard *pb = [NSPasteboard generalPasteboard]; [pb declareTypes: @[ NSFilenamesPboardType ] owner: nil]; [pb setPropertyList: [self _targets] forType: NSFilenamesPboardType]; }
- (void)paste:(id)s { NSArray *files = [[NSPasteboard generalPasteboard] propertyListForType: NSFilenamesPboardType]; NSFileManager *fm = [NSFileManager defaultManager]; for (NSString *p in files) { NSString *dest = UniquePath([_url path], [[p lastPathComponent] stringByDeletingPathExtension], [p pathExtension]); [fm copyItemAtPath: p toPath: dest error: NULL]; } [self _changed: nil]; }
- (void)selectAll:(id)s { [(id)[self _view] selectAll: s]; }
- (void)cmdDeselectAll:(id)s { _selection = @[]; [self reload]; }
- (void)_renamePath:(NSString *)path
{
	NSAlert *a = [[NSAlert alloc] init]; [a setMessageText: @"Rename"]; NSTextField *f = [[NSTextField alloc] initWithFrame: NSMakeRect(0, 0, 260, 24)]; [f setStringValue: [path lastPathComponent]]; [a setAccessoryView: f]; [a addButtonWithTitle: @"OK"]; [a addButtonWithTitle: @"Cancel"];
	if ([a runModal] == NSAlertFirstButtonReturn && [[f stringValue] length] && ![[f stringValue] containsString: @"/"]) { NSString *dest = [[path stringByDeletingLastPathComponent] stringByAppendingPathComponent: [f stringValue]]; if ([[NSFileManager defaultManager] moveItemAtPath: path toPath: dest error: NULL]) [self _changed: dest]; }
}
- (void)cmdRename:(id)s { if ([_selection count] == 1) [self _renamePath: _selection[0]]; }
- (void)cmdShowStaticInfo:(id)s
{
	NSFileManager *fm = [NSFileManager defaultManager]; NSMutableString *t = [NSMutableString string];
	for (NSString *p in [self _targets]) { NSDictionary *at = [fm attributesOfItemAtPath: p error: NULL]; BOOL dir = [at[NSFileType] isEqual: NSFileTypeDirectory]; [t appendFormat: @"%@\nKind: %@\nSize: %@\nWhere: %@\nCreated: %@\nModified: %@\n\n", [p lastPathComponent], KindString(p, dir && ![[p pathExtension] isEqual: @"app"]), dir ? @"--" : SizeString([at[NSFileSize] unsignedLongLongValue]), [p stringByDeletingLastPathComponent], DateString(at[NSFileCreationDate]), DateString(at[NSFileModificationDate])]; }
	if (![t length]) return; NSAlert *a = [[NSAlert alloc] init]; [a setMessageText: @"Info"]; [a setInformativeText: t]; [a runModal];
}
- (BOOL)validateMenuItem:(NSMenuItem *)i
{
	SEL a = [i action]; BOOL has = [_selection count] > 0;
	if (a == @selector(cmdBack:)) return _hi > 0; if (a == @selector(cmdForward:)) return _hi + 1 < (NSInteger)[_history count];
	if (a == @selector(cmdOpen:) || a == @selector(cmdOpenWithDownArrow:) || a == @selector(cmdMoveToTrash:) || a == @selector(cmdDuplicate:) || a == @selector(cmdMakeAlias:) || a == @selector(copy:) || a == @selector(cmdShowStaticInfo:) || a == @selector(cmdCopyAsPathname:)) return has;
	if (a == @selector(cmdRename:)) return [_selection count] == 1; if (a == @selector(paste:)) return [[NSPasteboard generalPasteboard] propertyListForType: NSFilenamesPboardType] != nil;
	if (a == @selector(cmdTogglePathBar:)) { [i setTitle: [_pathBar isHidden] ? @"Show Path Bar" : @"Hide Path Bar"]; return YES; } if (a == @selector(cmdToggleSidebar:)) { [i setTitle: [_sidebar isHidden] ? @"Show Sidebar" : @"Hide Sidebar"]; return YES; }
	if (a == @selector(cmdViewAsIcons:)) { [i setState: _mode == 0]; return YES; } if (a == @selector(cmdViewAsList:)) { [i setState: _mode == 1]; return YES; }
	return [self respondsToSelector: a];
}
/* delegates */
- (void)iconViewOpenItem:(NSString *)path { BOOL d = NO; [[NSFileManager defaultManager] fileExistsAtPath: path isDirectory: &d]; if (d && ![[path pathExtension] isEqual: @"app"]) [self goToPath: path]; else [[NSWorkspace sharedWorkspace] openFile: path]; }
- (void)iconViewSelectionChanged:(NSArray *)paths { _selection = paths; }
- (void)sidebarGoTo:(NSString *)path { [self goToPath: path]; }
- (void)pathBarGoTo:(NSString *)path { [self goToPath: path]; }
- (void)windowWillClose:(NSNotification *)n { [gBrowsers removeObject: self]; }
@end
