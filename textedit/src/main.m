/* TextEdit for wsbsd: the text editor of the Mac, laid out from the real one (accessibility tree of its window: 603 x 505 with the title bar, the formatting bar 36 high under it (the segments bold / italic /
 * underline / strikethrough, text colour, typeface, style, size, alignment, list, line spacing), the ruler 32 high, the text area under it; the menu bar from its accessibility dump, tools/gen_menu.py).
 * What works: new, open, save, save as (plain text and RTF), the Edit menu, fonts (bold, italic, underline, bigger, smaller, the font panel where AppKit has one), alignment, plain / rich text, find (the text
 * view's own), zoom, undo. Items whose action is not written yet are disabled (the menu shows them as the Mac does). Standard AppKit only: NSWindow, NSScrollView, NSTextView, NSSegmentedControl, NSPopUpButton, NSComboBox. */
#import <AppKit/AppKit.h>

typedef struct { int depth; NSString *title, *key; unsigned mask; int enabled; } TEMenuRow;
static const TEMenuRow kMenu[] = {
#include "TEMenu.inc"
};

static void EachFont(NSTextStorage *ts, NSRange r, void (^blk)(NSFont *f, NSRange rr))       /* GNUstep has no enumerateAttribute:inRange:options:usingBlock: */
{
	NSUInteger i = r.location, end = NSMaxRange(r);
	while (i < end) { NSRange er; id v = [ts attribute: NSFontAttributeName atIndex: i effectiveRange: &er]; NSRange cut = NSIntersectionRange(er, r); blk(v, cut); i = NSMaxRange(er) > i ? NSMaxRange(er) : i + 1; }
}
@interface TEDocument : NSObject <NSWindowDelegate, NSTextViewDelegate> { @public NSWindow *window; NSTextView *text; NSString *path; BOOL rich, edited; NSView *fmtBar; NSScrollView *scroll; CGFloat zoom; NSSegmentedControl *traits, *align; NSComboBox *size; }
+ (NSMutableArray *)all; + (TEDocument *)current;
- (void)open:(NSString *)p; - (BOOL)saveTo:(NSString *)p;
@end
@implementation TEDocument
+ (NSMutableArray *)all { static NSMutableArray *a; if (!a) a = [NSMutableArray array]; return a; }
+ (TEDocument *)current { NSWindow *k = [NSApp keyWindow] ?: [NSApp mainWindow]; for (TEDocument *d in [self all]) if (d->window == k) return d; return [[self all] lastObject]; }
- (instancetype)init
{
	if (!(self = [super init])) return nil; rich = YES; zoom = 1;
	NSScreen *sc = [NSScreen mainScreen]; NSRect sf = [sc frame]; static int n; CGFloat ox = (sf.size.width - 603) / 2 + 22 * (n % 8), oy = sf.size.height - 30 - 70 - 505 - 22 * (n % 8); n++;
	window = [[NSWindow alloc] initWithContentRect: NSMakeRect(ox, oy, 603, 473) styleMask: NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask backing: NSBackingStoreBuffered defer: NO];
	[window setReleasedWhenClosed: NO]; [window setDelegate: self]; [window setTitle: @"Untitled"]; [window setMinSize: NSMakeSize(260, 160)];
	NSView *cv = [window contentView]; CGFloat W = 603, H = 473;
	fmtBar = [[NSView alloc] initWithFrame: NSMakeRect(0, H - 36, W, 36)]; [fmtBar setAutoresizingMask: NSViewWidthSizable | NSViewMinYMargin]; [cv addSubview: fmtBar];
	traits = [[NSSegmentedControl alloc] initWithFrame: NSMakeRect(7, 7, 87, 22)]; [traits setSegmentCount: 4]; for (int i = 0; i < 4; i++) { [traits setWidth: i == 2 ? 21 : 22 forSegment: i]; [traits setLabel: @[ @"B", @"I", @"U", @"S" ][i] forSegment: i]; } [traits setTrackingMode: NSSegmentSwitchTrackingSelectAny]; [traits setTarget: self]; [traits setAction: @selector(traitPicked:)]; [fmtBar addSubview: traits];
	NSPopUpButton *face = [[NSPopUpButton alloc] initWithFrame: NSMakeRect(147, 7, 82, 22) pullsDown: NO]; NSMutableArray *fams = [NSMutableArray arrayWithObject: @"Helvetica"]; for (NSString *f in [[NSFontManager sharedFontManager] availableFontFamilies]) if (![fams containsObject: f] && [fams count] < 60) [fams addObject: f]; [face addItemsWithTitles: fams]; [face selectItemAtIndex: 0]; [face setTarget: self]; [face setAction: @selector(facePicked:)]; [fmtBar addSubview: face];
	size = [[NSComboBox alloc] initWithFrame: NSMakeRect(317, 7, 52, 22)]; [size addItemsWithObjectValues: @[ @9, @10, @11, @12, @13, @14, @18, @24, @36, @48, @64, @72 ]]; [size setStringValue: @"12"]; [size setTarget: self]; [size setAction: @selector(sizePicked:)]; [fmtBar addSubview: size];
	align = [[NSSegmentedControl alloc] initWithFrame: NSMakeRect(372, 7, 94, 22)]; [align setSegmentCount: 4]; for (int i = 0; i < 4; i++) { [align setWidth: 23 forSegment: i]; [align setLabel: @[ @"⇤", @"↔", @"⇥", @"☰" ][i] forSegment: i]; } [align setSelectedSegment: 0]; [align setTarget: self]; [align setAction: @selector(alignPicked:)]; [fmtBar addSubview: align];
	scroll = [[NSScrollView alloc] initWithFrame: NSMakeRect(0, 0, W, H - 36)]; [scroll setHasVerticalScroller: YES]; [scroll setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable]; [scroll setBorderType: NSNoBorder];
	text = [[NSTextView alloc] initWithFrame: NSMakeRect(0, 0, W, H - 36)]; [text setMinSize: NSMakeSize(0, H - 36)]; [text setMaxSize: NSMakeSize(1e7, 1e7)]; [text setVerticallyResizable: YES]; [text setHorizontallyResizable: NO]; [text setAutoresizingMask: NSViewWidthSizable]; [[text textContainer] setContainerSize: NSMakeSize(W, 1e7)]; [[text textContainer] setWidthTracksTextView: YES];
	[text setRichText: YES]; [text setUsesFontPanel: YES]; [text setAllowsUndo: YES]; [text setFont: [NSFont fontWithName: @"Helvetica" size: 12] ?: [NSFont systemFontOfSize: 12]]; [text setDelegate: self]; [text setTextContainerInset: NSMakeSize(5, 5)];
	[scroll setDocumentView: text]; [cv addSubview: scroll]; [[TEDocument all] addObject: self]; [window makeKeyAndOrderFront: nil]; [window makeFirstResponder: text]; return self;
}
- (void)traitPicked:(NSSegmentedControl *)s { NSFontManager *fm = [NSFontManager sharedFontManager]; NSInteger i = [s selectedSegment]; BOOL on = [s isSelectedForSegment: i];
	if (i == 0) [self setTrait: NSBoldFontMask on: on]; else if (i == 1) [self setTrait: NSItalicFontMask on: on]; else if (i == 2) [text underline: nil]; else [self strike: on]; (void)fm; }
- (void)setTrait:(NSFontTraitMask)m on:(BOOL)on { NSFontManager *fm = [NSFontManager sharedFontManager]; NSRange r = [text selectedRange]; if (!r.length) { NSFont *f = [text font]; [text setFont: on ? [fm convertFont: f toHaveTrait: m] : [fm convertFont: f toNotHaveTrait: m]]; return; }
	[[text textStorage] beginEditing]; EachFont([text textStorage], r, ^(NSFont *v, NSRange rr) { NSFont *f = v ?: [text font]; [[text textStorage] addAttribute: NSFontAttributeName value: on ? [fm convertFont: f toHaveTrait: m] : [fm convertFont: f toNotHaveTrait: m] range: rr]; }); [[text textStorage] endEditing]; }
- (void)strike:(BOOL)on { NSRange r = [text selectedRange]; if (!r.length) return; if (on) [[text textStorage] addAttribute: NSStrikethroughStyleAttributeName value: @1 range: r]; else [[text textStorage] removeAttribute: NSStrikethroughStyleAttributeName range: r]; }
- (void)facePicked:(NSPopUpButton *)p { NSFont *f = [text font]; NSFont *n = [[NSFontManager sharedFontManager] convertFont: f toFamily: [p titleOfSelectedItem]]; NSRange r = [text selectedRange]; if (r.length) [[text textStorage] addAttribute: NSFontAttributeName value: n range: r]; else [text setFont: n]; }
- (void)sizePicked:(NSComboBox *)c { CGFloat s = [[c stringValue] doubleValue]; if (s < 4 || s > 200) return; [self setFontSize: s]; }
- (void)setFontSize:(CGFloat)s { NSFontManager *fm = [NSFontManager sharedFontManager]; NSRange r = [text selectedRange]; if (!r.length) { [text setFont: [fm convertFont: [text font] toSize: s]]; return; }
	EachFont([text textStorage], r, ^(NSFont *v, NSRange rr) { [[text textStorage] addAttribute: NSFontAttributeName value: [fm convertFont: v ?: [text font] toSize: s] range: rr]; }); }
- (void)alignPicked:(NSSegmentedControl *)a { switch ([a selectedSegment]) { case 0: [text alignLeft: nil]; break; case 1: [text alignCenter: nil]; break; case 2: [text alignRight: nil]; break; default: [text setAlignment: NSJustifiedTextAlignment]; } }
- (void)open:(NSString *)p
{
	path = [p copy]; NSString *ext = [[p pathExtension] lowercaseString]; NSData *d = [NSData dataWithContentsOfFile: p]; if (!d) return;
	if ([ext isEqual: @"rtf"]) { NSAttributedString *a = [[NSAttributedString alloc] initWithRTF: d documentAttributes: NULL]; if (a) { rich = YES; [[text textStorage] setAttributedString: a]; } }
	else { NSString *s = [[NSString alloc] initWithData: d encoding: NSUTF8StringEncoding] ?: [[NSString alloc] initWithData: d encoding: NSISOLatin1StringEncoding] ?: @""; rich = NO; [self makePlain]; [text setString: s]; }
	[window setTitle: [p lastPathComponent]]; [window setRepresentedFilename: p]; edited = NO; [window setDocumentEdited: NO];
}
- (void)makePlain { rich = NO; [text setRichText: NO]; [text setFont: [NSFont userFixedPitchFontOfSize: 12] ?: [NSFont systemFontOfSize: 12]]; [fmtBar setHidden: YES]; NSRect f = [scroll frame]; f.size.height = [[window contentView] bounds].size.height; f.origin.y = 0; [scroll setFrame: f]; }
- (void)makeRich { rich = YES; [text setRichText: YES]; [text setFont: [NSFont fontWithName: @"Helvetica" size: 12] ?: [NSFont systemFontOfSize: 12]]; [fmtBar setHidden: NO]; NSRect f = [scroll frame]; f.size.height = [[window contentView] bounds].size.height - 36; [scroll setFrame: f]; }
- (BOOL)saveTo:(NSString *)p
{
	NSData *d = rich && [[[p pathExtension] lowercaseString] isEqual: @"rtf"] ? [[text textStorage] RTFFromRange: NSMakeRange(0, [[text textStorage] length]) documentAttributes: @{}] : [[[text string] copy] dataUsingEncoding: NSUTF8StringEncoding];
	if (![d writeToFile: p atomically: YES]) { NSBeep(); return NO; } path = [p copy]; [window setTitle: [p lastPathComponent]]; [window setRepresentedFilename: p]; edited = NO; [window setDocumentEdited: NO]; return YES;
}
- (void)textDidChange:(NSNotification *)n { if (!edited) { edited = YES; [window setDocumentEdited: YES]; } }
- (BOOL)windowShouldClose:(id)w
{
	if (!edited) return YES; NSAlert *a = [[NSAlert alloc] init]; [a setMessageText: [NSString stringWithFormat: @"Do you want to save the changes made to the document “%@”?", [window title]]]; [a setInformativeText: @"Your changes will be lost if you don’t save them."]; [a addButtonWithTitle: @"Save"]; [a addButtonWithTitle: @"Cancel"]; [a addButtonWithTitle: @"Delete"];
	NSInteger r = [a runModal]; if (r == NSAlertFirstButtonReturn) { [self save: nil]; return !edited; } return r == NSAlertThirdButtonReturn;
}
- (void)windowWillClose:(NSNotification *)n { [[TEDocument all] removeObject: self]; }
- (void)save:(id)s { if (path) { [self saveTo: path]; return; } [self saveAs: s]; }
- (void)saveAs:(id)s { NSSavePanel *sp = [NSSavePanel savePanel]; [sp setNameFieldStringValue: rich ? @"Untitled.rtf" : @"Untitled.txt"]; if ([sp runModal] == NSOKButton) [self saveTo: [[sp URL] path]]; }
@end

@interface TEApp : NSObject <NSApplicationDelegate, NSMenuDelegate> @end
@implementation TEApp
- (SEL)selectorFor:(NSString *)t inMenu:(NSString *)top
{
	static NSDictionary *map; if (!map) map = @{ @"New": @"newDoc:", @"Open…": @"openDoc:", @"Close": @"performClose:", @"Save…": @"saveDoc:", @"Save As…": @"saveDocAs:", @"Revert To": @"", @"Undo": @"undo:", @"Redo": @"redo:", @"Cut": @"cut:", @"Copy": @"copy:", @"Paste": @"paste:", @"Delete": @"delete:", @"Select All": @"selectAll:",
		@"Find…": @"performFindPanelAction:", @"Find Next": @"performFindPanelAction:", @"Find Previous": @"performFindPanelAction:", @"Bold": @"bold:", @"Italic": @"italic:", @"Underline": @"underline:", @"Bigger": @"bigger:", @"Smaller": @"smaller:", @"Show Fonts": @"orderFrontFontPanel:", @"Show Colors": @"orderFrontColorPanel:",
		@"Align Left": @"alignLeft:", @"Center": @"alignCenter:", @"Align Right": @"alignRight:", @"Justify": @"alignJustified:", @"Make Plain Text": @"togglePlain:", @"Make Rich Text": @"togglePlain:", @"Make Upper Case": @"uppercaseWord:", @"Make Lower Case": @"lowercaseWord:", @"Capitalize": @"capitalizeWord:",
		@"Actual Size": @"actualSize:", @"Zoom In": @"zoomIn:", @"Zoom Out": @"zoomOut:", @"Minimize": @"performMiniaturize:", @"Zoom": @"performZoom:", @"Bring All to Front": @"arrangeInFront:", @"Quit TextEdit": @"terminate:", @"Hide TextEdit": @"hide:", @"Hide Others": @"hideOtherApplications:", @"Show All": @"unhideAllApplications:", @"About TextEdit": @"about:", @"Close All": @"closeAll:" };
	NSString *s = map[t]; return [s length] ? NSSelectorFromString(s) : NULL;
}
- (void)buildMenu
{
	NSMenu *bar = [[NSMenu alloc] initWithTitle: @""]; NSMenu *stack[8] = { bar }; int depth = -1;
	// the application's own menu first: its title is the application name
	NSMenu *cur = nil; NSMenuItem *lastItem = nil;
	for (size_t i = 0; i < sizeof kMenu / sizeof kMenu[0]; i++) {
		const TEMenuRow *r = &kMenu[i];
		if (r->depth < 0) { cur = [[NSMenu alloc] initWithTitle: r->title]; [cur setAutoenablesItems: YES]; NSMenuItem *top = [bar addItemWithTitle: r->title action: NULL keyEquivalent: @""]; [top setSubmenu: cur]; stack[0] = cur; depth = 0; lastItem = nil; continue; }
		while (r->depth < depth) depth--;
		if (r->depth > depth && lastItem) { NSMenu *sub = [[NSMenu alloc] initWithTitle: [lastItem title]]; [sub setAutoenablesItems: YES]; [lastItem setSubmenu: sub]; depth = r->depth; stack[depth] = sub; }
		NSMenu *m = stack[r->depth]; if ([r->title isEqual: @"-"]) { [m addItem: [NSMenuItem separatorItem]]; lastItem = nil; continue; }
		NSString *top = [[bar itemAtIndex: [bar numberOfItems] - 1] title]; SEL a = [self selectorFor: r->title inMenu: top];
		NSMenuItem *it = [m addItemWithTitle: r->title action: a keyEquivalent: [r->key length] == 1 ? [r->key lowercaseString] : @""]; if ([r->key length] == 1) { [it setKeyEquivalentModifierMask: r->mask]; if ([[NSCharacterSet uppercaseLetterCharacterSet] characterIsMember: [r->key characterAtIndex: 0]] && (r->mask & 0x20000)) {} }
		if (a) [it setTarget: self]; lastItem = it; if ([r->title isEqual: @"Make Plain Text"]) [it setTarget: self];
	}
	[NSApp setMainMenu: bar];
}
- (BOOL)validateMenuItem:(NSMenuItem *)it
{
	SEL a = [it action]; TEDocument *d = [TEDocument current];
	if (a == @selector(newDoc:) || a == @selector(openDoc:) || a == @selector(terminate:) || a == @selector(about:) || a == @selector(hide:) || a == @selector(hideOtherApplications:)) return YES;
	if (!d) return NO;
	if (a == @selector(togglePlain:)) { [it setTitle: d->rich ? @"Make Plain Text" : @"Make Rich Text"]; return YES; }
	return YES;
}
- (void)newDoc:(id)s { [[TEDocument alloc] init]; }
- (void)openDoc:(id)s { NSOpenPanel *op = [NSOpenPanel openPanel]; [op setAllowsMultipleSelection: YES]; if ([op runModal] == NSOKButton) for (NSURL *u in [op URLs]) { TEDocument *d = [[TEDocument alloc] init]; [d open: [u path]]; } }
- (void)saveDoc:(id)s { [[TEDocument current] save: s]; }
- (void)saveDocAs:(id)s { [[TEDocument current] saveAs: s]; }
- (void)closeAll:(id)s { for (TEDocument *d in [[TEDocument all] copy]) [d->window performClose: nil]; }
- (void)about:(id)s { [NSApp orderFrontStandardAboutPanel: nil]; }
- (void)bold:(id)s { TEDocument *d = [TEDocument current]; [d setTrait: NSBoldFontMask on: ![[[d->text font] fontName] containsString: @"Bold"]]; }
- (void)italic:(id)s { TEDocument *d = [TEDocument current]; [d setTrait: NSItalicFontMask on: !([[[d->text font] fontName] containsString: @"Italic"] || [[[d->text font] fontName] containsString: @"Oblique"])]; }
- (void)underline:(id)s { [[TEDocument current]->text underline: nil]; }
- (void)bigger:(id)s { TEDocument *d = [TEDocument current]; [d setFontSize: [[d->text font] pointSize] + 1]; }
- (void)smaller:(id)s { TEDocument *d = [TEDocument current]; [d setFontSize: MAX(4.0, [[d->text font] pointSize] - 1)]; }
- (void)alignLeft:(id)s { [[TEDocument current]->text alignLeft: nil]; } - (void)alignCenter:(id)s { [[TEDocument current]->text alignCenter: nil]; } - (void)alignRight:(id)s { [[TEDocument current]->text alignRight: nil]; } - (void)alignJustified:(id)s { [[TEDocument current]->text setAlignment: NSJustifiedTextAlignment]; }
- (void)togglePlain:(id)s { TEDocument *d = [TEDocument current]; if (d->rich) [d makePlain]; else [d makeRich]; }
- (void)actualSize:(id)s { TEDocument *d = [TEDocument current]; d->zoom = 1; [d->text setFont: [d->text font]]; }
- (void)zoomIn:(id)s { [self bigger: s]; } - (void)zoomOut:(id)s { [self smaller: s]; }
- (void)applicationDidFinishLaunching:(NSNotification *)n { [self buildMenu]; if (![[TEDocument all] count]) [[TEDocument alloc] init]; [NSApp activateIgnoringOtherApps: YES]; }
- (BOOL)application:(NSApplication *)a openFile:(NSString *)f { TEDocument *d = [[TEDocument alloc] init]; [d open: f]; return YES; }
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)a { return NO; }       /* as on the Mac the application stays until Command-Q */
- (BOOL)applicationShouldHandleReopen:(NSApplication *)a hasVisibleWindows:(BOOL)f { if (!f) [[TEDocument alloc] init]; return YES; }
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)a { for (TEDocument *d in [[TEDocument all] copy]) if (d->edited) { [d->window makeKeyAndOrderFront: nil]; if (![d windowShouldClose: d->window]) return NSTerminateCancel; } return NSTerminateNow; }
@end

int main(int argc, char **argv)
{
	@autoreleasepool {
		[NSApplication sharedApplication]; TEApp *app = [[TEApp alloc] init]; [NSApp setDelegate: app];
		[NSApp run];
	}
	return 0;
}
