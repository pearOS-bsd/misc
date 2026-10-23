/* TApplicationController: the delegate of the Finder (decompiled: -[TApplicationController applicationWillFinishLaunching:] at 0x100011330, -loadMenuBar at 0x1000115a8: it loads the nib "MenuBar" with itself as owner). */
#import <Cocoa/Cocoa.h>
#import "TFinderViews.h"

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
	[NSApp activateIgnoringOtherApps: YES]; [self _hookRecentFolders]; if (getenv("FINDER_DUMPMENU")) [self cmdDumpMenu]; if (getenv("FINDER_WINDOW")) [self cmdNewFinderWindow: nil];
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
static void DumpMenu(NSMenu *m, int d, NSMutableString *out) { for (NSMenuItem *i in [m itemArray]) { [out appendFormat: @"%*s%@\t%@\t%@\n", d * 2, "", [i title], [i isSeparatorItem] ? @"--" : NSStringFromSelector([i action]), [i keyEquivalent]]; if ([i submenu]) DumpMenu([i submenu], d + 1, out); } }
- (void)cmdDumpMenu { NSMutableString *o = [NSMutableString string]; DumpMenu([NSApp mainMenu], 0, o); [o writeToFile: @"/tmp/finder_menu_actions.txt" atomically: YES encoding: NSUTF8StringEncoding error: NULL]; }
/* Go > Recent Folders: the menu lists the folders last shown (kept in the preferences) */
- (void)menuNeedsUpdate:(NSMenu *)menu
{
	if ([[menu title] isEqual: @"Group By"] || [[menu title] isEqual: @"Sort By"]) { [self _fillArrangeMenu: menu group: [[menu title] isEqual: @"Group By"]]; return; }
	while ([menu numberOfItems]) [menu removeItemAtIndex: 0]; NSArray *rf = TFPref(@"FXRecentFolders", @[]);
	for (NSString *p in rf) { NSMenuItem *it = [menu addItemWithTitle: TFDisplayName(p) action: NSSelectorFromString(@"cmdGoToRecent:") keyEquivalent: @""]; [it setRepresentedObject: p]; }
	if ([rf count]) [menu addItem: [NSMenuItem separatorItem]]; [menu addItemWithTitle: @"Clear Menu" action: NSSelectorFromString(@"cmdClearRecentFolders:") keyEquivalent: @""];
}
/* View > Group By and Sort By: the sub menus are filled when the menu opens, with the mark of what is on */
- (void)_fillArrangeMenu:(NSMenu *)menu group:(BOOL)group
{
	while ([menu numberOfItems]) [menu removeItemAtIndex: 0]; id win = [[NSApp keyWindow] windowController]; id ic = [win respondsToSelector: @selector(_icons)] ? nil : nil; (void)ic; NSString *cur = nil; Class bc = NSClassFromString(@"TBrowserWindowController"); if ([win isKindOfClass: bc]) cur = [win valueForKey: group ? @"currentGroup" : @"currentSort"];
	NSArray *opts = group ? @[ @[ @"None", @"" ], @[ @"Name", @"name" ], @[ @"Kind", @"kind" ], @[ @"Date Last Opened", @"dateLastOpened" ], @[ @"Date Modified", @"dateModified" ], @[ @"Date Created", @"dateCreated" ], @[ @"Size", @"size" ], @[ @"Tags", @"tags" ] ] : @[ @[ @"None", @"" ], @[ @"-", @"" ], @[ @"Name", @"name" ], @[ @"Kind", @"kind" ], @[ @"Date Modified", @"modified" ], @[ @"Date Created", @"created" ], @[ @"Size", @"size" ], @[ @"Tags", @"tags" ] ];
	for (NSArray *o in opts) { if ([o[0] isEqual: @"-"]) { [menu addItem: [NSMenuItem separatorItem]]; continue; } NSMenuItem *it = [menu addItemWithTitle: o[0] action: NSSelectorFromString(group ? @"cmdGroupByKey:" : @"cmdSortByKey:") keyEquivalent: @""]; [it setRepresentedObject: o[1]]; [it setState: [o[1] isEqual: cur ?: @""] ? NSOnState : NSOffState]; }
}
/* Connect to Server… (File menu actions reach the application first: the stub of the generated class would swallow it) */
- (void)cmdConnectTo:(id)s { Class bc = NSClassFromString(@"TBrowserWindowController"); id w = [[NSApp keyWindow] windowController]; if (![w isKindOfClass: bc]) { w = nil; for (NSWindow *x in [NSApp windows]) if ([[x windowController] isKindOfClass: bc]) { w = [x windowController]; break; } } if (!w) { [self cmdNewFinderWindow: nil]; for (NSWindow *x in [NSApp windows]) if ([[x windowController] isKindOfClass: bc]) { w = [x windowController]; break; } } [w performSelector: @selector(cmdConnectToServer:) withObject: s]; }
- (void)cmdClearRecentFolders:(id)s { TFSetPref(@"FXRecentFolders", @[]); }
/* the alternate items of the Finder's menus (shown when Option is held) and the cloud entries that appear only with providers installed are hidden */
- (void)_hideAlternates:(NSMenu *)m
{
	NSSet *alts = [NSSet setWithObjects: @"cmdNewFinderWindowWithOption:", @"cmdOpenAltBrowse:", @"cmdOpenOptionBrowse:", @"cmdOpenParentAltBrowse:", @"cmdSelectStartupDisk:", @"cmdOpenWithOptionDownArrow:", @"cmdDuplicateExactly:", @"cmdEjectOne:", @"cmdEjectAll:", @"cmdArchiveWithPassword:", @"cmdShowStaticInfoSummary:", @"cmdShowInspector:", @"cmdCopyAsPathname:", @"cmdCopyAsLink:", @"cmdMoveItemsHere:", @"cmdPasteExactly:", @"cmdAlternateFindFile:", @"cmdEmptyTrashSilently:", @"cmdGoToICloudProviders:", @"cmdGoToDataSeparatedICloud:", @"cmdAlwaysOpenWith:", @"cmdDeselectAll:", nil]; NSMutableSet *seen = [NSMutableSet set];
	for (NSMenuItem *i in [m itemArray]) { NSString *t = [i title], *act = NSStringFromSelector([i action]); if ([alts containsObject: act]) [i setHidden: YES]; else if ([t length] && ![i isSeparatorItem] && [seen containsObject: t]) [i setHidden: YES]; [seen addObject: t ?: @""]; if ([i submenu]) [self _hideAlternates: [i submenu]]; }
}
- (void)_hookRecentFolders { [self _hideAlternates: [NSApp mainMenu]]; for (NSMenuItem *top in [[NSApp mainMenu] itemArray]) for (NSMenuItem *i in [[top submenu] itemArray]) if ([NSStringFromSelector([i action]) isEqual: @"cmdRecentFolders:"] && [i submenu]) { [[i submenu] setDelegate: (id)self]; [self menuNeedsUpdate: [i submenu]]; }
	for (NSMenuItem *top in [[NSApp mainMenu] itemArray]) for (NSMenuItem *i in [[top submenu] itemArray]) { NSString *act = NSStringFromSelector([i action]); { NSString *ke = [i keyEquivalent]; if ([ke length] == 1) { unichar c = [ke characterAtIndex: 0]; if (c >= 'A' && c <= 'Z') { [i setKeyEquivalent: [ke lowercaseString]]; [i setKeyEquivalentModifierMask: [i keyEquivalentModifierMask] | NSShiftKeyMask]; } } }      /* the nib keeps a capital for Shift-Command: the shift is part of the mask */ if ([act isEqual: @"cmdMoveToTrash:"]) { [i setKeyEquivalent: @"\x7f"]; [i setKeyEquivalentModifierMask: NSCommandKeyMask]; } else if ([act isEqual: @"cmdEmptyTrash:"]) { [i setKeyEquivalent: @"\x7f"]; [i setKeyEquivalentModifierMask: NSCommandKeyMask | NSShiftKeyMask]; } else if ([act isEqual: @"cmdTogglePreviewPane:"]) { [i setKeyEquivalent: @"p"]; [i setKeyEquivalentModifierMask: NSCommandKeyMask | NSShiftKeyMask]; } else if ([act isEqual: @"cmdDeleteImmediately:"]) { [i setKeyEquivalent: @"\x7f"]; [i setKeyEquivalentModifierMask: NSCommandKeyMask | NSAlternateKeyMask]; } if (([act isEqual: @"cmdArrange:"] || [act isEqual: @"cmdSortBy:"]) && [i submenu]) { [[i submenu] setTitle: [act isEqual: @"cmdArrange:"] ? @"Group By" : @"Sort By"]; [[i submenu] setDelegate: (id)self]; [self menuNeedsUpdate: [i submenu]]; } } }
/* a click on the Finder's Dock icon with no Finder window open opens one */
- (BOOL)applicationShouldHandleReopen:(NSApplication *)app hasVisibleFlag:(BOOL)flag { BOOL any = NO; for (NSWindow *w in [NSApp windows]) if ([w isVisible] && [w isKindOfClass: NSClassFromString(@"TFinderWindow")]) any = YES; if (!any) [self cmdNewFinderWindow: nil]; return YES; }
- (NSMenu *)applicationDockMenu:(NSApplication *)app { NSMenu *m = [[NSMenu alloc] initWithTitle: @""]; NSMenuItem *it = [m addItemWithTitle: @"New Finder Window" action: @selector(cmdNewFinderWindow:) keyEquivalent: @""]; [it setTarget: self]; return m; }
- (void)cmdAbout:(id)s { NSAlert *al = [[NSAlert alloc] init]; [al setMessageText: @"Finder"]; [al setInformativeText: @"Finder for wsbsd\nThe desktop of the system, drawn and behaving like the Mac's."]; [al runModal]; }
- (void)cmdNewFinderWindow:(id)s { NSString *t = TFPref(@"NewWindowTarget", @"PfHm"); NSString *h = NSHomeDirectory(); NSString *p = [t isEqual: @"PfDe"] ? [h stringByAppendingPathComponent: @"Desktop"] : [t isEqual: @"PfDo"] ? [h stringByAppendingPathComponent: @"Documents"] : [t isEqual: @"PfCm"] ? @"/" : h; [TBrowserWindowController newBrowserWithPath: getenv("FINDER_PATH") ? @(getenv("FINDER_PATH")) : p]; }
- (void)cmdPreferences:(id)s { TFOpenSettings(); }
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
