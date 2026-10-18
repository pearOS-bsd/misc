#import "TermSettings.h"
#import "TermProfile.h"

@interface TermSettingsController : NSObject
{
	NSWindow *win; NSTableView *list; TermProfile *cur;
	NSPopUpButton *defPopup; NSColorWell *wells[5]; NSSlider *opacity, *blurSlider; NSTextField *colsField, *rowsField, *sizeField; NSButton *blinkBox, *aaBox; NSTextField *shellField;
}
- (void)show;
@end

static TermSettingsController *shared;

@implementation TermSettings
+ (void)show { if (!shared) shared = [[TermSettingsController alloc] init]; [shared show]; }
@end

static NSTextField *label(NSString *s, NSRect r) { NSTextField *t = [[[NSTextField alloc] initWithFrame:r] autorelease]; [t setStringValue:s]; [t setEditable:NO]; [t setSelectable:NO]; [t setBezeled:NO]; [t setBordered:NO]; [t setDrawsBackground:NO]; return t; }

@implementation TermSettingsController
- (instancetype)init
{
	if (!(self = [super init])) return nil;
	win = [[NSWindow alloc] initWithContentRect:NSMakeRect(220, 160, 640, 470) styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask) backing:NSBackingStoreBuffered defer:NO];
	[win setTitle:@"General"]; [win setReleasedWhenClosed:NO];
	NSTabView *tv = [[[NSTabView alloc] initWithFrame:NSMakeRect(10, 10, 620, 450)] autorelease];
	NSTabViewItem *g = [[[NSTabViewItem alloc] initWithIdentifier:@"General"] autorelease]; [g setLabel:@"General"]; [g setView:[self generalView]]; [tv addTabViewItem:g];
	NSTabViewItem *p = [[[NSTabViewItem alloc] initWithIdentifier:@"Profiles"] autorelease]; [p setLabel:@"Profiles"]; [p setView:[self profilesView]]; [tv addTabViewItem:p];
	[tv setDelegate:(id)self]; [[win contentView] addSubview:tv];
	return self;
}
- (void)tabView:(NSTabView *)t didSelectTabViewItem:(NSTabViewItem *)i { [win setTitle:[i label]]; }
- (void)show { [win makeKeyAndOrderFront:nil]; }

- (NSView *)generalView
{
	NSView *v = [[[NSView alloc] initWithFrame:NSMakeRect(0, 0, 600, 400)] autorelease];
	[v addSubview:label(@"New windows open with:", NSMakeRect(20, 340, 180, 20))];
	defPopup = [[[NSPopUpButton alloc] initWithFrame:NSMakeRect(210, 336, 220, 26) pullsDown:NO] autorelease];
	for (TermProfile *pr in [TermProfile allProfiles]) [defPopup addItemWithTitle:pr->name];
	[defPopup selectItemWithTitle:[TermProfile defaultProfile]->name]; [defPopup setTarget:self]; [defPopup setAction:@selector(defaultChanged:)]; [v addSubview:defPopup];
	[v addSubview:label(@"Shell:", NSMakeRect(20, 290, 180, 20))];
	shellField = [[[NSTextField alloc] initWithFrame:NSMakeRect(210, 288, 300, 24)] autorelease]; [shellField setPlaceholderString:@"Default login shell"]; [shellField setStringValue:[[NSUserDefaults standardUserDefaults] stringForKey:@"Shell"] ?: @""];
	[shellField setTarget:self]; [shellField setAction:@selector(shellChanged:)]; [v addSubview:shellField];
	[v addSubview:label(@"The shell opens in the profile's window size; changes to a profile apply at once to the windows that use it.", NSMakeRect(20, 240, 560, 36))];
	return v;
}
- (void)defaultChanged:(id)s { TermProfile *p = [TermProfile profileNamed:[defPopup titleOfSelectedItem]]; if (p) [TermProfile setDefaultProfile:p]; }
- (void)shellChanged:(id)s { [[NSUserDefaults standardUserDefaults] setObject:[shellField stringValue] forKey:@"Shell"]; }

- (NSView *)profilesView
{
	NSView *v = [[[NSView alloc] initWithFrame:NSMakeRect(0, 0, 600, 400)] autorelease];
	NSScrollView *sc = [[[NSScrollView alloc] initWithFrame:NSMakeRect(10, 40, 160, 350)] autorelease]; [sc setHasVerticalScroller:YES]; [sc setBorderType:NSBezelBorder];
	list = [[[NSTableView alloc] initWithFrame:NSMakeRect(0, 0, 160, 350)] autorelease]; NSTableColumn *col = [[[NSTableColumn alloc] initWithIdentifier:@"n"] autorelease]; [col setWidth:150]; [list addTableColumn:col];
	[list setHeaderView:nil]; [list setDataSource:(id)self]; [list setDelegate:(id)self]; [sc setDocumentView:list]; [v addSubview:sc];
	NSButton *mk = [[[NSButton alloc] initWithFrame:NSMakeRect(10, 8, 160, 26)] autorelease]; [mk setTitle:@"Default"]; [mk setBezelStyle:NSRoundedBezelStyle]; [mk setTarget:self]; [mk setAction:@selector(makeDefault:)]; [v addSubview:mk];
	CGFloat x = 190, y = 350; NSString *names[5] = { @"Text", @"Bold Text", @"Cursor", @"Selection", @"Background" };
	for (int i = 0; i < 5; i++) {
		[v addSubview:label(names[i], NSMakeRect(x, y, 100, 20))];
		wells[i] = [[[NSColorWell alloc] initWithFrame:NSMakeRect(x + 110, y - 4, 50, 26)] autorelease]; [wells[i] setTag:i]; [wells[i] setTarget:self]; [wells[i] setAction:@selector(colourChanged:)]; [v addSubview:wells[i]]; y -= 34;
	}
	[v addSubview:label(@"Opacity", NSMakeRect(x, y, 100, 20))]; opacity = [[[NSSlider alloc] initWithFrame:NSMakeRect(x + 110, y, 180, 20)] autorelease]; [opacity setMinValue:0.1]; [opacity setMaxValue:1]; [opacity setTarget:self]; [opacity setAction:@selector(numbersChanged:)]; [v addSubview:opacity]; y -= 34;
	[v addSubview:label(@"Blur", NSMakeRect(x, y, 100, 20))]; blurSlider = [[[NSSlider alloc] initWithFrame:NSMakeRect(x + 110, y, 180, 20)] autorelease]; [blurSlider setMinValue:0]; [blurSlider setMaxValue:1]; [blurSlider setTarget:self]; [blurSlider setAction:@selector(numbersChanged:)]; [v addSubview:blurSlider]; y -= 34;
	[v addSubview:label(@"Columns", NSMakeRect(x, y, 70, 20))]; colsField = [[[NSTextField alloc] initWithFrame:NSMakeRect(x + 70, y - 2, 50, 24)] autorelease]; [colsField setTarget:self]; [colsField setAction:@selector(numbersChanged:)]; [v addSubview:colsField];
	[v addSubview:label(@"Rows", NSMakeRect(x + 140, y, 50, 20))]; rowsField = [[[NSTextField alloc] initWithFrame:NSMakeRect(x + 190, y - 2, 50, 24)] autorelease]; [rowsField setTarget:self]; [rowsField setAction:@selector(numbersChanged:)]; [v addSubview:rowsField]; y -= 34;
	[v addSubview:label(@"Font size", NSMakeRect(x, y, 100, 20))]; sizeField = [[[NSTextField alloc] initWithFrame:NSMakeRect(x + 110, y - 2, 50, 24)] autorelease]; [sizeField setTarget:self]; [sizeField setAction:@selector(numbersChanged:)]; [v addSubview:sizeField]; y -= 34;
	blinkBox = [[[NSButton alloc] initWithFrame:NSMakeRect(x, y, 200, 20)] autorelease]; [blinkBox setButtonType:NSSwitchButton]; [blinkBox setTitle:@"Blink cursor"]; [blinkBox setTarget:self]; [blinkBox setAction:@selector(numbersChanged:)]; [v addSubview:blinkBox];
	aaBox = [[[NSButton alloc] initWithFrame:NSMakeRect(x + 200, y, 200, 20)] autorelease]; [aaBox setButtonType:NSSwitchButton]; [aaBox setTitle:@"Antialias text"]; [aaBox setTarget:self]; [aaBox setAction:@selector(numbersChanged:)]; [v addSubview:aaBox];
	[list reloadData]; NSUInteger di = [[TermProfile allProfiles] indexOfObject:[TermProfile defaultProfile]]; [list selectRowIndexes:[NSIndexSet indexSetWithIndex:di] byExtendingSelection:NO]; [self load:[[TermProfile allProfiles] objectAtIndex:di]];
	return v;
}
- (NSInteger)numberOfRowsInTableView:(NSTableView *)t { return (NSInteger)[[TermProfile allProfiles] count]; }
- (id)tableView:(NSTableView *)t objectValueForTableColumn:(NSTableColumn *)c row:(NSInteger)r { TermProfile *p = [[TermProfile allProfiles] objectAtIndex:(NSUInteger)r]; return [p isEqual:[TermProfile defaultProfile]] ? [p->name stringByAppendingString:@"  (default)"] : p->name; }
- (void)tableViewSelectionDidChange:(NSNotification *)n { NSInteger r = [list selectedRow]; if (r >= 0) [self load:[[TermProfile allProfiles] objectAtIndex:(NSUInteger)r]]; }
- (void)load:(TermProfile *)p
{
	cur = p; NSColor *cs[5] = { p->text, p->boldText, p->cursor, p->selection, p->background };
	for (int i = 0; i < 5; i++) [wells[i] setColor:i == 4 ? [cs[i] colorWithAlphaComponent:1] : cs[i]];
	[opacity setDoubleValue:[p->background alphaComponent]]; [blurSlider setDoubleValue:p->blur]; [colsField setIntValue:p->cols]; [rowsField setIntValue:p->rows]; [sizeField setDoubleValue:p->fontSize];
	[blinkBox setState:p->blink ? NSOnState : NSOffState]; [aaBox setState:p->antialias ? NSOnState : NSOffState];
}
- (void)colourChanged:(id)s
{
	if (!cur) return; NSColor *c = [(NSColorWell *)s color]; NSInteger t = [s tag];
	switch (t) { case 0: [cur->text release]; cur->text = [c retain]; break; case 1: [cur->boldText release]; cur->boldText = [c retain]; break; case 2: [cur->cursor release]; cur->cursor = [c retain]; break; case 3: [cur->selection release]; cur->selection = [c retain]; break;
		case 4: [cur->background release]; cur->background = [[c colorWithAlphaComponent:[opacity doubleValue]] retain]; break; }
	[cur changed];
}
- (void)numbersChanged:(id)s
{
	if (!cur) return;
	NSColor *b = [cur->background colorWithAlphaComponent:[opacity doubleValue]]; [cur->background release]; cur->background = [b retain];
	cur->blur = [blurSlider doubleValue]; cur->cols = MAX(20, MIN(400, [colsField intValue])); cur->rows = MAX(5, MIN(200, [rowsField intValue])); cur->fontSize = MAX(6, MIN(96, [sizeField doubleValue]));
	cur->blink = [blinkBox state] == NSOnState; cur->antialias = [aaBox state] == NSOnState; [cur changed];
}
- (void)makeDefault:(id)s { if (cur) { [TermProfile setDefaultProfile:cur]; [defPopup selectItemWithTitle:cur->name]; [list reloadData]; } }
@end
