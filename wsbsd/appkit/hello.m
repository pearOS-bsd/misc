/* the smallest AppKit program: an application, a window with a button and a text field, run for a moment and quit */
#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSDisplayServer.h>

@interface Hello : NSObject { @public NSTextField *field; NSWindow *win; }
- (void)clicked:(id)sender;
@end
@implementation Hello
- (void)resize:(id)sender { NSLog(@"resizing"); [win setFrame:NSMakeRect(300, 300, 480, 260) display:YES]; NSLog(@"frame now %@", NSStringFromRect([win frame])); }
- (void)check:(id)sender { NSLog(@"frame after resize %@", NSStringFromRect([win frame])); }
- (void)quit:(id)sender { NSLog(@"done"); [NSApp terminate:nil]; }
- (void)clicked:(id)sender { NSLog(@"button clicked"); [field setStringValue:@"Clicked!"]; }
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
	h->field = t; h->win = w;
	[w makeKeyAndOrderFront:nil];
	NSLog(@"window shown, frame %@ number %d visible %d bgapp %d hidden %d active %d", NSStringFromRect([w frame]), (int)[w windowNumber], (int)[w isVisible], (int)[[NSUserDefaults standardUserDefaults] boolForKey:@"GSBackgroundApp"], (int)[NSApp isHidden], (int)[NSApp isActive]);
	[NSTimer scheduledTimerWithTimeInterval:([[NSUserDefaults standardUserDefaults] doubleForKey:@"HelloSeconds"] ?: 1.0) target:h selector:@selector(quit:) userInfo:nil repeats:NO];
	[NSTimer scheduledTimerWithTimeInterval:12.0 target:h selector:@selector(resize:) userInfo:nil repeats:NO];
	[NSTimer scheduledTimerWithTimeInterval:13.5 target:h selector:@selector(check:) userInfo:nil repeats:NO];
	[app run];
	return 0;
}
