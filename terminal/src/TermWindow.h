#import <AppKit/AppKit.h>
#import "TermView.h"

/* One Terminal window: a tab bar (shown with two or more tabs, or when asked for), the terminal views of the tabs, a find bar. The profile's blur is a behind-window visual effect. */
@interface TermWindowController : NSObject
{
	NSWindow *window; NSMutableArray *tabs; NSUInteger current; NSView *root, *host, *effect, *findBar; NSView *tabBar; NSTextField *findField; BOOL forceTabBar, findShown, findCase;
}
+ (NSMutableArray *)all;
- (instancetype)initWithProfile:(TermProfile *)p command:(NSString *)cmd;
- (NSWindow *)window;
- (TermView *)term;
- (NSArray *)tabs; - (NSUInteger)currentIndex;
- (void)newTabWithProfile:(TermProfile *)p command:(NSString *)cmd;
- (void)selectTab:(NSUInteger)i;
- (void)closeTab:(NSUInteger)i;
- (void)closeCurrentTab:(id)sender;
- (void)nextTab:(id)sender; - (void)previousTab:(id)sender;
- (void)toggleTabBar:(id)sender; - (BOOL)tabBarShown;
- (void)showFindBar:(id)sender; - (void)hideFindBar:(id)sender; - (void)findNext:(id)sender; - (void)findPrevious:(id)sender; - (void)useSelectionForFind:(id)sender;
- (void)applyProfileToCurrent:(TermProfile *)p;
- (void)layoutViews;
@end
