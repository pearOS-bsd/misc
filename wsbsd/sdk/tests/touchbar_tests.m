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
@interface SD : NSObject <NSScrubberDataSource, NSScrubberDelegate> { @public NSInteger selected, highlighted; int began, finished; } @end
@implementation SD
- (NSInteger)numberOfItemsForScrubber:(NSScrubber *)s { return 6; }
- (NSScrubberItemView *)scrubber:(NSScrubber *)s viewForItemAtIndex:(NSInteger)i { NSScrubberTextItemView *v = [s makeItemWithIdentifier: @"t" owner: nil]; [v setTitle: [NSString stringWithFormat: @"i%ld", (long)i]]; return v; }
- (void)scrubber:(NSScrubber *)s didSelectItemAtIndex:(NSInteger)i { selected = i; }
- (void)scrubber:(NSScrubber *)s didHighlightItemAtIndex:(NSInteger)i { highlighted = i; }
- (void)didBeginInteractingWithScrubber:(NSScrubber *)s { began++; } - (void)didFinishInteractingWithScrubber:(NSScrubber *)s { finished++; }
@end
@interface Tgt : NSObject { @public int hits; } - (void)hit:(id)s; @end
@implementation Tgt - (void)hit:(id)s { hits++; } @end

static void MoreTests(void)
{
	/* scrubber: layout, selection styles, interaction through the real mouse path is covered by the UI gallery */
	NSScrubber *s = [[NSScrubber alloc] initWithFrame: NSMakeRect(0, 0, 200, 30)]; [s registerClass: [NSScrubberTextItemView class] forItemIdentifier: @"t"];
	NSScrubberFlowLayout *fl = [NSScrubberFlowLayout new]; fl.itemSize = NSMakeSize(60, 30); fl.itemSpacing = 10; [s setScrubberLayout: fl]; SD *sd = [SD new]; [s setDataSource: sd]; [s setDelegate: sd];
	CHECK([s numberOfItems] == 6); CHECK([[s itemViewForItemAtIndex: 2] frame].origin.x == 140); CHECK([[(NSScrubberTextItemView *)[s itemViewForItemAtIndex: 3] title] isEqual: @"i3"]);
	CHECK([[fl layoutAttributesForItemAtIndex: 1] frame].origin.x == 70); CHECK([fl scrubberContentSize].width == 6 * 60 + 5 * 10); CHECK([s selectedIndex] == -1);
	[s setSelectedIndex: 2]; CHECK([s selectedIndex] == 2); CHECK([[s itemViewForItemAtIndex: 2] isSelected]); CHECK(![[s itemViewForItemAtIndex: 1] isSelected]);
	[s setSelectionBackgroundStyle: [NSScrubberSelectionStyle roundedBackgroundStyle]]; CHECK([[s selectionBackgroundStyle] makeSelectionView] != nil);
	NSScrubberProportionalLayout *pl = [[NSScrubberProportionalLayout alloc] initWithNumberOfVisibleItems: 4]; [s setScrubberLayout: pl]; CHECK([[pl layoutAttributesForItemAtIndex: 1] frame].size.width == 50); CHECK([pl numberOfVisibleItems] == 4);
	CHECK([s visibleRange].length >= 4); [s setMode: NSScrubberModeFree]; CHECK([s mode] == NSScrubberModeFree);
	/* picker */
	Tgt *t = [Tgt new]; NSPickerTouchBarItem *p = [NSPickerTouchBarItem pickerTouchBarItemWithIdentifier: @"p" labels: @[ @"a", @"b", @"c" ] selectionMode: NSPickerTouchBarItemSelectionModeSelectOne target: t action: @selector(hit:)];
	CHECK([p numberOfOptions] == 3); CHECK([[p labelAtIndex: 1] isEqual: @"b"]); CHECK([p selectedIndex] == 0); [p setSelectedIndex: 2]; CHECK([p selectedIndex] == 2); [p setEnabled: NO atIndex: 1]; CHECK(![p isEnabledAtIndex: 1]); CHECK([p target] == t);
	/* stepper */
	NSStepperTouchBarItem *st = [NSStepperTouchBarItem stepperTouchBarItemWithIdentifier: @"s" formatter: nil]; [st setMinValue: 0]; [st setMaxValue: 10]; [st setIncrement: 2]; [st setValue: 4]; CHECK([st value] == 4); [st setValue: 99]; CHECK([st value] == 10); CHECK([st view] != nil);
	/* color picker */
	NSColorPickerTouchBarItem *cp = [NSColorPickerTouchBarItem colorPickerWithIdentifier: @"c"]; [cp setColor: [NSColor blueColor]]; CHECK([[cp color] isEqual: [NSColor blueColor]]); CHECK([cp view] != nil); CHECK([cp isEnabled]);
	/* popover: presenting its bar makes it the bar of the host, dismissing removes it */
	NSTouchBar *pb = [NSTouchBar new]; [pb setDefaultItemIdentifiers: @[]]; NSPopoverTouchBarItem *po = [[NSPopoverTouchBarItem alloc] initWithIdentifier: @"po"]; [po setPopoverTouchBar: pb]; [po setCollapsedRepresentationLabel: @"More"]; CHECK([po showsCloseButton]); CHECK([po view] != nil);
	[po showPopover: nil]; CHECK([[WsbsdTouchBarHost sharedHost] currentTouchBar] == pb); CHECK([pb isVisible]); [po dismissPopover: nil]; CHECK([[WsbsdTouchBarHost sharedHost] currentTouchBar] != pb);
	/* candidate list */
	NSCandidateListTouchBarItem *cl = [[NSCandidateListTouchBarItem alloc] initWithIdentifier: @"cl"]; CHECK(![cl isCandidateListVisible]); [cl setCandidates: @[ @"a", @"b" ] forSelectedRange: NSMakeRange(0, 0) inString: @"x"]; CHECK([cl isCandidateListVisible]); CHECK([(NSScrubber *)[cl view] numberOfItems] == 2);
	/* the other-items proxy and visibility priority are covered by the gallery pages; group items */
	NSGroupTouchBarItem *a = [NSGroupTouchBarItem alertStyleGroupItemWithIdentifier: @"alert"]; CHECK(a != nil);
}

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
		MoreTests();
		printf(fails ? "touchbar_tests: %d FAILED\n" : "touchbar_tests: ok\n", fails);
	}
	return fails != 0;
}
