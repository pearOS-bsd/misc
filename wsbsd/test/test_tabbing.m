/* Window tabbing: groups, selection (only the selected window is on screen), closing, merge / move out, content shortened by the tab bar. */
#import <AppKit/AppKit.h>
@interface NSWindowTabGroup : NSObject - (NSArray *)windows; - (NSWindow *)selectedWindow; - (void)setSelectedWindow:(NSWindow *)w; - (BOOL)isTabBarVisible; @end
@interface NSWindow (D) - (NSWindowTabGroup *)tabGroup; - (NSArray *)tabbedWindows; - (void)addTabbedWindow:(NSWindow *)w ordered:(NSWindowOrderingMode)o; - (void)mergeAllWindows:(id)s; - (void)moveTabToNewWindow:(id)s; - (void)selectNextTab:(id)s; - (void)selectPreviousTab:(id)s; @end
static int fails;
#define CHECK(c) do { if (!(c)) { printf("FAIL %s:%d %s\n", __FILE__, __LINE__, #c); fails++; } } while (0)
static NSWindow *mk(NSString *t, NSRect f) { NSWindow *w = [[NSWindow alloc] initWithContentRect: f styleMask: NSTitledWindowMask | NSClosableWindowMask | NSResizableWindowMask backing: NSBackingStoreBuffered defer: NO]; [w setTitle: t]; [w setReleasedWhenClosed: NO]; return w; }
int main(void)
{
	@autoreleasepool {
		[NSApplication sharedApplication];
		NSWindow *a = mk(@"A", NSMakeRect(100, 100, 400, 300)), *b = mk(@"B", NSMakeRect(300, 200, 300, 200)), *c = mk(@"C", NSMakeRect(50, 50, 200, 200));
		[a makeKeyAndOrderFront: nil]; [b orderFront: nil]; [c orderFront: nil];
		CHECK([a tabbedWindows] == nil);
		NSRect cv0 = [[a contentView] frame];
		[a addTabbedWindow: b ordered: NSWindowAbove];
		CHECK([[a tabbedWindows] count] == 2); CHECK([[a tabbedWindows][0] isEqual: a]); CHECK([[a tabbedWindows][1] isEqual: b]);
		CHECK([[a tabGroup] selectedWindow] == b); CHECK([b isVisible]); CHECK(![a isVisible]);
		CHECK(NSEqualRects([b frame], [a frame]));
		CHECK([[a tabGroup] isTabBarVisible]); CHECK([[b contentView] frame].size.height < cv0.size.height - 20);
		[a addTabbedWindow: c ordered: NSWindowAbove]; CHECK([[a tabbedWindows] count] == 3); CHECK([[a tabbedWindows][1] isEqual: c]);
		CHECK([[a tabGroup] selectedWindow] == c);
		[b selectNextTab: nil]; CHECK([[a tabGroup] selectedWindow] == b); CHECK([b isVisible]); CHECK(![c isVisible]);
		[a selectNextTab: nil]; CHECK([[a tabGroup] selectedWindow] == a); CHECK([a isVisible]);
		[a selectPreviousTab: nil]; CHECK([[a tabGroup] selectedWindow] == b);
		[c moveTabToNewWindow: nil]; CHECK([[a tabbedWindows] count] == 2); CHECK([c tabbedWindows] == nil); CHECK([c isVisible]);
		[b close]; CHECK([a tabbedWindows] == nil); CHECK([a isVisible]);
		CHECK(fabs([[a contentView] frame].size.height - cv0.size.height) < 0.5);
		NSWindow *d = mk(@"D", NSMakeRect(0, 0, 200, 100)); [d orderFront: nil]; [a mergeAllWindows: nil]; CHECK([[a tabbedWindows] count] == 3 || [[a tabbedWindows] count] == 2);
	}
	printf(fails ? "tabbing: %d failed\n" : "tabbing ok\n", fails);
	return fails != 0;
}
