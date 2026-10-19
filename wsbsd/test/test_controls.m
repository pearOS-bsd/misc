/* NSControl / NSButton / NSMenu additions that act through the cell or the menu view. */
#import <AppKit/AppKit.h>
@interface NSControl (D) - (NSControlSize)controlSize; - (void)setControlSize:(NSControlSize)s; - (NSLineBreakMode)lineBreakMode; - (void)setLineBreakMode:(NSLineBreakMode)m; - (BOOL)isHighlighted; - (void)setHighlighted:(BOOL)b; @end
@interface NSMenu (D) - (NSMenuItem *)highlightedItem; - (void)setItemArray:(NSArray *)a; - (NSSize)size; - (CGFloat)minimumWidth; - (void)setMinimumWidth:(CGFloat)w; @end
static int fails;
#define CHECK(c) do { if (!(c)) { printf("FAIL %s:%d %s\n", __FILE__, __LINE__, #c); fails++; } } while (0)
int main(void)
{
	@autoreleasepool {
		[NSApplication sharedApplication];
		NSButton *b = [[NSButton alloc] initWithFrame: NSMakeRect(0, 0, 80, 24)];
		[b setControlSize: NSSmallControlSize]; CHECK([b controlSize] == NSSmallControlSize); CHECK([[b cell] controlSize] == NSSmallControlSize);
		[b setLineBreakMode: NSLineBreakByTruncatingTail]; CHECK([b lineBreakMode] == NSLineBreakByTruncatingTail);
		[b setHighlighted: YES]; CHECK([b isHighlighted]); [b setHighlighted: NO]; CHECK(![b isHighlighted]);
		NSMenu *m = [[NSMenu alloc] initWithTitle: @"M"]; [m addItemWithTitle: @"x" action: NULL keyEquivalent: @""];
		NSMenuItem *a = [[NSMenuItem alloc] initWithTitle: @"A" action: NULL keyEquivalent: @""], *c = [[NSMenuItem alloc] initWithTitle: @"C" action: NULL keyEquivalent: @""];
		[m setItemArray: @[ a, c ]]; CHECK([m numberOfItems] == 2); CHECK([m itemAtIndex: 1] == c);
		CHECK([m highlightedItem] == nil);
		NSSize s0 = [m size]; [m setMinimumWidth: s0.width + 100]; CHECK([m size].width >= s0.width + 99); CHECK([m minimumWidth] > 0);
	}
	printf(fails ? "controls: %d failed\n" : "controls ok\n", fails);
	return fails != 0;
}
