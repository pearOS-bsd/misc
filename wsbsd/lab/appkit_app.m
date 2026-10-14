/* A small but typical Cocoa app: window, button, slider, text field, checkbox, scroll view with text, a menu, a timer that ends it. */
#import <Cocoa/Cocoa.h>
int main(void)
{
	@autoreleasepool {
		NSApplication *app = [NSApplication sharedApplication];
		[app setActivationPolicy:NSApplicationActivationPolicyRegular];
		NSMenu *menubar = [[NSMenu alloc] init]; NSMenuItem *mi = [[NSMenuItem alloc] init]; [menubar addItem:mi]; [app setMainMenu:menubar];
		NSMenu *m = [[NSMenu alloc] init]; [m addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@"q"]; [mi setSubmenu:m];
		NSWindow *w = [[NSWindow alloc] initWithContentRect:NSMakeRect(200, 200, 520, 360) styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable | NSWindowStyleMaskMiniaturizable) backing:NSBackingStoreBuffered defer:NO];
		[w setTitle:@"wsbsd trace"];
		NSView *v = [w contentView];
		NSButton *b = [[NSButton alloc] initWithFrame:NSMakeRect(20, 300, 120, 32)]; [b setTitle:@"Button"]; [b setBezelStyle:NSBezelStyleRounded]; [v addSubview:b];
		NSButton *c = [[NSButton alloc] initWithFrame:NSMakeRect(160, 300, 120, 32)]; [c setButtonType:NSButtonTypeSwitch]; [c setTitle:@"Check"]; [v addSubview:c];
		NSSlider *s = [[NSSlider alloc] initWithFrame:NSMakeRect(20, 250, 260, 24)]; [s setDoubleValue:40]; [v addSubview:s];
		NSTextField *t = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 210, 260, 24)]; [t setStringValue:@"Hello from Cocoa"]; [v addSubview:t];
		NSScrollView *sv = [[NSScrollView alloc] initWithFrame:NSMakeRect(20, 20, 480, 170)]; NSTextView *tv = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 460, 170)];
		[tv setString:@"Some text in a scroll view.\nSecond line, with the system font."]; [sv setDocumentView:tv]; [sv setHasVerticalScroller:YES]; [v addSubview:sv];
		[w makeKeyAndOrderFront:nil];
		[app activateIgnoringOtherApps:YES];
		[NSTimer scheduledTimerWithTimeInterval:3.0 repeats:NO block:^(NSTimer *x) { [app terminate:nil]; }];
		[app run];
	}
	return 0;
}
