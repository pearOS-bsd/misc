/* NSMenuItem additions: hidden items take no room and have no key equivalent, views take their row, parentItem, section headers. */
#import <AppKit/AppKit.h>
@interface NSMenuItem (D) - (BOOL)isHidden; - (void)setHidden:(BOOL)h; - (BOOL)allowsKeyEquivalentWhenHidden; - (void)setAllowsKeyEquivalentWhenHidden:(BOOL)b; - (NSMenuItem *)parentItem; - (BOOL)isHiddenOrHasHiddenAncestor; - (NSView *)view; - (void)setView:(NSView *)v; - (BOOL)isSectionHeader; + (NSMenuItem *)sectionHeaderWithTitle:(NSString *)t; @end
static int fails;
#define CHECK(c) do { if (!(c)) { printf("FAIL %s:%d %s\n", __FILE__, __LINE__, #c); fails++; } } while (0)
int main(void)
{
	@autoreleasepool {
		[NSApplication sharedApplication];
		NSMenu *m = [[NSMenu alloc] initWithTitle: @"T"];
		NSMenuItem *a = [m addItemWithTitle: @"A" action: NULL keyEquivalent: @"a"], *b = [m addItemWithTitle: @"B" action: NULL keyEquivalent: @"b"], *c = [m addItemWithTitle: @"C" action: NULL keyEquivalent: @"c"];
		NSMenuView *mv = [m menuRepresentation]; [mv sizeToFit]; [mv sizeToFit];
		CGFloat h3 = [mv frame].size.height;
		CHECK(![b isHidden]); CHECK([[b keyEquivalent] isEqual: @"b"]);
		[b setHidden: YES];
		CHECK([b isHidden]); CHECK([[b keyEquivalent] isEqual: @""]);
		CHECK([mv frame].size.height < h3 - 10);
		[b setAllowsKeyEquivalentWhenHidden: YES]; CHECK([[b keyEquivalent] isEqual: @"b"]);
		[b setHidden: NO]; CHECK(fabs([mv frame].size.height - h3) < 0.5);
		NSMenu *sub = [[NSMenu alloc] initWithTitle: @"S"]; [c setSubmenu: sub];
		NSMenuItem *s1 = [sub addItemWithTitle: @"S1" action: NULL keyEquivalent: @""];
		CHECK([s1 parentItem] == c); CHECK([a parentItem] == nil);
		[c setHidden: YES]; CHECK([s1 isHiddenOrHasHiddenAncestor]); CHECK(![s1 isHidden]);
		NSView *v = [[NSView alloc] initWithFrame: NSMakeRect(0, 0, 100, 40)]; [b setView: v];
		CHECK([b view] == v); CHECK([v superview] == mv); CHECK(fabs([mv rectOfItemAtIndex: 1].size.height - 40) < 0.5);
		NSMenuItem *h = [NSMenuItem sectionHeaderWithTitle: @"Sec"]; CHECK([h isSectionHeader]); CHECK(![h isEnabled]); CHECK(![a isSectionHeader]);
	}
	printf(fails ? "menuitem: %d failed\n" : "menuitem ok\n", fails);
	return fails != 0;
}
