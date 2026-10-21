/* NSScreen conversions, per segment calls of NSSegmentedControl, NSToolbar identifiers, NSTextField preferredMaxLayoutWidth, NSLevelIndicator and layout guides (appkit/back-wsd/WsdMoreAppKit.m) */
#import <AppKit/AppKit.h>
@interface NSScreen (T) - (NSRect)convertRectToBacking:(NSRect)r; - (NSRect)convertRectFromBacking:(NSRect)r; - (NSString *)localizedName; - (NSInteger)maximumFramesPerSecond; + (BOOL)screensHaveSeparateSpaces; - (NSRect)backingAlignedRect:(NSRect)r options:(NSAlignmentOptions)o; @end
@interface NSSegmentedControl (T) - (NSInteger)tagForSegment:(NSInteger)s; - (void)setTag:(NSInteger)t forSegment:(NSInteger)s; - (double)doubleValueForSelectedSegment; - (NSInteger)indexOfSelectedItem; - (void)setSegmentDistribution:(NSInteger)v; - (NSInteger)segmentDistribution; @end
@interface NSToolbar (T) - (NSArray *)itemIdentifiers; - (void)removeItemWithItemIdentifier:(NSString *)i; - (void)setCenteredItemIdentifier:(NSString *)i; - (NSString *)centeredItemIdentifier; @end
@interface NSTextField (T) - (void)setPreferredMaxLayoutWidth:(CGFloat)w; - (CGFloat)preferredMaxLayoutWidth; - (void)setMaximumNumberOfLines:(NSInteger)n; - (NSInteger)maximumNumberOfLines; - (NSSize)intrinsicContentSize; @end
@interface NSLevelIndicator (T) - (void)setFillColor:(NSColor *)c; - (NSColor *)fillColor; - (void)setLevelIndicatorStyle:(NSInteger)s; - (NSInteger)levelIndicatorStyle; - (BOOL)drawsTieredCapacityLevels; @end
@interface NSView (T) - (id)safeAreaLayoutGuide; @end
static int fails;
#define CHECK(c) do { if (!(c)) { printf("FAIL %s:%d %s\n", __FILE__, __LINE__, #c); fails++; } } while (0)
@interface D : NSObject <NSToolbarDelegate> @end
@implementation D
- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)t { return @[ @"a", @"b", @"c" ]; }
- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)t { return @[ @"a", @"b", @"c" ]; }
- (NSToolbarItem *)toolbar:(NSToolbar *)t itemForItemIdentifier:(NSString *)i willBeInsertedIntoToolbar:(BOOL)f { return [[NSToolbarItem alloc] initWithItemIdentifier: i]; }
@end
int main(void)
{
	@autoreleasepool {
		[NSApplication sharedApplication];
		NSScreen *s = [NSScreen mainScreen]; CGFloat k = [s backingScaleFactor];
		CHECK([[s localizedName] length] > 0); CHECK([s maximumFramesPerSecond] == 60); CHECK([NSScreen screensHaveSeparateSpaces]);
		NSRect r = NSMakeRect(1, 2, 3, 4), b = [s convertRectToBacking: r]; CHECK(b.size.width == 3 * k && b.origin.y == 2 * k); CHECK(NSEqualRects([s convertRectFromBacking: b], r));
		NSRect al = [s backingAlignedRect: NSMakeRect(0.2, 0.2, 10.3, 10.3) options: NSAlignAllEdgesOutward]; CHECK(al.origin.x <= 0.2 && NSMaxX(al) >= 10.5);
		NSSegmentedControl *sc = [[NSSegmentedControl alloc] initWithFrame: NSMakeRect(0, 0, 100, 24)]; [sc setSegmentCount: 3];
		[sc setTag: 101 forSegment: 1]; CHECK([sc tagForSegment: 1] == 101); [sc setSelectedSegment: 1]; CHECK([sc indexOfSelectedItem] == 1 && [sc doubleValueForSelectedSegment] == 101);
		[sc setSegmentDistribution: 2]; CHECK([sc segmentDistribution] == 2);
		NSWindow *w = [[NSWindow alloc] initWithContentRect: NSMakeRect(100, 100, 400, 300) styleMask: NSTitledWindowMask backing: NSBackingStoreBuffered defer: NO];
		NSToolbar *tb = [[NSToolbar alloc] initWithIdentifier: @"t"]; [tb setDelegate: [D new]]; [w setToolbar: tb];
		CHECK([[tb itemIdentifiers] isEqual: (@[ @"a", @"b", @"c" ])]); [tb removeItemWithItemIdentifier: @"b"]; CHECK([[tb itemIdentifiers] isEqual: (@[ @"a", @"c" ])]);
		[tb setCenteredItemIdentifier: @"a"]; CHECK([[tb centeredItemIdentifier] isEqual: @"a"]);
		NSTextField *tf = [NSTextField wrappingLabelWithString: @"a long label that has to wrap over several lines when the width is small enough to force it"]; NSSize wide = [tf intrinsicContentSize];
		[tf setPreferredMaxLayoutWidth: 80]; NSSize narrow = [tf intrinsicContentSize]; CHECK(narrow.width == 80 && narrow.height > wide.height * 2);
		[tf setMaximumNumberOfLines: 2]; CHECK([tf maximumNumberOfLines] == 2); NSSize two = [tf intrinsicContentSize]; CHECK(two.height < narrow.height);
		NSLevelIndicator *li = [[NSLevelIndicator alloc] initWithFrame: NSMakeRect(0, 0, 100, 18)]; [li setFillColor: [NSColor redColor]]; CHECK([[li fillColor] isEqual: [NSColor redColor]]); CHECK([li drawsTieredCapacityLevels]);
		[li setLevelIndicatorStyle: 1]; CHECK([li levelIndicatorStyle] == 1);
		NSView *v = [[NSView alloc] initWithFrame: NSMakeRect(0, 0, 100, 100)]; id g = [v safeAreaLayoutGuide]; CHECK(g != nil && g == [v safeAreaLayoutGuide]);
		printf(fails ? "%d failures\n" : "morekit ok\n", fails);
	}
	return fails != 0;
}
