/* A window whose responder chain provides a Touch Bar: the host must show it (WSBSD_TBDUMP=1 prints what it found). */
#import <Cocoa/Cocoa.h>
@interface Win : NSWindow <NSTouchBarDelegate> @end
@implementation Win
- (NSTouchBar *)makeTouchBar
{
	NSTouchBar *b = [NSTouchBar new]; [b setDelegate: self];
	[b setDefaultItemIdentifiers: @[ @"com.test.back", @"com.test.title", NSTouchBarItemIdentifierFlexibleSpace, @"com.test.slider", NSTouchBarItemIdentifierFixedSpaceSmall, @"com.test.group" ]];
	return b;
}
- (NSTouchBarItem *)touchBar:(NSTouchBar *)bar makeItemForIdentifier:(NSTouchBarItemIdentifier)i
{
	if ([i isEqual: @"com.test.back"]) return [NSButtonTouchBarItem buttonTouchBarItemWithIdentifier: i title: @"Back" target: self action: @selector(hit:)];
	if ([i isEqual: @"com.test.title"]) { NSCustomTouchBarItem *c = [[NSCustomTouchBarItem alloc] initWithIdentifier: i]; NSTextField *t = [NSTextField labelWithString: @"Touch Bar demo"]; [t setTextColor: [NSColor whiteColor]]; [t sizeToFit]; [c setView: t]; return c; }
	if ([i isEqual: @"com.test.slider"]) { NSSliderTouchBarItem *s = [[NSSliderTouchBarItem alloc] initWithIdentifier: i]; [s setDoubleValue: 0.4]; return s; }
	if ([i isEqual: @"com.test.group"]) return [NSGroupTouchBarItem groupItemWithIdentifier: i items: @[ [NSButtonTouchBarItem buttonTouchBarItemWithIdentifier: @"a" title: @"A" target: self action: @selector(hit:)], [NSButtonTouchBarItem buttonTouchBarItemWithIdentifier: @"b" title: @"B" target: self action: @selector(hit:)] ]];
	return nil;
}
- (void)hit:(id)s { fprintf(stderr, "touchbar button hit\n"); }
@end
int main(int argc, char **argv)
{
	@autoreleasepool {
		[NSApplication sharedApplication];
		Win *w = [[Win alloc] initWithContentRect: NSMakeRect(200, 300, 420, 200) styleMask: NSWindowStyleMaskTitled | NSWindowStyleMaskClosable backing: NSBackingStoreBuffered defer: NO]; [w setTitle: @"Touch Bar test"]; [w makeKeyAndOrderFront: nil];
		[NSApp activateIgnoringOtherApps: YES];
		[NSTimer scheduledTimerWithTimeInterval: 3 repeats: NO block: ^(NSTimer *t) { WsbsdTouchBarHost *h = [WsbsdTouchBarHost sharedHost]; NSPanel *p = [h panel]; fprintf(stderr, "bar %p visible=%d panel=%d subviews=%lu\n", [h currentTouchBar], [[h currentTouchBar] isVisible], [p isVisible], (unsigned long)[[[[p contentView] subviews] lastObject] subviews].count); }];
		[NSApp run];
	}
	return 0;
}
