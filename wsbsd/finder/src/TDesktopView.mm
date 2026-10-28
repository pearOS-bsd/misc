/* TDesktopWindowController: the desktop. The icons are those of ~/Desktop and of the volumes the preferences ask for (Finder > Settings > General), in the Finder's own icon view (TIconView in desktop mode: columns from the top right,
 * places that stay where they are put, Clean Up, drag into folders), on the window at the desktop icon level. A double click opens an item in a Finder window. */
#import "TDesktopWindow.h"
#import "TFinderViews.h"

@interface TBrowserWindowController : NSWindowController
+ (instancetype)newBrowserWithPath:(NSString *)path;
@end
@interface TDesktopWindowController : NSObject <TIconViewDelegate> { NSString *_pictureSeen; TDesktopWindow *_window; TIconView *_view; NSArray *_selection; NSString *_volumeSig; }
+ (instancetype)sharedController;
- (void)showDesktop;
@end
@implementation TDesktopWindowController
+ (instancetype)sharedController { static id s; static dispatch_once_t o; dispatch_once(&o, ^{ s = [[self alloc] init]; }); return s; }
static NSString *DesktopPath(void) { return [NSHomeDirectory() stringByAppendingPathComponent: @"Desktop"]; }
- (void)showDesktop
{
	@try { [self _showDesktop]; } @catch (NSException *e) { NSLog(@"Finder: showDesktop failed: %@ %@ %@", [e name], [e reason], [e callStackSymbols]); }
}
- (NSString *)_signature { NSMutableString *s = [NSMutableString string]; for (NSDictionary *v in TFVolumes()) [s appendFormat: @"%@;", v[@"path"]]; for (NSString *k in @[ @"ShowHardDrivesOnDesktop", @"ShowExternalHardDrivesOnDesktop", @"ShowRemovableMediaOnDesktop", @"ShowMountedServersOnDesktop" ]) [s appendFormat: @"%d", TFPrefBool(k, [k hasPrefix: @"ShowExt"] || [k hasPrefix: @"ShowRem"])]; [s appendFormat: @"%lu", (unsigned long)[[[NSFileManager defaultManager] contentsOfDirectoryAtPath: DesktopPath() error: NULL] count]]; return s; }
- (void)_poll:(NSTimer *)t { NSString *pic = TFWallpaperPath(); if (pic && ![pic isEqual: _pictureSeen] && _pictureSeen) [self _prefs: nil]; _pictureSeen = pic;      /* the default picture follows the appearance */
	NSString *sig = [self _signature]; if (![sig isEqual: _volumeSig]) { _volumeSig = sig; [_view reloadKeepingSelectionOrFolder: DesktopPath()]; } }
- (void)_showDesktop
{
	if (_window) return; NSScreen *screen = [NSScreen mainScreen]; NSLog(@"Finder: showDesktop screen %@ frame %@", screen, NSStringFromRect([screen frame])); _window = [[TDesktopWindow alloc] initWithScreen: screen];
	{ TWallpaperView *wp = [[TWallpaperView alloc] initWithFrame: [[_window contentView] bounds]]; [wp setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable]; [_window setContentView: wp]; [_window setOpaque: TFWallpaperImage() != nil]; TFWriteWallpaperGrid([screen frame].size); }
	_view = [[TIconView alloc] initWithFrame: [[_window contentView] bounds]]; _view->desktop = YES; _view->delegate = self; [_view setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable]; [[_window contentView] addSubview: _view];
	[_view setMenu: [self _desktopMenu]];
	[_view setFolder: DesktopPath()]; _volumeSig = [self _signature]; [NSTimer scheduledTimerWithTimeInterval: 2 target: self selector: @selector(_poll:) userInfo: nil repeats: YES];
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(_prefs:) name: @"TFPrefsChanged" object: nil]; [_window orderBack: nil];
}
- (void)_prefs:(NSNotification *)n { _volumeSig = nil; [self _poll: nil]; [_window setOpaque: TFWallpaperImage() != nil]; TFWriteWallpaperGrid([[NSScreen mainScreen] frame].size); [[_window contentView] setNeedsDisplay: YES]; }
- (void)iconViewOpenItem:(NSString *)path { BOOL d = NO; [[NSFileManager defaultManager] fileExistsAtPath: path isDirectory: &d]; if (d && !TFIsPackage(path)) [TBrowserWindowController newBrowserWithPath: path]; else TFOpenPath(path); }
- (void)iconViewSelectionChanged:(NSArray *)paths { _selection = paths; }
- (BOOL)iconViewDropPaths:(NSArray *)paths intoFolder:(NSString *)folder atWindowPoint:(NSPoint)p copy:(BOOL)copy
{
	if (![folder length]) return NO; NSFileManager *fm = [NSFileManager defaultManager]; BOOL any = NO;
	for (NSString *s in paths) { NSString *to = [folder stringByAppendingPathComponent: [s lastPathComponent]]; if ([to isEqual: s] || [fm fileExistsAtPath: to]) continue; if (copy ? [fm copyItemAtPath: s toPath: to error: NULL] : [fm moveItemAtPath: s toPath: to error: NULL]) any = YES; }
	if (any) [_view reloadKeepingSelectionOrFolder: DesktopPath()]; return any;
}
- (void)cmdNewFolder:(id)s { NSFileManager *fm = [NSFileManager defaultManager]; NSString *p = [DesktopPath() stringByAppendingPathComponent: @"untitled folder"]; int i = 2; while ([fm fileExistsAtPath: p]) p = [DesktopPath() stringByAppendingPathComponent: [NSString stringWithFormat: @"untitled folder %d", i++]]; if (![fm createDirectoryAtPath: p withIntermediateDirectories: NO attributes: nil error: NULL]) { NSBeep(); return; } [_view reloadKeepingSelectionOrFolder: DesktopPath()]; _selection = @[ p ]; [_view beginRename: p]; }
- (void)cmdShowStaticInfo:(id)s { for (NSString *p in _selection) TFOpenInfoWindow(p); }
- (void)cmdMoveToTrash:(id)s { NSFileManager *fm = [NSFileManager defaultManager]; NSString *tr = [NSHomeDirectory() stringByAppendingPathComponent: @".Trash"]; [fm createDirectoryAtPath: tr withIntermediateDirectories: YES attributes: nil error: NULL]; for (NSString *p in _selection) { if ([p hasPrefix: DesktopPath()]) [fm moveItemAtPath: p toPath: [tr stringByAppendingPathComponent: [p lastPathComponent]] error: NULL]; } [_view reloadKeepingSelectionOrFolder: DesktopPath()]; }
- (void)cmdCleanUp:(id)s { [_view cleanUp: NO]; }
/* the menu of an item on the desktop (as the Finder's: Open, Move to Trash, Get Info, Rename, Duplicate, Quick Look, Copy, the tag colours): the background has the menu above */
- (NSMenu *)itemContextMenu
{
	NSMenu *m = [[NSMenu alloc] initWithTitle: @""]; NSString *first = [_selection count] ? [_selection[0] lastPathComponent] : @"";
#define ITEM(title, sel) ({ NSMenuItem *x = [m addItemWithTitle: title action: sel keyEquivalent: @""]; [x setTarget: self]; x; })
	ITEM(@"Open", @selector(cmdOpen:)); [m addItem: [NSMenuItem separatorItem]]; ITEM(@"Move to Trash", @selector(cmdMoveToTrash:)); [m addItem: [NSMenuItem separatorItem]];
	ITEM(@"Get Info", @selector(cmdShowStaticInfo:)); ITEM(@"Rename", @selector(cmdRename:)); ITEM(@"Duplicate", @selector(cmdDuplicate:)); ITEM(([NSString stringWithFormat: @"Quick Look “%@”", first]), @selector(cmdQuickLook:)); ITEM(@"Copy", @selector(cmdCopyItems:)); [m addItem: [NSMenuItem separatorItem]];
	NSMenuItem *dots = ITEM(@"Tag colours", @selector(cmdToggleTag:)); [dots setTag: 2]; [dots setRepresentedObject: [NSClassFromString(@"WsdFinderSupport") tagNames]];
#undef ITEM
	return m;
}
- (void)cmdOpen:(id)s { for (NSString *p in _selection) [self iconViewOpenItem: p]; }
- (void)cmdRename:(id)s { if ([_selection count]) [_view beginRename: _selection[0]]; }
- (void)iconViewRename:(NSString *)path to:(NSString *)name { if (![name length] || [name isEqual: [path lastPathComponent]] || [name containsString: @"/"]) return; NSString *to = [[path stringByDeletingLastPathComponent] stringByAppendingPathComponent: name]; if (![[NSFileManager defaultManager] fileExistsAtPath: to] && [[NSFileManager defaultManager] moveItemAtPath: path toPath: to error: NULL]) { _selection = @[ to ]; [_view reloadKeepingSelectionOrFolder: DesktopPath()]; } }
- (void)cmdDuplicate:(id)s { NSFileManager *fm = [NSFileManager defaultManager]; for (NSString *p in _selection) { NSString *base = [[p lastPathComponent] stringByDeletingPathExtension], *ext = [p pathExtension], *dir = [p stringByDeletingLastPathComponent]; NSString *to; int i = 1; do { NSString *n = [NSString stringWithFormat: @"%@ copy%@", base, i > 1 ? [NSString stringWithFormat: @" %d", i] : @""]; to = [dir stringByAppendingPathComponent: [ext length] ? [n stringByAppendingPathExtension: ext] : n]; i++; } while ([fm fileExistsAtPath: to]); [fm copyItemAtPath: p toPath: to error: NULL]; } [_view reloadKeepingSelectionOrFolder: DesktopPath()]; }
- (void)cmdQuickLook:(id)s { if ([_selection count]) TFOpenQuickLook(_selection[0]); }
- (void)cmdCopyItems:(id)s { NSPasteboard *pb = [NSPasteboard generalPasteboard]; [pb declareTypes: @[ NSFilenamesPboardType ] owner: nil]; [pb setPropertyList: _selection forType: NSFilenamesPboardType]; }
- (void)cmdToggleTag:(NSMenuItem *)it { NSString *n = [it representedObject]; BOOL all = [_selection count] > 0; for (NSString *p in _selection) if (![TFTagsOf(p) containsObject: n]) all = NO; for (NSString *p in _selection) { NSMutableArray *cur = [TFTagsOf(p) mutableCopy]; if (all) [cur removeObject: n]; else if (![cur containsObject: n]) [cur addObject: n]; TFSetTags(cur, p); } [_view reloadKeepingSelectionOrFolder: DesktopPath()]; }
/* the menu of the desktop, as the Finder shows it: New Folder, Get Info, the background, Sort By, Clean Up, View Options */
- (NSMenu *)_desktopMenu
{
	NSMenu *m = [[NSMenu alloc] initWithTitle: @""]; NSMenuItem *it;
#define ITEM(menu, title, sel) ({ NSMenuItem *x = [menu addItemWithTitle: title action: sel keyEquivalent: @""]; [x setTarget: self]; x; })
	ITEM(m, @"New Folder", @selector(cmdNewFolder:)); [m addItem: [NSMenuItem separatorItem]];
	ITEM(m, @"Get Info", @selector(cmdShowStaticInfo:)); ITEM(m, @"Change Wallpaper…", @selector(cmdChangeBackground:)); [[m addItemWithTitle: @"Edit Widgets…" action: NULL keyEquivalent: @""] setEnabled: NO]; [m addItem: [NSMenuItem separatorItem]];       /* Edit Widgets: the Mac's widget editor does not exist here */
	NSMenuItem *us = ITEM(m, @"Use Stacks", @selector(cmdDesktopStacks:)); [us setState: [_view->_group length] ? NSOnState : NSOffState];
	NSArray *keys = @[ @[ @"Name", @"name" ], @[ @"Kind", @"kind" ], @[ @"Date Last Opened", @"opened" ], @[ @"Date Added", @"created" ], @[ @"Date Modified", @"modified" ], @[ @"Date Created", @"created" ], @[ @"Size", @"size" ], @[ @"Tags", @"tags" ] ];
	it = ITEM(m, @"Sort By", NULL); NSMenu *sb = [[NSMenu alloc] initWithTitle: @"Sort By"]; NSMenuItem *none = ITEM(sb, @"None", @selector(cmdDesktopSort:)); [none setRepresentedObject: @""]; [sb addItem: [NSMenuItem separatorItem]]; ITEM(sb, @"Snap to Grid", @selector(cmdDesktopSnap:)); [sb addItem: [NSMenuItem separatorItem]];
	for (NSArray *k in keys) { NSMenuItem *x = ITEM(sb, k[0], @selector(cmdDesktopSort:)); [x setRepresentedObject: k[1]]; } [it setSubmenu: sb];
	ITEM(m, @"Clean Up", @selector(cmdCleanUp:));
	it = ITEM(m, @"Clean Up By", NULL); NSMenu *cb = [[NSMenu alloc] initWithTitle: @"Clean Up By"]; for (NSArray *k in @[ @[ @"Name", @"name" ], @[ @"Kind", @"kind" ], @[ @"Date Modified", @"modified" ], @[ @"Date Created", @"created" ], @[ @"Size", @"size" ], @[ @"Tags", @"tags" ] ]) { NSMenuItem *x = ITEM(cb, k[0], @selector(cmdDesktopSort:)); [x setRepresentedObject: k[1]]; [x setTag: 1]; } [it setSubmenu: cb];
	[m addItem: [NSMenuItem separatorItem]]; ITEM(m, @"Show View Options", @selector(cmdDesktopViewOptions:));
#undef ITEM
	return m;
}
- (void)cmdDesktopStacks:(id)s { [_view setGroup: [_view->_group length] ? nil : @"kind"]; }
- (void)cmdDesktopSnap:(id)s { [_view setSnapToGrid: !_view->_snap]; }
/* Sort By keeps the order; Clean Up By puts the icons on the grid in that order once */
- (void)cmdDesktopSort:(NSMenuItem *)it { NSString *k = [it representedObject]; [_view arrangeBy: [k length] ? k : nil]; if ([it tag] == 1) { [_view cleanUp: NO]; [_view arrangeBy: nil]; } }
- (void)cmdDesktopViewOptions:(id)s { TFOpenViewOptions(_view, @"Desktop", ^{}); }
- (void)cmdChangeBackground:(id)s { [self performSelector: @selector(_chooseBackground) withObject: nil afterDelay: 0.1]; }
/* a picture for the desktop: kept in the preference DesktopPicture; every window tints its background with it */
- (void)_chooseBackground { NSOpenPanel *op = [NSOpenPanel openPanel]; [op setAllowedFileTypes: @[ @"png", @"jpg", @"jpeg", @"tif", @"tiff", @"bmp", @"gif" ]]; [op setPrompt: @"Choose"]; if ([op runModal] == NSOKButton && [[op URL] path]) { TFSetPref(@"DesktopPicture", [[op URL] path]); [[NSNotificationCenter defaultCenter] postNotificationName: @"TFPrefsChanged" object: nil]; } }
- (void)_cmdChangeBackgroundOld:(id)s { for (NSString *a in @[ @"/System/Applications/System Settings.app", @"/System/Applications/System Preferences.app" ]) if ([[NSFileManager defaultManager] fileExistsAtPath: a]) { [[NSWorkspace sharedWorkspace] launchApplication: a]; return; } NSBeep(); }
@end
