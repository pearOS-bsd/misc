/* a window with an NSToolbar whose items carry SF Symbol images and a segmented control with symbol images */
#import <AppKit/AppKit.h>
@interface NSImage (S) + (NSImage *)imageWithSystemSymbolName:(NSString *)n accessibilityDescription:(NSString *)d; @end
@interface TD : NSObject <NSToolbarDelegate> @end
@implementation TD
- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)t { return @[ @"seg", @"open", @"eye", @"trash" ]; }
- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)t { return @[ @"seg", @"open", @"eye", @"trash" ]; }
- (NSToolbarItem *)toolbar:(NSToolbar *)t itemForItemIdentifier:(NSString *)i willBeInsertedIntoToolbar:(BOOL)f
{
	NSToolbarItem *it = [[NSToolbarItem alloc] initWithItemIdentifier: i];
	if ([i isEqual: @"seg"]) {
		NSSegmentedControl *sc = [[NSSegmentedControl alloc] initWithFrame: NSMakeRect(0, 0, 80, 28)];
		[sc setSegmentCount: 2];
		[sc setImage: [NSImage imageWithSystemSymbolName: @"plus" accessibilityDescription: nil] forSegment: 0];
		[sc setImage: [NSImage imageWithSystemSymbolName: @"minus" accessibilityDescription: nil] forSegment: 1];
		NSView *box = [[NSView alloc] initWithFrame: NSMakeRect(0, 0, 122, 61)]; [sc setFrame: NSMakeRect(18, 18, 86, 24)];
		for (int k = 0; k < 2; k++) [sc setWidth: 26 forSegment: k];
		[box addSubview: sc]; [sc removeFromSuperview]; [it setView: sc]; (void)box; [it setLabel: @"Zoom"];
	} else {
		[it setImage: [NSImage imageWithSystemSymbolName: i accessibilityDescription: nil] ?: [NSImage imageWithSystemSymbolName: @"folder" accessibilityDescription: nil]];
		[it setLabel: i];
	}
	return it;
}
@end
int main(void)
{
	@autoreleasepool {
		[NSApplication sharedApplication];
		[NSApp finishLaunching];
		NSWindow *w = [[NSWindow alloc] initWithContentRect: NSMakeRect(100, 300, 540, 220) styleMask: NSTitledWindowMask | NSClosableWindowMask backing: NSBackingStoreBuffered defer: NO];
		static TD *td; td = [TD new];
		NSToolbar *tb = [[NSToolbar alloc] initWithIdentifier: @"t"]; [tb setDelegate: td]; [w setToolbar: tb];
		NSImage *sy = [NSImage imageWithSystemSymbolName: @"trash" accessibilityDescription: nil];
		NSButton *b1 = [[NSButton alloc] initWithFrame: NSMakeRect(20, 120, 90, 32)]; [b1 setImage: sy]; [b1 setTitle: @"btn"]; [[w contentView] addSubview: b1];
		NSButton *b2 = [[NSButton alloc] initWithFrame: NSMakeRect(130, 120, 60, 32)]; [b2 setImage: sy]; [b2 setImagePosition: NSImageOnly]; [[w contentView] addSubview: b2];
		NSImageView *iv = [[NSImageView alloc] initWithFrame: NSMakeRect(210, 120, 40, 40)]; [iv setImage: sy]; [[w contentView] addSubview: iv];
		NSButton *b3 = [[NSButton alloc] initWithFrame: NSMakeRect(270, 100, 80, 60)]; [b3 setImage: sy]; [b3 setTitle: @"above"]; [b3 setImagePosition: NSImageAbove]; [b3 setBordered: NO]; [[w contentView] addSubview: b3];
		{ NSArray *nm = @[ @"plus", @"minus", @"arrow.up", @"arrow.down", @"chevron.up", @"chevron.down", @"arrow.up.left.and.arrow.down.right", @"arrow.down.right.and.arrow.up.left" ];
		  for (NSUInteger k = 0; k < [nm count]; k++) { NSImage *im = [NSImage imageWithSystemSymbolName: nm[k] accessibilityDescription: nil]; NSImageView *v = [[NSImageView alloc] initWithFrame: NSMakeRect(20 + 40 * k, 30, 30, 30)]; [v setImage: im]; [[w contentView] addSubview: v]; fprintf(stderr, "%s -> %s\n", [nm[k] UTF8String], im ? "ok" : "nil"); } }
		[w orderFront: nil];
		[NSTimer scheduledTimerWithTimeInterval: 12 target: NSApp selector: @selector(terminate:) userInfo: nil repeats: NO];
		[NSApp run];
	}
	return 0;
}
