/* NSTouchBar semantics without a display: identifiers, delegate, template items, groups, buttons, the responder chain. */
#import <Cocoa/Cocoa.h>
static int fails;
#define CHECK(c) do { if (!(c)) { fails++; printf("FAIL %s:%d %s\n", __FILE__, __LINE__, #c); } } while (0)
@interface D : NSObject <NSTouchBarDelegate> { @public int made; } @end
@implementation D
- (NSTouchBarItem *)touchBar:(NSTouchBar *)b makeItemForIdentifier:(NSTouchBarItemIdentifier)i { made++; if ([i isEqual: @"x"]) { NSCustomTouchBarItem *c = [[NSCustomTouchBarItem alloc] initWithIdentifier: i]; [c setView: [[NSView alloc] initWithFrame: NSMakeRect(0, 0, 40, 20)]]; [c setCustomizationLabel: @"X"]; return c; } return nil; }
@end
@interface R : NSResponder @end
@implementation R - (NSTouchBar *)makeTouchBar { NSTouchBar *b = [NSTouchBar new]; [b setDefaultItemIdentifiers: @[ @"x" ]]; return b; } @end
int main(void)
{
	@autoreleasepool {
		[NSApplication sharedApplication];
		NSTouchBar *b = [NSTouchBar new]; D *d = [D new]; [b setDelegate: d]; [b setDefaultItemIdentifiers: @[ @"x", NSTouchBarItemIdentifierFlexibleSpace ]]; [b setPrincipalItemIdentifier: @"x"];
		CHECK([[b itemIdentifiers] count] == 2); CHECK([[b principalItemIdentifier] isEqual: @"x"]);
		NSTouchBarItem *i = [b itemForIdentifier: @"x"]; CHECK([[i identifier] isEqual: @"x"]); CHECK([[(NSCustomTouchBarItem *)i customizationLabel] isEqual: @"X"]); CHECK([i view] != nil);
		CHECK([b itemForIdentifier: @"x"] == i); CHECK(d->made == 1);                       /* made once, then cached */
		NSButtonTouchBarItem *bt = [NSButtonTouchBarItem buttonTouchBarItemWithIdentifier: @"b" title: @"Go" target: d action: @selector(description)];
		CHECK([[bt title] isEqual: @"Go"]); CHECK([bt target] == d); CHECK([bt action] == @selector(description)); CHECK([bt isEnabled]); CHECK([bt view].frame.size.width >= 64);
		NSGroupTouchBarItem *g = [NSGroupTouchBarItem groupItemWithIdentifier: @"g" items: @[ bt ]]; CHECK([[[g groupTouchBar] itemIdentifiers] isEqual: @[ @"b" ]]); CHECK([g view] != nil);
		NSTouchBar *t2 = [NSTouchBar new]; [t2 setTemplateItems: [NSSet setWithObject: bt]]; [t2 setDefaultItemIdentifiers: @[ @"b" ]]; CHECK([t2 itemForIdentifier: @"b"] == bt);
		NSSliderTouchBarItem *s = [[NSSliderTouchBarItem alloc] initWithIdentifier: @"s"]; [s setDoubleValue: 0.25]; CHECK([s doubleValue] == 0.25); CHECK([s view] == [s slider]);
		R *r = [R new]; CHECK([r touchBar] == nil); NSTouchBar *made = [r makeTouchBar]; [r setTouchBar: made]; CHECK([r touchBar] == made);
		CHECK(![b isVisible]);
		printf(fails ? "touchbar_tests: %d FAILED\n" : "touchbar_tests: ok\n", fails);
	}
	return fails != 0;
}
