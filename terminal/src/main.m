/* Terminal: a terminal emulator application written from scratch against the public Cocoa API (also builds on GNUstep). */
#import <AppKit/AppKit.h>
#import "TermView.h"

#ifdef GNUSTEP
#define NSWindowStyleMaskTitled NSTitledWindowMask
#define NSWindowStyleMaskClosable NSClosableWindowMask
#define NSWindowStyleMaskMiniaturizable NSMiniaturizableWindowMask
#define NSWindowStyleMaskResizable NSResizableWindowMask
#endif

@interface TermApp : NSObject
- (void)finish:(NSTimer *)t;
- (void)typeInitial:(NSTimer *)t;
- (void)newWindow:(id)sender;
@end

@implementation TermApp
- (void)newWindow:(id)sender
{
	(void)sender;
	TermView *v = [[TermView alloc] initWithShell:nil];
	NSSize sz = [v idealSizeForCols:80 rows:24];
	NSRect cr = NSMakeRect(80 + 24 * [[NSApp windows] count], 160, sz.width, sz.height);
	NSWindow *w = [[NSWindow alloc] initWithContentRect:cr styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable) backing:NSBackingStoreBuffered defer:NO];
	[w setTitle:@"Terminal"]; [w setContentView:v]; [v setFrameSize:sz]; [w makeFirstResponder:v]; [w makeKeyAndOrderFront:nil];
	const char *init = getenv("TERMINAL_INITIAL_INPUT");                       /* for automated runs: text typed into the shell shortly after start */
	const char *quitAfter = getenv("TERMINAL_EXIT_AFTER");
	if (quitAfter && atof(quitAfter) > 0) [NSTimer scheduledTimerWithTimeInterval:atof(quitAfter) target:self selector:@selector(finish:) userInfo:nil repeats:NO];
	if (init && *init) [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(typeInitial:) userInfo:v repeats:NO];
}
- (void)finish:(NSTimer *)t
{
	const char *dump = getenv("TERMINAL_DUMP");                                          /* automated runs: write the screen text, then quit */
	if (dump && *dump) { for (NSWindow *w in [NSApp windows]) if ([[w contentView] isKindOfClass:[TermView class]]) { [(TermView *)[w contentView] dumpScreenToFile:[NSString stringWithUTF8String:dump]]; break; } }
	[NSApp terminate:nil];
}
- (void)typeInitial:(NSTimer *)t { [(TermView *)[t userInfo] writeString:[NSString stringWithUTF8String:getenv("TERMINAL_INITIAL_INPUT")]]; }
- (void)applicationDidFinishLaunching:(NSNotification *)n { (void)n; [self newWindow:nil]; }
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)a { (void)a; return YES; }
@end

static NSMenuItem *item(NSMenu *m, NSString *title, SEL sel, NSString *key, id target)
{
	NSMenuItem *i = [[NSMenuItem alloc] initWithTitle:title action:sel keyEquivalent:key]; if (target) [i setTarget:target]; [m addItem:i]; return i;
}

int main(int argc, char **argv)
{
	(void)argc; (void)argv;
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSApplication *app = [NSApplication sharedApplication];
	TermApp *d = [[TermApp alloc] init]; [app setDelegate:(id)d];
	NSMenu *bar = [[NSMenu alloc] initWithTitle:@""];
	NSMenuItem *appItem = [[NSMenuItem alloc] initWithTitle:@"Terminal" action:NULL keyEquivalent:@""]; [bar addItem:appItem];
	NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"Terminal"]; item(appMenu, @"Quit Terminal", @selector(terminate:), @"q", nil); [appItem setSubmenu:appMenu];
	NSMenuItem *shellItem = [[NSMenuItem alloc] initWithTitle:@"Shell" action:NULL keyEquivalent:@""]; [bar addItem:shellItem];
	NSMenu *shellMenu = [[NSMenu alloc] initWithTitle:@"Shell"]; item(shellMenu, @"New Window", @selector(newWindow:), @"n", d); item(shellMenu, @"Close Window", @selector(performClose:), @"w", nil); [shellItem setSubmenu:shellMenu];
	NSMenuItem *editItem = [[NSMenuItem alloc] initWithTitle:@"Edit" action:NULL keyEquivalent:@""]; [bar addItem:editItem];
	NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];
	item(editMenu, @"Copy", @selector(copy:), @"c", nil); item(editMenu, @"Paste", @selector(paste:), @"v", nil); item(editMenu, @"Select All", @selector(selectAll:), @"a", nil); item(editMenu, @"Clear Screen", @selector(clearScreen:), @"k", nil);
	[editItem setSubmenu:editMenu];
	[app setMainMenu:bar];
	[app run];
	[pool release];
	return 0;
}
