/* TDesktopWindowController: the desktop. The icons are those of ~/Desktop and of the volumes the preferences ask for (Finder > Settings > General), in the Finder's own icon view (TIconView in desktop mode: columns from the top right,
 * places that stay where they are put, Clean Up, drag into folders), on the window at the desktop icon level. A double click opens an item in a Finder window. */
#import "TDesktopWindow.h"
#import "TFinderViews.h"

@interface TBrowserWindowController : NSWindowController
+ (instancetype)newBrowserWithPath:(NSString *)path;
@end
@interface TDesktopWindowController : NSObject <TIconViewDelegate> { TDesktopWindow *_window; TIconView *_view; NSArray *_selection; NSString *_volumeSig; }
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
- (void)_poll:(NSTimer *)t { NSString *sig = [self _signature]; if (![sig isEqual: _volumeSig]) { _volumeSig = sig; [_view reloadKeepingSelectionOrFolder: DesktopPath()]; } }
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
- (void)cmdNewFolder:(id)s { NSFileManager *fm = [NSFileManager defaultManager]; NSString *p = [DesktopPath() stringByAppendingPathComponent: @"untitled folder"]; int i = 2; while ([fm fileExistsAtPath: p]) p = [DesktopPath() stringByAppendingPathComponent: [NSString stringWithFormat: @"untitled folder %d", i++]]; [fm createDirectoryAtPath: p withIntermediateDirectories: NO attributes: nil error: NULL]; [_view reloadKeepingSelectionOrFolder: DesktopPath()]; }
- (void)cmdShowStaticInfo:(id)s { for (NSString *p in _selection) TFOpenInfoWindow(p); }
- (void)cmdMoveToTrash:(id)s { NSFileManager *fm = [NSFileManager defaultManager]; NSString *tr = [NSHomeDirectory() stringByAppendingPathComponent: @".Trash"]; [fm createDirectoryAtPath: tr withIntermediateDirectories: YES attributes: nil error: NULL]; for (NSString *p in _selection) { if ([p hasPrefix: DesktopPath()]) [fm moveItemAtPath: p toPath: [tr stringByAppendingPathComponent: [p lastPathComponent]] error: NULL]; } [_view reloadKeepingSelectionOrFolder: DesktopPath()]; }
- (void)cmdCleanUp:(id)s { [_view cleanUp: NO]; }
/* the menu of the desktop, as the Finder shows it: New Folder, Get Info, the background, Sort By, Clean Up, View Options */
- (NSMenu *)_desktopMenu
{
	NSMenu *m = [[NSMenu alloc] initWithTitle: @""]; NSMenuItem *it;
#define ITEM(menu, title, sel) ({ NSMenuItem *x = [menu addItemWithTitle: title action: sel keyEquivalent: @""]; [x setTarget: self]; x; })
	ITEM(m, @"New Folder", @selector(cmdNewFolder:)); [m addItem: [NSMenuItem separatorItem]];
	ITEM(m, @"Get Info", @selector(cmdShowStaticInfo:)); ITEM(m, @"Change Desktop Background…", @selector(cmdChangeBackground:)); [m addItem: [NSMenuItem separatorItem]];
	NSArray *keys = @[ @[ @"Name", @"name" ], @[ @"Kind", @"kind" ], @[ @"Date Modified", @"modified" ], @[ @"Date Created", @"created" ], @[ @"Size", @"size" ], @[ @"Tags", @"tags" ] ];
	it = ITEM(m, @"Sort By", NULL); NSMenu *sb = [[NSMenu alloc] initWithTitle: @"Sort By"]; NSMenuItem *none = ITEM(sb, @"None", @selector(cmdDesktopSort:)); [none setRepresentedObject: @""]; [sb addItem: [NSMenuItem separatorItem]];
	for (NSArray *k in keys) { NSMenuItem *x = ITEM(sb, k[0], @selector(cmdDesktopSort:)); [x setRepresentedObject: k[1]]; } [it setSubmenu: sb];
	ITEM(m, @"Clean Up", @selector(cmdCleanUp:));
	it = ITEM(m, @"Clean Up By", NULL); NSMenu *cb = [[NSMenu alloc] initWithTitle: @"Clean Up By"]; for (NSArray *k in keys) { NSMenuItem *x = ITEM(cb, k[0], @selector(cmdDesktopSort:)); [x setRepresentedObject: k[1]]; [x setTag: 1]; } [it setSubmenu: cb];
	[m addItem: [NSMenuItem separatorItem]]; ITEM(m, @"Show View Options", @selector(cmdDesktopViewOptions:));
#undef ITEM
	return m;
}
/* Sort By keeps the order; Clean Up By puts the icons on the grid in that order once */
- (void)cmdDesktopSort:(NSMenuItem *)it { NSString *k = [it representedObject]; [_view arrangeBy: [k length] ? k : nil]; if ([it tag] == 1) { [_view cleanUp: NO]; [_view arrangeBy: nil]; } }
- (void)cmdDesktopViewOptions:(id)s { TFOpenViewOptions(_view, @"Desktop", ^{}); }
- (void)cmdChangeBackground:(id)s { [self performSelector: @selector(_chooseBackground) withObject: nil afterDelay: 0.1]; }
/* a picture for the desktop: kept in the preference DesktopPicture; every window tints its background with it */
- (void)_chooseBackground { NSOpenPanel *op = [NSOpenPanel openPanel]; [op setAllowedFileTypes: @[ @"png", @"jpg", @"jpeg", @"tif", @"tiff", @"bmp", @"gif" ]]; [op setPrompt: @"Choose"]; if ([op runModal] == NSOKButton && [[op URL] path]) { TFSetPref(@"DesktopPicture", [[op URL] path]); [[NSNotificationCenter defaultCenter] postNotificationName: @"TFPrefsChanged" object: nil]; } }
- (void)_cmdChangeBackgroundOld:(id)s { for (NSString *a in @[ @"/System/Applications/System Settings.app", @"/System/Applications/System Preferences.app" ]) if ([[NSFileManager defaultManager] fileExistsAtPath: a]) { [[NSWorkspace sharedWorkspace] launchApplication: a]; return; } NSBeep(); }
@end
