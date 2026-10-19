/* NSViewController: child hierarchy, presentation as sheet / modal window with presenting / presented links, preferredContentSize, transition. */
#import <AppKit/AppKit.h>
@interface NSViewController (D) - (NSArray *)childViewControllers; - (void)addChildViewController:(NSViewController *)c; - (void)insertChildViewController:(NSViewController *)c atIndex:(NSInteger)i; - (void)removeFromParentViewController;
- (NSViewController *)parentViewController; - (NSViewController *)presentingViewController; - (NSArray *)presentedViewControllers; - (void)presentViewControllerAsSheet:(NSViewController *)v; - (void)presentViewControllerAsModalWindow:(NSViewController *)v;
- (NSSize)preferredContentSize; - (void)setPreferredContentSize:(NSSize)s; - (void)loadViewIfNeeded; - (NSView *)viewIfLoaded;
- (void)transitionFromViewController:(NSViewController *)f toViewController:(NSViewController *)t options:(NSUInteger)o completionHandler:(void (^)(void))h; @end
@interface NSEvent (M) + (id)addLocalMonitorForEventsMatchingMask:(unsigned long long)mask handler:(NSEvent *(^)(NSEvent *))h; + (void)removeMonitor:(id)m; @end
static int fails;
#define CHECK(c) do { if (!(c)) { printf("FAIL %s:%d %s\n", __FILE__, __LINE__, #c); fails++; } } while (0)
@interface VC : NSViewController @end
@implementation VC - (void)loadView { [self setView: [[NSView alloc] initWithFrame: NSMakeRect(0, 0, 200, 100)]]; } @end
int main(void)
{
	@autoreleasepool {
		[NSApplication sharedApplication];
		VC *p = [[VC alloc] init], *a = [[VC alloc] init], *b = [[VC alloc] init];
		CHECK([p viewIfLoaded] == nil); [p loadViewIfNeeded]; CHECK([p viewIfLoaded] != nil);
		[p addChildViewController: a]; [p insertChildViewController: b atIndex: 0];
		CHECK([[p childViewControllers] count] == 2); CHECK([[p childViewControllers][0] isEqual: b]); CHECK([a parentViewController] == p);
		[b removeFromParentViewController]; CHECK([[p childViewControllers] count] == 1); CHECK([b parentViewController] == nil);
		NSWindow *w = [[NSWindow alloc] initWithContentRect: NSMakeRect(0, 0, 400, 300) styleMask: NSTitledWindowMask backing: NSBackingStoreBuffered defer: NO]; [w setContentView: [p view]]; [w orderFront: nil];
		VC *sheet = [[VC alloc] init]; [sheet setPreferredContentSize: NSMakeSize(300, 120)];
		[p presentViewControllerAsSheet: sheet];
		CHECK([sheet presentingViewController] == p); CHECK([[p presentedViewControllers] count] == 1); CHECK([[sheet view] window] != nil);
		CHECK(fabs([[[sheet view] window] contentRectForFrameRect: [[[sheet view] window] frame]].size.width - 300) < 1);
		[sheet setPreferredContentSize: NSMakeSize(350, 150)]; CHECK(fabs([[[sheet view] window] contentRectForFrameRect: [[[sheet view] window] frame]].size.width - 350) < 1);
		[p dismissViewController: sheet]; CHECK([sheet presentingViewController] == nil); CHECK([[p presentedViewControllers] count] == 0); CHECK([[sheet view] window] == nil);
		[b loadViewIfNeeded]; [a loadViewIfNeeded]; [[p view] addSubview: [a view]];
		__block int done = 0; [p transitionFromViewController: a toViewController: b options: 0 completionHandler: ^{ done = 1; }];
		CHECK(done == 1); CHECK([[b view] superview] == [p view]); CHECK([[a view] superview] == nil);
		__block int seen = 0; __block BOOL swallow = NO;
		id mon = [NSEvent addLocalMonitorForEventsMatchingMask: NSKeyDownMask handler: ^NSEvent *(NSEvent *e) { seen++; return swallow ? nil : e; }];
		NSEvent *k = [NSEvent keyEventWithType: NSKeyDown location: NSZeroPoint modifierFlags: 0 timestamp: 0 windowNumber: [w windowNumber] context: nil characters: @"a" charactersIgnoringModifiers: @"a" isARepeat: NO keyCode: 0];
		[NSApp sendEvent: k]; CHECK(seen == 1); swallow = YES; [NSApp sendEvent: k]; CHECK(seen == 2);
		[NSEvent removeMonitor: mon]; [NSApp sendEvent: k]; CHECK(seen == 2);
	}
	printf(fails ? "viewcontroller: %d failed\n" : "viewcontroller ok\n", fails);
	return fails != 0;
}
