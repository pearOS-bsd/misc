// a typical small Cocoa program: delegate, main menu, activation, a window with a scroll view + text view, a label and a button
#import <Cocoa/Cocoa.h>
@interface D : NSObject <NSApplicationDelegate> { NSWindow *w; } @end
@implementation D
- (void)applicationDidFinishLaunching:(NSNotification *)n {
  NSMenu *bar = [[NSMenu alloc] init]; NSMenuItem *mi = [[NSMenuItem alloc] init]; [bar addItem:mi];
  NSMenu *m = [[NSMenu alloc] initWithTitle:@"app2"]; [m addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@"q"]; [mi setSubmenu:m];
  [NSApp setMainMenu:bar];
  w = [[NSWindow alloc] initWithContentRect:NSMakeRect(300, 300, 480, 320) styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:NO];
  [w setTitle:@"app2"];
  NSScrollView *sv = [[NSScrollView alloc] initWithFrame:NSMakeRect(10, 50, 460, 260)]; [sv setHasVerticalScroller:YES];
  NSTextView *tv = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 440, 260)]; [tv setString:@"Hello from a typical Cocoa app. This text wraps around the width of the view because it is laid out by the real NSLayoutManager.\nSecond paragraph.\n1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n11\n12\n13\n14\n15\n16"]; [sv setDocumentView:tv];
  [[w contentView] addSubview:sv];
  NSTextField *l = [NSTextField labelWithString:@"label"]; [l setFrame:NSMakeRect(10, 15, 200, 24)]; [[w contentView] addSubview:l];
  NSButton *b = [NSButton buttonWithTitle:@"OK" target:self action:@selector(ok:)]; [b setFrame:NSMakeRect(380, 10, 90, 32)]; [[w contentView] addSubview:b];
  [w makeKeyAndOrderFront:nil];
  [NSApp activateIgnoringOtherApps:YES];
}
- (void)ok:(id)s { NSLog(@"app2: OK"); }
@end
int main(void) { @autoreleasepool { NSApplication *a = [NSApplication sharedApplication]; [a setActivationPolicy:NSApplicationActivationPolicyRegular]; D *d = [D new]; [a setDelegate:d]; [a run]; } return 0; }
