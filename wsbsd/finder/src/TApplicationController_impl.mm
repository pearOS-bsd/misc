/* TApplicationController: the delegate of the Finder (decompiled: -[TApplicationController applicationWillFinishLaunching:] at 0x100011330, -loadMenuBar at 0x1000115a8: it loads the nib "MenuBar" with itself as owner). */
#import <AppKit/AppKit.h>

@interface TBrowserWindowController : NSWindowController
+ (instancetype)newBrowserWithPath:(NSString *)path;
- (void)goToPath:(NSString *)path;
@end
@interface TApplicationController : NSObject @end
@interface TApplicationController (Impl)
+ (id)sharedApplicationController;
- (void)loadMenuBar;
- (void)configureMenuBar;
@end

@implementation TApplicationController (Impl)
+ (id)sharedApplicationController { static id shared; static dispatch_once_t once; dispatch_once(&once, ^{ shared = [[self alloc] init]; }); return shared; }
- (void)applicationWillFinishLaunching:(NSNotification *)n { [self loadMenuBar]; }
- (void)applicationDidFinishLaunching:(NSNotification *)n
{
	id c = [NSClassFromString(@"TDesktopWindowController") performSelector: NSSelectorFromString(@"sharedController")]; [c performSelector: NSSelectorFromString(@"showDesktop")];
	[NSApp activateIgnoringOtherApps: YES]; if (getenv("FINDER_WINDOW")) [self cmdNewFinderWindow: nil];
}
/* the menu bar comes from the nib "MenuBar" of the bundle (the Mac's compiled nib, converted by tools/nib2plist.py when the resources are imported) */
- (void)loadMenuBar
{
	NSBundle *b = [NSBundle mainBundle]; NSString *path = [b pathForResource: @"MenuBar" ofType: @"nib"];
	if (!path) for (NSString *lp in @[ @"Base.lproj", @"en.lproj", @"English.lproj" ]) { NSString *p = [[b resourcePath] stringByAppendingPathComponent: [lp stringByAppendingPathComponent: @"MenuBar.nib"]]; if ([[NSFileManager defaultManager] fileExistsAtPath: p]) { path = p; break; } }
	NSMutableArray *top = [NSMutableArray array]; BOOL ok = path && [NSBundle loadNibFile: path externalNameTable: @{ NSNibOwner: self, NSNibTopLevelObjects: top } withZone: NSDefaultMallocZone()];
	NSLog(@"Finder: MenuBar nib %@ loaded %d, top objects %lu", path, ok, (unsigned long)[top count]);
	if (![NSApp mainMenu]) for (id o in top) if ([o isKindOfClass: [NSMenu class]]) { [NSApp setMainMenu: o]; break; }
	[self configureMenuBar];
}
- (void)configureMenuBar { }
/* actions of the menu bar: with no Finder window open they open one (the Finder's behaviour); the window controller handles them otherwise */
- (void)cmdNewFinderWindow:(id)s { [TBrowserWindowController newBrowserWithPath: NSHomeDirectory()]; }
- (void)cmdNewFinderWindowWithOption:(id)s { [self cmdNewFinderWindow: s]; }
- (void)_goTo:(NSString *)path { id c = [[NSApp keyWindow] windowController]; if ([c isKindOfClass: [TBrowserWindowController class]]) [c goToPath: path]; else [TBrowserWindowController newBrowserWithPath: path]; }
- (void)cmdGoHome:(id)s { [self _goTo: NSHomeDirectory()]; }
- (void)cmdGoToDesktop:(id)s { [self _goTo: [NSHomeDirectory() stringByAppendingPathComponent: @"Desktop"]]; }
- (void)cmdGoToDocuments:(id)s { [self _goTo: [NSHomeDirectory() stringByAppendingPathComponent: @"Documents"]]; }
- (void)cmdGoToDownloads:(id)s { [self _goTo: [NSHomeDirectory() stringByAppendingPathComponent: @"Downloads"]]; }
- (void)cmdGoToApplications:(id)s { [self _goTo: @"/Applications"]; }
- (void)cmdGoToComputer:(id)s { [self _goTo: @"/"]; }
- (BOOL)validateMenuItem:(NSMenuItem *)i
{
	SEL a = [i action]; if (a == @selector(cmdNewFinderWindow:) || a == @selector(cmdNewFinderWindowWithOption:) || a == @selector(cmdGoHome:) || a == @selector(cmdGoToDesktop:) || a == @selector(cmdGoToDocuments:) || a == @selector(cmdGoToDownloads:) || a == @selector(cmdGoToApplications:) || a == @selector(cmdGoToComputer:)) return YES;
	return [self respondsToSelector: a] || [NSApp targetForAction: a] != nil;
}
@end
