#import <Cocoa/Cocoa.h>
#include <stdio.h>
#include <stdlib.h>

static NSView *content;
static CGFloat contentH;
static int shown = -1;

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

@interface Del : NSObject { NSWindow *w; }
@end
@implementation Del
- (void) applicationDidFinishLaunching: (NSNotification *)n
{
	NSRect r = NSMakeRect(0, 0, 940, 700); contentH = r.size.height;
	w = [[NSWindow alloc] initWithContentRect: r styleMask: NSTitledWindowMask | NSClosableWindowMask | NSResizableWindowMask backing: NSBackingStoreBuffered defer: NO];
	[w setTitle: @"UI Gallery"]; content = [w contentView];
	CGFloat cx[4] = { 20, 250, 480, 710 }, y = 20; int col = 0;
#define CELL(label, name, view) do { caption(label, cx[col], y); place(view, name, cx[col], y + 16); col++; if (col == 4) { col = 0; y += 74; } } while (0)

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
	NSSegmentedControl *sg = [[[NSSegmentedControl alloc] initWithFrame: NSMakeRect(0, 0, 190, 24)] autorelease]; [sg setSegmentCount: 3]; for (int i = 0; i < 3; i++) [sg setLabel: [NSString stringWithFormat: @"Seg %d", i + 1] forSegment: i]; [sg setSelectedSegment: 1]; CELL(@"segmented", @"segmented", sg);
	NSProgressIndicator *pi = [[[NSProgressIndicator alloc] initWithFrame: NSMakeRect(0, 0, 160, 8)] autorelease]; [pi setIndeterminate: NO]; [pi setMinValue: 0]; [pi setMaxValue: 100]; [pi setDoubleValue: 60]; CELL(@"progress bar", @"progress", pi);
	NSStepper *st = [[[NSStepper alloc] initWithFrame: NSMakeRect(0, 0, 19, 27)] autorelease]; CELL(@"stepper", @"stepper", st);
	NSBox *bx = [[[NSBox alloc] initWithFrame: NSMakeRect(0, 0, 190, 60)] autorelease]; [bx setTitle: @"Group"]; CELL(@"box", @"box", bx);
	NSBox *sp = [[[NSBox alloc] initWithFrame: NSMakeRect(0, 0, 190, 2)] autorelease]; [sp setBoxType: NSBoxSeparator]; CELL(@"separator", @"separator", sp);
	NSTextField *lb = [[[NSTextField alloc] initWithFrame: NSMakeRect(0, 0, 190, 18)] autorelease]; [lb setStringValue: @"Label text"]; [lb setEditable: NO]; [lb setBezeled: NO]; [lb setDrawsBackground: NO]; CELL(@"label", @"label", lb);
	NSTabView *tv = [[[NSTabView alloc] initWithFrame: NSMakeRect(0, 0, 210, 110)] autorelease];
	for (int i = 0; i < 3; i++) { NSTabViewItem *it = [[[NSTabViewItem alloc] initWithIdentifier: [NSString stringWithFormat: @"t%d", i]] autorelease]; [it setLabel: [NSString stringWithFormat: @"Tab %d", i + 1]]; [tv addTabViewItem: it]; }
	if (col != 0) { col = 0; y += 74; }
	caption(@"tab view", cx[0], y); place(tv, @"tabview", cx[0], y + 16);
	NSScrollView *scv = [[[NSScrollView alloc] initWithFrame: NSMakeRect(0, 0, 210, 110)] autorelease]; [scv setHasVerticalScroller: YES]; [scv setDocumentView: [[[NSView alloc] initWithFrame: NSMakeRect(0, 0, 190, 400)] autorelease]];
	caption(@"scroll view", cx[1], y); place(scv, @"scrollview", cx[1], y + 16);
	NSTextView *tx = [[[NSTextView alloc] initWithFrame: NSMakeRect(0, 0, 210, 110)] autorelease]; [tx setString: @"Text view"];
	NSScrollView *ts = [[[NSScrollView alloc] initWithFrame: NSMakeRect(0, 0, 210, 110)] autorelease]; [ts setDocumentView: tx]; [ts setHasVerticalScroller: YES]; [ts setBorderType: NSBezelBorder];
	caption(@"text view", cx[2], y); place(ts, @"textview", cx[2], y + 16);
	NSTableView *tb = [[[NSTableView alloc] initWithFrame: NSMakeRect(0, 0, 210, 110)] autorelease]; NSTableColumn *c = [[[NSTableColumn alloc] initWithIdentifier: @"c"] autorelease]; [[c headerCell] setStringValue: @"Column"]; [c setWidth: 200]; [tb addTableColumn: c];
	NSScrollView *tss = [[[NSScrollView alloc] initWithFrame: NSMakeRect(0, 0, 210, 110)] autorelease]; [tss setDocumentView: tb]; [tss setHasVerticalScroller: YES]; [tss setBorderType: NSBezelBorder];
	caption(@"table view", cx[3], y); place(tss, @"tableview", cx[3], y + 16);
	[w center]; [w makeKeyAndOrderFront: nil]; [w makeFirstResponder: nil];       /* no field starts with the focus ring */
	const char *ex = getenv("UI_EXIT_AFTER"); if (ex) [NSTimer scheduledTimerWithTimeInterval: atof(ex) target: NSApp selector: @selector(terminate:) userInfo: nil repeats: NO];
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
