/* three windows merged into one tab group (screenshot with wsshot) */
#import <AppKit/AppKit.h>
@interface NSWindow (D) - (void)addTabbedWindow:(NSWindow *)w ordered:(NSWindowOrderingMode)o; @end
int main(void)
{
	@autoreleasepool {
		[NSApplication sharedApplication]; [NSApp finishLaunching];
		NSWindow *first = nil;
		for (NSString *t in @[ @"Documents", @"Downloads", @"Projects" ]) {
			NSWindow *w = [[NSWindow alloc] initWithContentRect: NSMakeRect(160, 260, 560, 320) styleMask: NSTitledWindowMask | NSClosableWindowMask | NSResizableWindowMask | NSMiniaturizableWindowMask backing: NSBackingStoreBuffered defer: NO];
			[w setTitle: t]; NSTextField *l = [NSTextField labelWithString: [t stringByAppendingString: @" tab"]]; [l setFont: [NSFont systemFontOfSize: 28]]; [l setFrame: NSMakeRect(40, 200, 400, 40)]; [[w contentView] addSubview: l];
			if (!first) { first = w; [w makeKeyAndOrderFront: nil]; } else [first addTabbedWindow: w ordered: NSWindowAbove];
		}
		[NSTimer scheduledTimerWithTimeInterval: 12 target: NSApp selector: @selector(terminate:) userInfo: nil repeats: NO];
		[NSApp run];
	}
	return 0;
}
