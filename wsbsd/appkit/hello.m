/* the smallest AppKit program: an application, a window with a button and a text field, run for a moment and quit */
#import <AppKit/AppKit.h>

@interface Hello : NSObject
- (void)clicked:(id)sender;
@end
@implementation Hello
- (void)clicked:(id)sender { NSLog(@"button clicked"); }
@end

int main(int argc, char **argv)
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSApplication *app = [NSApplication sharedApplication];
	Hello *h = [[Hello alloc] init];
	NSWindow *w = [[NSWindow alloc] initWithContentRect:NSMakeRect(100, 100, 360, 200) styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSResizableWindowMask) backing:NSBackingStoreBuffered defer:NO];
	[w setTitle:@"wsbsd AppKit"];
	NSButton *b = [[NSButton alloc] initWithFrame:NSMakeRect(20, 130, 120, 32)];
	[b setTitle:@"Click me"]; [b setTarget:h]; [b setAction:@selector(clicked:)];
	[[w contentView] addSubview:b];
	NSTextField *t = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 80, 200, 24)];
	[t setStringValue:@"Hello from GNUstep AppKit"];
	[[w contentView] addSubview:t];
	[w makeKeyAndOrderFront:nil];
	NSLog(@"window shown, frame %@", NSStringFromRect([w frame]));
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
	NSLog(@"done");
	[pool release];
	return 0;
}
