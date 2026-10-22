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
	_view = [[TIconView alloc] initWithFrame: [[_window contentView] bounds]]; _view->desktop = YES; _view->delegate = self; [_view setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable]; [[_window contentView] addSubview: _view];
	NSMenu *m = [[NSMenu alloc] initWithTitle: @""]; for (NSArray *e in @[ @[ @"New Folder", @"cmdNewFolder:" ], @[ @"Get Info", @"cmdShowStaticInfo:" ], @[ @"Move to Trash", @"cmdMoveToTrash:" ], @[ @"Clean Up", @"cmdCleanUp:" ] ]) { NSMenuItem *it = [m addItemWithTitle: e[0] action: NSSelectorFromString(e[1]) keyEquivalent: @""]; [it setTarget: self]; } [_view setMenu: m];
	[_view setFolder: DesktopPath()]; _volumeSig = [self _signature]; [NSTimer scheduledTimerWithTimeInterval: 2 target: self selector: @selector(_poll:) userInfo: nil repeats: YES];
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(_prefs:) name: @"TFPrefsChanged" object: nil]; [_window orderBack: nil];
}
- (void)_prefs:(NSNotification *)n { _volumeSig = nil; [self _poll: nil]; }
- (void)iconViewOpenItem:(NSString *)path { BOOL d = NO; [[NSFileManager defaultManager] fileExistsAtPath: path isDirectory: &d]; if (d && ![[path pathExtension] isEqual: @"app"]) [TBrowserWindowController newBrowserWithPath: path]; else [[NSWorkspace sharedWorkspace] openFile: path]; }
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
@end
