/* TApplicationController: the delegate of the Finder (decompiled: -[TApplicationController applicationWillFinishLaunching:] at 0x100011330, -loadMenuBar at 0x1000115a8). */
#import <AppKit/AppKit.h>

@interface TApplicationController : NSObject @end
@interface TApplicationController (Impl)
+ (id)sharedApplicationController;
- (void)loadMenuBar;
- (void)configureMenuBar;
@end

@implementation TApplicationController (Impl)
+ (id)sharedApplicationController { static id shared; static dispatch_once_t once; dispatch_once(&once, ^{ shared = [[self alloc] init]; }); return shared; }
- (void)applicationWillFinishLaunching:(NSNotification *)n { [self loadMenuBar]; }
- (void)applicationDidFinishLaunching:(NSNotification *)n { [NSApp activateIgnoringOtherApps: YES]; }
/* the menu bar comes from the nib "MenuBar" of the bundle */
- (void)loadMenuBar { NSArray *top = nil; [[NSBundle mainBundle] loadNibNamed: @"MenuBar" owner: self topLevelObjects: &top]; [self configureMenuBar]; }
- (void)configureMenuBar { }
@end
