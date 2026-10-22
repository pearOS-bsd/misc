#import <Cocoa/Cocoa.h>
#include <stdio.h>
#include <stdlib.h>

static NSView *content;
static CGFloat contentH;
static int shown = -1;
static NSTextField *focusField;

/* registers a control at (x, y) from the top-left of the content area and prints its rectangle */
static void place(NSView *v, NSString *name, CGFloat x, CGFloat yTop)
{
	NSRect f = [v frame]; f.origin.x = x; f.origin.y = contentH - yTop - f.size.height; [v setFrame: f];
	[content addSubview: v];
	printf("CTRL %s %d %d %d %d\n", [name UTF8String], (int)x, (int)yTop, (int)f.size.width, (int)f.size.height);
}

static void caption(NSString *s, CGFloat x, CGFloat yTop)
{
	NSTextField *t = [[[NSTextField alloc] initWithFrame: NSMakeRect(x, contentH - yTop - 14, 180, 14)] autorelease];
	[t setStringValue: s]; [t setEditable: NO]; [t setSelectable: NO]; [t setBezeled: NO]; [t setBordered: NO]; [t setDrawsBackground: NO];
	[t setFont: [NSFont systemFontOfSize: 10]]; [t setTextColor: [[NSColor controlTextColor] colorWithAlphaComponent: 0.6]];
	[content addSubview: t];
}

static NSButton *button(NSString *title, NSButtonType type, NSRect f)
{
	NSButton *b = [[[NSButton alloc] initWithFrame: f] autorelease];
	[b setTitle: title]; [b setButtonType: type]; if (type == NSMomentaryPushInButton) [b setBezelStyle: NSRoundedBezelStyle];
	return b;
}

@interface Del : NSObject <NSTouchBarDelegate, NSScrubberDataSource, NSScrubberDelegate> { NSWindow *w; }
@end
@interface Src : NSObject
@end
@implementation Src
- (NSInteger) numberOfRowsInTableView: (NSTableView *)t { return 4; }
- (id) tableView: (NSTableView *)t objectValueForTableColumn: (NSTableColumn *)c row: (NSInteger)r { return [NSString stringWithFormat: @"Row %d", (int)r + 1]; }
@end
@interface Stripes : NSView @end
@implementation Stripes
- (void) drawRect: (NSRect)r { for (int i = 0; i < 24; i++) { [[NSColor colorWithCalibratedHue: i / 24.0 saturation: 0.85 brightness: 0.9 alpha: 1] set]; NSRectFill(NSMakeRect(i * 18, 0, 18, 360)); } }
@end

@implementation Del
- (void) applicationDidFinishLaunching: (NSNotification *)n
{
	NSRect r = NSMakeRect(0, 0, 940, 740); contentH = r.size.height;
	printf("CONTENT %d %d\n", (int)r.size.width, (int)r.size.height);
	w = [[NSWindow alloc] initWithContentRect: r styleMask: NSTitledWindowMask | NSClosableWindowMask | NSResizableWindowMask backing: NSBackingStoreBuffered defer: NO];
	[w setTitle: @"UI Gallery"]; content = [w contentView];
	if (getenv("UI_APPEARANCE") && [NSApp respondsToSelector: @selector(setAppearance:)] && NSClassFromString(@"NSAppearance")) {
		NSString *an = !strcmp(getenv("UI_APPEARANCE"), "light") ? @"NSAppearanceNameAqua" : @"NSAppearanceNameDarkAqua";
		id ap = [NSClassFromString(@"NSAppearance") performSelector: @selector(appearanceNamed:) withObject: an]; [NSApp performSelector: @selector(setAppearance:) withObject: ap];
	}
	if (getenv("UI_MODE") && !strcmp(getenv("UI_MODE"), "touchbar")) {     /* only the window and its Touch Bar (the page is UI_TB=1..6) */
		int page = getenv("UI_TB") ? atoi(getenv("UI_TB")) : 1; [w setTitle: @"UI Gallery: Touch Bar"]; caption([NSString stringWithFormat: @"Touch Bar page %d: the bar of this window is shown at the bottom of the screen", page], 20, 20);
		[w setTouchBar: [self tbBarForPage: page]]; [w center]; [w makeKeyAndOrderFront: nil]; printf("TOUCHBAR page %d\n", page); if (getenv("UI_TB_CUSTOMIZE")) [NSApp performSelector: @selector(toggleTouchBarCustomizationPalette:) withObject: nil afterDelay: 1.0];
		const char *ex2 = getenv("UI_EXIT_AFTER"); if (ex2) [NSTimer scheduledTimerWithTimeInterval: atof(ex2) target: NSApp selector: @selector(terminate:) userInfo: nil repeats: NO];
		return;
	}
	CGFloat cx[4] = { 20, 250, 480, 710 }, y = 20; int col = 0;
#define CELL(label, name, view) do { caption(label, cx[col], y); place(view, name, cx[col], y + 16); col++; if (col == 4) { col = 0; y += 66; } } while (0)

	NSButton *b = button(@"Button", NSMomentaryPushInButton, NSMakeRect(0, 0, 100, 32)); CELL(@"push", @"push", b);
	b = button(@"Default", NSMomentaryPushInButton, NSMakeRect(0, 0, 100, 32)); [b setKeyEquivalent: @"\r"]; CELL(@"push default", @"push-default", b);
	b = button(@"Disabled", NSMomentaryPushInButton, NSMakeRect(0, 0, 100, 32)); [b setEnabled: NO]; CELL(@"push disabled", @"push-disabled", b);
	b = button(@"Checkbox", NSSwitchButton, NSMakeRect(0, 0, 110, 20)); CELL(@"checkbox off", @"check-off", b);
	b = button(@"Checkbox", NSSwitchButton, NSMakeRect(0, 0, 110, 20)); [b setState: NSOnState]; CELL(@"checkbox on", @"check-on", b);
	b = button(@"Checkbox", NSSwitchButton, NSMakeRect(0, 0, 110, 20)); [b setEnabled: NO]; CELL(@"checkbox disabled", @"check-disabled", b);
	b = button(@"Radio", NSRadioButton, NSMakeRect(0, 0, 100, 20)); CELL(@"radio off", @"radio-off", b);
	b = button(@"Radio", NSRadioButton, NSMakeRect(0, 0, 100, 20)); [b setState: NSOnState]; CELL(@"radio on", @"radio-on", b);
	NSTextField *tf = [[[NSTextField alloc] initWithFrame: NSMakeRect(0, 0, 160, 22)] autorelease]; [tf setStringValue: @"Text field"]; CELL(@"text field", @"textfield", tf);
	NSSecureTextField *sf = [[[NSSecureTextField alloc] initWithFrame: NSMakeRect(0, 0, 160, 22)] autorelease]; [sf setStringValue: @"secret"]; CELL(@"secure field", @"securefield", sf);
	NSTextField *dis = [[[NSTextField alloc] initWithFrame: NSMakeRect(0, 0, 160, 22)] autorelease]; [dis setStringValue: @"Disabled"]; [dis setEnabled: NO]; CELL(@"text disabled", @"textfield-disabled", dis);
	if (NSClassFromString(@"NSSearchField")) { NSSearchField *s = [[[NSSearchField alloc] initWithFrame: NSMakeRect(0, 0, 160, 22)] autorelease]; [s setStringValue: @"search"]; CELL(@"search field", @"searchfield", s); }
	NSSlider *sl = [[[NSSlider alloc] initWithFrame: NSMakeRect(0, 0, 160, 22)] autorelease]; [sl setMinValue: 0]; [sl setMaxValue: 100]; [sl setDoubleValue: 40]; CELL(@"slider", @"slider", sl);
	sl = [[[NSSlider alloc] initWithFrame: NSMakeRect(0, 0, 160, 22)] autorelease]; [sl setMinValue: 0]; [sl setMaxValue: 100]; [sl setDoubleValue: 40]; [sl setEnabled: NO]; CELL(@"slider disabled", @"slider-disabled", sl);
	NSPopUpButton *pu = [[[NSPopUpButton alloc] initWithFrame: NSMakeRect(0, 0, 130, 26) pullsDown: NO] autorelease]; [pu addItemsWithTitles: [NSArray arrayWithObjects: @"Item A", @"Item B", nil]]; CELL(@"pop-up", @"popup", pu);
	NSComboBox *cb = [[[NSComboBox alloc] initWithFrame: NSMakeRect(0, 0, 130, 26)] autorelease]; [cb setStringValue: @"Combo"]; CELL(@"combo box", @"combobox", cb);
	NSSegmentedControl *sg = [[[NSSegmentedControl alloc] initWithFrame: NSMakeRect(0, 0, 190, 24)] autorelease]; [sg setSegmentCount: 3]; for (int i = 0; i < 3; i++) { [sg setLabel: [NSString stringWithFormat: @"Seg %d", i + 1] forSegment: i]; [sg setWidth: 63 forSegment: i]; } [sg setSelectedSegment: 1]; CELL(@"segmented", @"segmented", sg);
	NSProgressIndicator *pi = [[[NSProgressIndicator alloc] initWithFrame: NSMakeRect(0, 0, 160, 8)] autorelease]; [pi setIndeterminate: NO]; [pi setMinValue: 0]; [pi setMaxValue: 100]; [pi setDoubleValue: 60]; CELL(@"progress bar", @"progress", pi);
	NSStepper *st = [[[NSStepper alloc] initWithFrame: NSMakeRect(0, 0, 19, 27)] autorelease]; CELL(@"stepper", @"stepper", st);
	NSBox *bx = [[[NSBox alloc] initWithFrame: NSMakeRect(0, 0, 190, 60)] autorelease]; [bx setTitle: @"Group"]; CELL(@"box", @"box", bx);
	NSBox *sp = [[[NSBox alloc] initWithFrame: NSMakeRect(0, 0, 190, 2)] autorelease]; [sp setBoxType: NSBoxSeparator]; CELL(@"separator", @"separator", sp);
	NSTextField *lb = [[[NSTextField alloc] initWithFrame: NSMakeRect(0, 0, 190, 18)] autorelease]; [lb setStringValue: @"Label text"]; [lb setEditable: NO]; [lb setBezeled: NO]; [lb setDrawsBackground: NO]; CELL(@"label", @"label", lb);
	if (NSClassFromString(@"NSDatePicker")) { NSDatePicker *dp = [[[NSDatePicker alloc] initWithFrame: NSMakeRect(0, 0, 150, 27)] autorelease]; [dp setLocale: [NSLocale localeWithLocaleIdentifier: @"en_GB"]]; [dp setTimeZone: [NSTimeZone timeZoneForSecondsFromGMT: 0]]; [dp setDatePickerStyle: NSTextFieldAndStepperDatePickerStyle]; [dp setDateValue: [NSDate dateWithTimeIntervalSince1970: 86400.0 * 365 * 30]]; CELL(@"date picker", @"datepicker", dp); }
	if (NSClassFromString(@"NSLevelIndicator")) { NSLevelIndicator *li = [[[NSLevelIndicator alloc] initWithFrame: NSMakeRect(0, 0, 160, 18)] autorelease]; [li setMinValue: 0]; [li setMaxValue: 10]; [li setDoubleValue: 6]; CELL(@"level indicator", @"levelindicator", li); }
	NSColorWell *cw = [[[NSColorWell alloc] initWithFrame: NSMakeRect(0, 0, 44, 24)] autorelease]; [cw setColor: [NSColor colorWithCalibratedRed: 0.9 green: 0.3 blue: 0.2 alpha: 1]]; CELL(@"color well", @"colorwell", cw);
	NSSplitView *sv = [[[NSSplitView alloc] initWithFrame: NSMakeRect(0, 0, 190, 50)] autorelease]; [sv setVertical: YES]; [sv addSubview: [[[NSView alloc] initWithFrame: NSMakeRect(0, 0, 90, 50)] autorelease]]; [sv addSubview: [[[NSView alloc] initWithFrame: NSMakeRect(0, 0, 90, 50)] autorelease]]; CELL(@"split view", @"splitview", sv);
	b = button(@"Pressed", NSMomentaryPushInButton, NSMakeRect(0, 0, 100, 32)); [b highlight: YES]; CELL(@"push pressed", @"push-pressed", b);
	b = button(@"Pressed", NSMomentaryPushInButton, NSMakeRect(0, 0, 100, 32)); [b setKeyEquivalent: @"\r"]; [b highlight: YES]; CELL(@"default pressed", @"push-default-pressed", b);
	focusField = [[[NSTextField alloc] initWithFrame: NSMakeRect(0, 0, 160, 22)] autorelease]; [focusField setStringValue: @"Focused"]; CELL(@"text field focused", @"textfield-focused", focusField);
	b = button(@"Checkbox", NSSwitchButton, NSMakeRect(0, 0, 110, 20)); [b setState: NSOnState]; [b highlight: YES]; CELL(@"checkbox pressed", @"check-pressed", b);
	NSTabView *tv = [[[NSTabView alloc] initWithFrame: NSMakeRect(0, 0, 210, 110)] autorelease];
	for (int i = 0; i < 3; i++) { NSTabViewItem *it = [[[NSTabViewItem alloc] initWithIdentifier: [NSString stringWithFormat: @"t%d", i]] autorelease]; [it setLabel: [NSString stringWithFormat: @"Tab %d", i + 1]]; [tv addTabViewItem: it]; }
	if (col != 0) { col = 0; y += 66; }
	if (getenv("UI_TABVIEW")) { caption(@"tab view", cx[0], y); place(tv, @"tabview", cx[0], y + 16); }     /* off by default: on macOS 26+ the tab view puts a glass layer outside the window, which breaks the capture */
	NSScrollView *scv = [[[NSScrollView alloc] initWithFrame: NSMakeRect(0, 0, 210, 110)] autorelease]; [scv setHasVerticalScroller: YES]; [scv setDocumentView: [[[NSView alloc] initWithFrame: NSMakeRect(0, 0, 190, 400)] autorelease]];
	caption(@"scroll view", cx[1], y); place(scv, @"scrollview", cx[1], y + 16);
	NSTextView *tx = [[[NSTextView alloc] initWithFrame: NSMakeRect(0, 0, 210, 110)] autorelease]; [tx setString: @"Text view"];
	NSScrollView *ts = [[[NSScrollView alloc] initWithFrame: NSMakeRect(0, 0, 210, 110)] autorelease]; [ts setDocumentView: tx]; [ts setHasVerticalScroller: YES]; [ts setBorderType: NSBezelBorder];
	caption(@"text view", cx[2], y); place(ts, @"textview", cx[2], y + 16);
	NSTableView *tb = [[[NSTableView alloc] initWithFrame: NSMakeRect(0, 0, 210, 110)] autorelease]; NSTableColumn *c = [[[NSTableColumn alloc] initWithIdentifier: @"c"] autorelease]; [[c headerCell] setStringValue: @"Column"]; [c setWidth: 200]; [tb addTableColumn: c];
	NSScrollView *tss = [[[NSScrollView alloc] initWithFrame: NSMakeRect(0, 0, 210, 110)] autorelease]; [tss setDocumentView: tb]; [tss setHasVerticalScroller: YES]; [tss setBorderType: NSBezelBorder];
	static Src *src; src = [[Src alloc] init]; [tb setDataSource: src]; [tb reloadData]; [tb selectRowIndexes: [NSIndexSet indexSetWithIndex: 1] byExtendingSelection: NO];
	caption(@"table view", cx[3], y); place(tss, @"tableview", cx[3], y + 16);
	[w center]; [w makeKeyAndOrderFront: nil]; if (getenv("UI_FOCUS")) [w makeFirstResponder: focusField];       /* off by default: on macOS 26+ a focused field opens a Writing Tools panel that leaks into the capture */
	else [w makeFirstResponder: nil];
	if (getenv("UI_MODE") && !strcmp(getenv("UI_MODE"), "alert")) [self performSelector: @selector(showAlert:) withObject: nil afterDelay: 0.6];
	if (getenv("UI_MODE") && !strcmp(getenv("UI_MODE"), "menu")) [self performSelector: @selector(showMenu:) withObject: nil afterDelay: 0.6];
	if (getenv("UI_MODE") && !strcmp(getenv("UI_MODE"), "vibrancy")) [self performSelector: @selector(showVibrancy:) withObject: nil afterDelay: 0.6];
	const char *ex = getenv("UI_EXIT_AFTER"); if (ex) [NSTimer scheduledTimerWithTimeInterval: atof(ex) target: NSApp selector: @selector(terminate:) userInfo: nil repeats: NO];
}

/* ---- Touch Bar: UI_MODE=touchbar UI_TB=1..6 (a page of items each); the bar is the one of the window ---- */
- (NSTouchBar *) tbBarForPage: (int)page
{
	NSTouchBar *b = [[[NSTouchBar alloc] init] autorelease]; [b setDelegate: self]; NSArray *ids = nil;
	switch (page) {
	case 1: ids = [NSArray arrayWithObjects: @"tb.button", @"tb.image", @"tb.group", NSTouchBarItemIdentifierFlexibleSpace, @"tb.slider", nil]; break;
	case 6: ids = [NSArray arrayWithObjects: @"tb.label", NSTouchBarItemIdentifierFlexibleSpace, @"tb.button", nil]; { NSButtonTouchBarItem *tray = [NSButtonTouchBarItem buttonTouchBarItemWithIdentifier: @"tb.tray" title: @"Tray" target: self action: @selector(tbHit:)]; [NSTouchBarItem addSystemTrayItem: tray]; } break;
	case 5: ids = [NSArray arrayWithObjects: @"tb.stepper", NSTouchBarItemIdentifierFixedSpaceSmall, @"tb.picker", NSTouchBarItemIdentifierFlexibleSpace, @"tb.image", nil]; break;
	case 2: ids = [NSArray arrayWithObjects: @"tb.scrubber.text", NSTouchBarItemIdentifierFixedSpaceSmall, @"tb.scrubber.image", nil]; break;
	case 3: ids = [NSArray arrayWithObjects: @"tb.popover", @"tb.color", @"tb.share", NSTouchBarItemIdentifierFlexibleSpace, @"tb.candidates", nil]; break;
	default: ids = [NSArray arrayWithObjects: @"tb.label", @"tb.principal", @"tb.low1", @"tb.low2", @"tb.low3", @"tb.low4", nil]; [b setPrincipalItemIdentifier: @"tb.principal"]; break;
	}
	[b setDefaultItemIdentifiers: ids]; [b setCustomizationIdentifier: [NSString stringWithFormat: @"com.test.touchbar.%d", page]]; [b setCustomizationAllowedItemIdentifiers: ids];
	if (page == 3) [b setEscapeKeyReplacementItemIdentifier: @"tb.esc"];
	return b;
}
- (NSTouchBarItem *) touchBar: (NSTouchBar *)bar makeItemForIdentifier: (NSTouchBarItemIdentifier)i
{
	printf("TOUCHBAR make %s\n", [i UTF8String]);
	if ([i isEqual: @"tb.button"]) { NSButtonTouchBarItem *it = [NSButtonTouchBarItem buttonTouchBarItemWithIdentifier: i title: @"Button" target: self action: @selector(tbHit:)]; [it setBezelColor: [NSColor colorWithCalibratedRed: 0.1 green: 0.45 blue: 1 alpha: 1]]; return it; }
	if ([i isEqual: @"tb.image"]) return [NSButtonTouchBarItem buttonTouchBarItemWithIdentifier: i image: [NSImage imageNamed: NSImageNameTouchBarAddTemplate] target: self action: @selector(tbHit:)];
	if ([i isEqual: @"tb.group"]) return [NSGroupTouchBarItem groupItemWithIdentifier: i items: [NSArray arrayWithObjects: [NSButtonTouchBarItem buttonTouchBarItemWithIdentifier: @"tb.g1" title: @"One" target: self action: @selector(tbHit:)], [NSButtonTouchBarItem buttonTouchBarItemWithIdentifier: @"tb.g2" title: @"Two" target: self action: @selector(tbHit:)], nil]];
	if ([i isEqual: @"tb.slider"]) { NSSliderTouchBarItem *it = [[[NSSliderTouchBarItem alloc] initWithIdentifier: i] autorelease]; [[it slider] setMinValue: 0]; [[it slider] setMaxValue: 100]; [it setDoubleValue: 35]; [it setCustomizationLabel: @"Slider"]; return it; }
	if ([i isEqual: @"tb.stepper"]) { NSStepperTouchBarItem *it = [NSStepperTouchBarItem stepperTouchBarItemWithIdentifier: i formatter: nil]; [it setMinValue: 0]; [it setMaxValue: 10]; [it setValue: 4]; [it setTarget: self]; [it setAction: @selector(tbHit:)]; return it; }
	if ([i isEqual: @"tb.picker"]) return [NSPickerTouchBarItem pickerTouchBarItemWithIdentifier: i labels: [NSArray arrayWithObjects: @"S", @"M", @"L", nil] selectionMode: NSPickerTouchBarItemSelectionModeSelectOne target: self action: @selector(tbHit:)];
	if ([i isEqual: @"tb.scrubber.text"]) { NSCustomTouchBarItem *it = [[[NSCustomTouchBarItem alloc] initWithIdentifier: i] autorelease]; NSScrubber *s = [[[NSScrubber alloc] initWithFrame: NSMakeRect(0, 0, 420, 30)] autorelease]; [s registerClass: [NSScrubberTextItemView class] forItemIdentifier: @"text"]; NSScrubberFlowLayout *l = [[[NSScrubberFlowLayout alloc] init] autorelease]; [l setItemSize: NSMakeSize(90, 30)]; [l setItemSpacing: 6]; [s setScrubberLayout: l]; [s setMode: NSScrubberModeFree]; [s setSelectionBackgroundStyle: [NSScrubberSelectionStyle roundedBackgroundStyle]]; [s setDataSource: self]; [s setDelegate: self]; [s setSelectedIndex: 1]; [it setView: s]; return it; }
	if ([i isEqual: @"tb.scrubber.image"]) { NSCustomTouchBarItem *it = [[[NSCustomTouchBarItem alloc] initWithIdentifier: i] autorelease]; NSScrubber *s = [[[NSScrubber alloc] initWithFrame: NSMakeRect(0, 0, 300, 30)] autorelease]; [s registerClass: [NSScrubberImageItemView class] forItemIdentifier: @"image"]; [s setScrubberLayout: [[[NSScrubberProportionalLayout alloc] initWithNumberOfVisibleItems: 5] autorelease]]; [s setMode: NSScrubberModeFixed]; [s setSelectionOverlayStyle: [NSScrubberSelectionStyle outlineOverlayStyle]]; [s setDataSource: self]; [s setDelegate: self]; [it setView: s]; return it; }
	if ([i isEqual: @"tb.popover"]) { NSPopoverTouchBarItem *it = [[[NSPopoverTouchBarItem alloc] initWithIdentifier: i] autorelease]; [it setCollapsedRepresentationLabel: @"Popover"]; NSTouchBar *pb = [[[NSTouchBar alloc] init] autorelease]; [pb setDelegate: self]; [pb setDefaultItemIdentifiers: [NSArray arrayWithObjects: @"tb.button", @"tb.slider", nil]]; [it setPopoverTouchBar: pb]; [it setShowsCloseButton: YES]; return it; }
	if ([i isEqual: @"tb.color"]) { NSColorPickerTouchBarItem *it = [NSColorPickerTouchBarItem colorPickerWithIdentifier: i]; [it setTarget: self]; [it setAction: @selector(tbHit:)]; return it; }
	if ([i isEqual: @"tb.share"]) { NSSharingServicePickerTouchBarItem *it = [[[NSSharingServicePickerTouchBarItem alloc] initWithIdentifier: i] autorelease]; return it; }
	if ([i isEqual: @"tb.candidates"]) { NSCandidateListTouchBarItem *it = [[[NSCandidateListTouchBarItem alloc] initWithIdentifier: i] autorelease]; [it setCandidates: [NSArray arrayWithObjects: @"apple", @"apply", @"apple pie", @"application", nil] forSelectedRange: NSMakeRange(0, 0) inString: @"app"]; return it; }
	if ([i isEqual: @"tb.esc"]) return [NSButtonTouchBarItem buttonTouchBarItemWithIdentifier: i title: @"Done" target: self action: @selector(tbHit:)];
	if ([i isEqual: @"tb.label"]) { NSCustomTouchBarItem *it = [[[NSCustomTouchBarItem alloc] initWithIdentifier: i] autorelease]; NSTextField *t = [NSTextField labelWithString: @"left"]; [t setTextColor: [NSColor whiteColor]]; [it setView: t]; [it setVisibilityPriority: NSTouchBarItemPriorityHigh]; return it; }
	if ([i isEqual: @"tb.principal"]) { NSCustomTouchBarItem *it = [[[NSCustomTouchBarItem alloc] initWithIdentifier: i] autorelease]; NSTextField *t = [NSTextField labelWithString: @"principal (centered)"]; [t setTextColor: [NSColor whiteColor]]; [t sizeToFit]; [it setView: t]; return it; }
	if ([i hasPrefix: @"tb.low"]) { NSButtonTouchBarItem *it = [NSButtonTouchBarItem buttonTouchBarItemWithIdentifier: i title: [@"Low " stringByAppendingString: [i substringFromIndex: 6]] target: self action: @selector(tbHit:)]; [it setVisibilityPriority: NSTouchBarItemPriorityLow]; return it; }
	return nil;
}
- (void) tbHit: (id)sender { printf("TOUCHBAR hit %s\n", [NSStringFromClass([sender class]) UTF8String]); fflush(stdout); }
- (NSInteger) numberOfItemsForScrubber: (NSScrubber *)s { return 12; }
- (NSScrubberItemView *) scrubber: (NSScrubber *)s viewForItemAtIndex: (NSInteger)i
{
	if ([[[s scrubberLayout] class] isEqual: [NSScrubberProportionalLayout class]]) { NSScrubberImageItemView *v = [s makeItemWithIdentifier: @"image" owner: nil]; [v setImage: [NSImage imageNamed: i % 2 ? NSImageNameTouchBarGoForwardTemplate : NSImageNameTouchBarGoBackTemplate]]; return v; }
	NSScrubberTextItemView *v = [s makeItemWithIdentifier: @"text" owner: nil]; [v setTitle: [NSString stringWithFormat: @"Item %d", (int)i + 1]]; return v;
}
- (void) scrubber: (NSScrubber *)s didSelectItemAtIndex: (NSInteger)i { printf("TOUCHBAR scrubber select %d\n", (int)i); fflush(stdout); }
- (void) showAlert: (id)unused
{
	NSAlert *a = [[[NSAlert alloc] init] autorelease];
	[a setMessageText: @"Alert title"]; [a setInformativeText: @"Informative text that explains the alert in a sentence or two."];
	[a addButtonWithTitle: @"OK"]; [a addButtonWithTitle: @"Cancel"];
	[a runModal];
}
- (void) showVibrancy: (id)unused
{
	/* a striped window behind, a window with a behind-window material (sidebar) partly over it */
	NSWindow *back = [[NSWindow alloc] initWithContentRect: NSMakeRect(60, 140, 420, 360) styleMask: NSTitledWindowMask backing: NSBackingStoreBuffered defer: NO];
	[back setTitle: @"Backdrop"]; [back setContentView: [[[Stripes alloc] initWithFrame: NSMakeRect(0, 0, 420, 360)] autorelease]]; [back makeKeyAndOrderFront: nil];
	NSWindow *fx = [[NSWindow alloc] initWithContentRect: NSMakeRect(300, 200, 360, 280) styleMask: NSTitledWindowMask | NSClosableWindowMask backing: NSBackingStoreBuffered defer: NO];
	[fx setTitle: @"Vibrancy"];
	Class vc = NSClassFromString(@"NSVisualEffectView"); if (!vc) return;
	NSView *ve = [[[vc alloc] initWithFrame: NSMakeRect(0, 0, 360, 280)] autorelease];
	[(id)ve performSelector: @selector(setMaterial:) withObject: (id)(NSInteger)7]; [(id)ve performSelector: @selector(setBlendingMode:) withObject: (id)(NSInteger)0]; [(id)ve performSelector: @selector(setState:) withObject: (id)(NSInteger)1];
	[fx setContentView: ve];
	NSTextField *t = [[[NSTextField alloc] initWithFrame: NSMakeRect(20, 220, 300, 22)] autorelease]; [t setStringValue: @"Sidebar material over a striped window"]; [t setEditable: NO]; [t setBezeled: NO]; [t setDrawsBackground: NO]; [ve addSubview: t];
	[fx makeKeyAndOrderFront: nil];
}
- (void) showMenu: (id)unused
{
	NSMenu *m = [[[NSMenu alloc] initWithTitle: @""] autorelease];
	[m addItemWithTitle: @"Item one" action: @selector(self) keyEquivalent: @""];
	NSMenuItem *two = [m addItemWithTitle: @"Item two (checked)" action: @selector(self) keyEquivalent: @"t"]; [two setState: NSOnState];
	[m addItem: [NSMenuItem separatorItem]];
	NSMenuItem *dis = [m addItemWithTitle: @"Disabled item" action: NULL keyEquivalent: @""]; [dis setEnabled: NO];
	[m addItemWithTitle: @"Item four" action: @selector(self) keyEquivalent: @"4"];
	[NSMenu popUpContextMenu: m withEvent: [NSEvent mouseEventWithType: NSRightMouseDown location: NSMakePoint([w frame].origin.x + 150, [w frame].origin.y + 150) modifierFlags: 0 timestamp: 0 windowNumber: 0 context: nil eventNumber: 0 clickCount: 1 pressure: 1] forView: [w contentView]];
}
- (BOOL) applicationShouldTerminateAfterLastWindowClosed: (NSApplication *)a { return YES; }
@end

int main(void)
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[NSApplication sharedApplication];
	if ([NSApp respondsToSelector: @selector(setActivationPolicy:)]) [NSApp setActivationPolicy: NSApplicationActivationPolicyRegular];
	setvbuf(stdout, NULL, _IOLBF, 0);
	[NSApp setDelegate: [[Del alloc] init]];
	[NSApp activateIgnoringOtherApps: YES];
	[NSApp run];
	[pool release];
	return 0;
}
