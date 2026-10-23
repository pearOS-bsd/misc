/* NSMenuItem additions: hidden items take no room and have no key equivalent, views take their row, parentItem, section headers. */
#import <AppKit/AppKit.h>
@interface NSMenuItem (D) - (BOOL)isHidden; - (void)setHidden:(BOOL)h; - (BOOL)allowsKeyEquivalentWhenHidden; - (void)setAllowsKeyEquivalentWhenHidden:(BOOL)b; - (NSMenuItem *)parentItem; - (BOOL)isHiddenOrHasHiddenAncestor; - (NSView *)view; - (void)setView:(NSView *)v; - (BOOL)isSectionHeader; + (NSMenuItem *)sectionHeaderWithTitle:(NSString *)t; @end
@interface NSMenuItemBadge : NSObject - (id)initWithCount:(NSInteger)c; - (NSInteger)itemCount; - (NSInteger)type; - (NSString *)stringValue; + (id)alertsWithCount:(NSInteger)c; @end
@interface NSMenuItem (B) - (NSMenuItemBadge *)badge; - (void)setBadge:(NSMenuItemBadge *)b; @end
static int fails, kHit;
@interface KT : NSObject @end
@implementation KT - (void)netAct:(id)s { kHit = 1; } - (void)connAct:(id)s { kHit = 2; } @end
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
		{	/* Shift counts for letters: Command-K reaches the plain item, Shift-Command-K the shifted one (WsdMacTheme.m) */
			NSMenu *km = [[NSMenu alloc] initWithTitle: @"K"]; KT *tg = [[KT alloc] init];
			NSMenuItem *n1 = [km addItemWithTitle: @"Net" action: @selector(netAct:) keyEquivalent: @"k"]; [n1 setKeyEquivalentModifierMask: NSCommandKeyMask | NSShiftKeyMask]; [n1 setTarget: tg];
			NSMenuItem *n2 = [km addItemWithTitle: @"Conn" action: @selector(connAct:) keyEquivalent: @"k"]; [n2 setKeyEquivalentModifierMask: NSCommandKeyMask]; [n2 setTarget: tg];
			NSEvent *e1 = [NSEvent keyEventWithType: NSKeyDown location: NSZeroPoint modifierFlags: NSCommandKeyMask timestamp: 0 windowNumber: 0 context: nil characters: @"k" charactersIgnoringModifiers: @"k" isARepeat: NO keyCode: 40];
			NSEvent *e2 = [NSEvent keyEventWithType: NSKeyDown location: NSZeroPoint modifierFlags: NSCommandKeyMask | NSShiftKeyMask timestamp: 0 windowNumber: 0 context: nil characters: @"K" charactersIgnoringModifiers: @"k" isARepeat: NO keyCode: 40];
			CHECK([km performKeyEquivalent: e1]); CHECK(kHit == 2); CHECK([km performKeyEquivalent: e2]); CHECK(kHit == 1);
		}
		NSMenuItem *h = [NSMenuItem sectionHeaderWithTitle: @"Sec"]; CHECK([h isSectionHeader]); CHECK(![h isEnabled]); CHECK(![a isSectionHeader]);
		NSMenuItem *bi = [[NSMenuItem alloc] initWithTitle: @"X" action: NULL keyEquivalent: @""]; [bi setBadge: [NSClassFromString(@"NSMenuItemBadge") alertsWithCount: 7]];
		CHECK([[bi badge] itemCount] == 7); CHECK([[bi badge] type] == 3); CHECK([[[bi badge] stringValue] isEqual: @"7"]);
	}
	printf(fails ? "menuitem: %d failed\n" : "menuitem ok\n", fails);
	return fails != 0;
}
