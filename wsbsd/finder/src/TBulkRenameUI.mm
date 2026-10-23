/* The dialog of Rename N Items…: a window of its own (see TFBulkRename). The names come from TFBulkRenamedNames (TBulkRename.mm). */
#import "TFinderViews.h"
#import <objc/runtime.h>
#include <dlfcn.h>

/* the card of the dialogs: the window colour (tinted by the wallpaper like any window of the Mac) with a 1 pt lighter rim, corners of 16 */
@interface TBulkCard : NSView @end
@implementation TBulkCard
- (BOOL)isFlipped { return YES; }
- (void)drawRect:(NSRect)r
{
	NSColor *bg = nil; typedef NSColor *(*TintFn)(NSWindow *); static TintFn fn; static BOOL looked; if (!looked) { looked = YES; fn = (TintFn)dlsym(RTLD_DEFAULT, "WsdTintedWindowBackground"); } if (fn) bg = fn([self window]); if (!bg) bg = [NSColor windowBackgroundColor];
	NSBezierPath *bp = [NSBezierPath bezierPathWithRoundedRect: NSInsetRect([self bounds], 0.5, 0.5) xRadius: 16 yRadius: 16]; [bg setFill]; [bp fill]; [TFDark() ? TFRGBA(255, 255, 255, 0.10) : TFRGBA(0, 0, 0, 0.12) setStroke]; [bp stroke];
}
@end
/* the same card with the origin at the bottom (the layout of TFAsk) */
@interface TAskCard : TBulkCard @end
@implementation TAskCard
- (BOOL)isFlipped { return NO; }
@end
@interface TBulkButtons : NSObject { @public void (^done)(BOOL); } @end
@implementation TBulkButtons
- (void)ok:(id)s { if (done) done(YES); }
- (void)cancel:(id)s { if (done) done(NO); }
@end

/* Rename Finder Items…, the sheet of the Mac, laid out from the accessibility tree of the real one (489 wide, centred on the window; from the top of the sheet; every control 13 pt):
 * the title "Rename Finder Items:" (19, 3); the format pop-up 109 x 22 at (19, 34); Replace Text (132 high): "Find:" (19, 65) and its field 157 x 24 at (53, 61), "Replace with:" (234, 65) and its field at (313, 61),
 * the example (19, 105), the buttons Cancel and Rename 75 x 26 at (310, 99) and (395, 99); Add Text (103 high): the text field 222 x 24 at (134, 33), the pop-up "after name"/"before name" 108 x 22 at
 * (362, 34), the example at (19, 76), the buttons at y 70; Format (161 high): "Name Format:" (19, 64) with its pop-up 141 x 22 at (111, 61) ("Name and Index", "Name and Counter" (five digits), "Name and Date"
 * ("2026-10-23 at 1.13.30 PM")), "Where:" (271, 64) with its pop-up 108 x 22 at (371, 61), "Custom Format:" (19, 94) with its field 141 x 24 at (111, 90) ("File " at first), "Start numbers at:" (271, 94)
 * with its field at (371, 90) ("1"), the example at (19, 134), the buttons at y 128. Not measured: the material behind the sheet, the look of the pop-ups and of the fields (the theme's). */
@interface TBulkRenameForm : NSObject { @public NSPopUpButton *mode, *where, *format; NSTextField *find, *repl, *text, *custom, *start, *example, *lFind, *lRepl, *lFormat, *lWhere, *lCustom, *lStart, *title; NSButton *ok, *cancel; NSWindow *win; NSView *card; NSArray *paths; } @end
@implementation TBulkRenameForm
- (NSDictionary *)params { return @{ @"mode": @([mode indexOfSelectedItem]), @"find": [find stringValue], @"replace": [repl stringValue], @"text": [text stringValue], @"after": @([where indexOfSelectedItem] == 0), @"format": @([format indexOfSelectedItem]), @"custom": [custom stringValue], @"start": @([start integerValue]) }; }
static void Place(NSView *v, CGFloat H, CGFloat x, CGFloat y, CGFloat w, CGFloat h) { [v setFrame: NSMakeRect(x, y, w, h)]; }
- (void)update:(id)s
{
	if (!example) return; NSInteger m = [mode indexOfSelectedItem]; CGFloat H = m == 0 ? 132 : m == 1 ? 103 : 161, dy = m == 0 ? 0 : 0;
	NSRect f = [win frame]; double midY = NSMidY(f); f.size = NSMakeSize(489, H); f.origin.y = midY - H / 2; [win setFrame: f display: YES]; [card setFrameSize: NSMakeSize(489, H)]; (void)dy;
	for (NSView *v in @[ find, repl, lFind, lRepl ]) [v setHidden: m != 0]; for (NSView *v in @[ text ]) [v setHidden: m != 1]; for (NSView *v in @[ format, custom, start, lFormat, lCustom, lStart ]) [v setHidden: m != 2]; [where setHidden: m == 0]; [lWhere setHidden: m != 2];
	Place(title, H, 19, 3, 300, 18); Place(mode, H, 19, 34, 109, 22);
	if (m == 0) { Place(lFind, H, 19, 65, 36, 16); Place(find, H, 53, 61, 157, 24); Place(lRepl, H, 234, 65, 82, 16); Place(repl, H, 313, 61, 157, 24); Place(example, H, 19, 105, 285, 16); Place(cancel, H, 310, 99, 75, 26); Place(ok, H, 395, 99, 75, 26); }
	else if (m == 1) { Place(text, H, 134, 33, 222, 24); Place(where, H, 362, 34, 108, 22); Place(example, H, 19, 76, 285, 16); Place(cancel, H, 310, 70, 75, 26); Place(ok, H, 395, 70, 75, 26); }
	else { Place(lFormat, H, 19, 64, 86, 16); Place(format, H, 111, 61, 141, 22); Place(lWhere, H, 271, 64, 94, 16); Place(where, H, 371, 61, 108, 22); Place(lCustom, H, 19, 94, 86, 16); Place(custom, H, 111, 90, 141, 24); Place(lStart, H, 271, 94, 94, 16); Place(start, H, 371, 90, 108, 24); Place(example, H, 19, 134, 285, 16); Place(cancel, H, 310, 128, 75, 26); Place(ok, H, 395, 128, 75, 26); }
	NSArray *r = TFBulkRenamedNames(@[ [paths firstObject] ], [self params]); [example setStringValue: [NSString stringWithFormat: @"Example: %@", [r firstObject] ?: @""]]; NSArray *all = TFBulkRenamedNames(paths, [self params]); BOOL any = NO; for (NSUInteger i = 0; i < [paths count] && i < [all count]; i++) if ([all[i] length] && ![all[i] isEqual: [paths[i] lastPathComponent]]) any = YES; [ok setEnabled: any]; [card setNeedsDisplay: YES];
}
@end

/* asks how to rename (a window of its own, not a modal session: a modal one fights with the Finder windows for the key); the old and new names (full paths) of what changes go to done, nil when cancelled */
void TFBulkRename(NSArray *paths, void (^done)(NSArray *))
{
	TBulkRenameForm *f = [[TBulkRenameForm alloc] init]; f->paths = paths; NSRect pw = [[NSApp keyWindow] frame]; if (NSIsEmptyRect(pw)) pw = [[NSScreen mainScreen] frame];
	NSWindow *w = [[TFinderWindow alloc] initWithContentRect: NSMakeRect(NSMidX(pw) - 244.5, NSMidY(pw) - 66, 489, 132) styleMask: NSWindowStyleMaskBorderless backing: NSBackingStoreBuffered defer: NO]; [w setReleasedWhenClosed: NO]; [w setLevel: NSModalPanelWindowLevel]; [w setOpaque: NO]; [w setBackgroundColor: [NSColor clearColor]];
	TBulkCard *card = [[TBulkCard alloc] initWithFrame: NSMakeRect(0, 0, 489, 132)]; [w setContentView: card]; f->win = w; f->card = card;
	NSTextField *(^Label)(NSString *, BOOL) = ^NSTextField *(NSString *s, BOOL dim) { NSTextField *t = [[NSTextField alloc] initWithFrame: NSZeroRect]; [t setEditable: NO]; [t setSelectable: NO]; [t setBezeled: NO]; [t setBordered: NO]; [t setDrawsBackground: NO]; [t setTextColor: dim ? TF_DIM : TF_TEXT]; [t setFont: [NSFont systemFontOfSize: 13]]; [t setStringValue: s]; [card addSubview: t]; return t; };
	NSTextField *(^Field)(void) = ^NSTextField *{ NSTextField *t = [[NSTextField alloc] initWithFrame: NSZeroRect]; [t setTarget: f]; [t setAction: @selector(update:)]; [card addSubview: t]; return t; };
	NSPopUpButton *(^Pop)(NSArray *) = ^NSPopUpButton *(NSArray *items) { NSPopUpButton *b = [[NSPopUpButton alloc] initWithFrame: NSZeroRect pullsDown: NO]; [b addItemsWithTitles: items]; [b setTarget: f]; [b setAction: @selector(update:)]; [card addSubview: b]; return b; };
	f->title = Label(@"Rename Finder Items:", YES); f->mode = Pop(@[ @"Replace Text", @"Add Text", @"Format" ]);
	f->lFind = Label(@"Find:", NO); f->find = Field(); f->lRepl = Label(@"Replace with:", NO); f->repl = Field(); f->text = Field(); f->where = Pop(@[ @"after name", @"before name" ]);
	f->lFormat = Label(@"Name Format:", NO); f->format = Pop(@[ @"Name and Index", @"Name and Counter", @"Name and Date" ]); f->lWhere = Label(@"Where:", NO); f->lCustom = Label(@"Custom Format:", NO); f->custom = Field(); [f->custom setStringValue: @"File "]; f->lStart = Label(@"Start numbers at:", NO); f->start = Field(); [f->start setStringValue: @"1"];
	f->example = Label(@"", NO); TBulkButtons *bt = [[TBulkButtons alloc] init]; f->ok = [[NSButton alloc] initWithFrame: NSZeroRect]; f->cancel = [[NSButton alloc] initWithFrame: NSZeroRect];
	[f->ok setTitle: @"Rename"]; [f->cancel setTitle: @"Cancel"]; for (NSButton *b in @[ f->ok, f->cancel ]) { [b setBezelStyle: NSRoundedBezelStyle]; [b setTarget: bt]; [card addSubview: b]; } [f->ok setAction: @selector(ok:)]; [f->cancel setAction: @selector(cancel:)]; [f->ok setKeyEquivalent: @"\r"];
	[f update: nil];
	__weak NSWindow *ww = w; __block TBulkButtons *keep = bt;
	bt->done = ^(BOOL yes) { NSArray *res = nil; if (yes) { NSArray *nn = TFBulkRenamedNames(paths, [f params]); NSMutableArray *r = [NSMutableArray array];
			for (NSUInteger i = 0; i < [paths count]; i++) { NSString *old = paths[i], *nw = nn[i]; if ([nw length] && ![nw containsString: @"/"] && ![nw isEqual: [old lastPathComponent]]) [r addObject: @[ old, [[old stringByDeletingLastPathComponent] stringByAppendingPathComponent: nw] ]]; } res = r; }
		[ww orderOut: nil]; keep->done = nil; keep = nil; done(res); };
	objc_setAssociatedObject(w, "bulk", @[ bt, f ], OBJC_ASSOCIATION_RETAIN); [w makeKeyAndOrderFront: nil]; static NSWindow *open; open = w;
}

/* A question with text fields in a window of its own (NSAlert here draws no accessory view, and a modal session fights with the Finder windows for the key): the values go to done, nil when cancelled.
 * fields: dictionaries with label (the placeholder), value and secure (a password). */
void TFAsk(NSString *title, NSString *message, NSArray *fields, NSString *okTitle, void (^done)(NSArray *values))
{
	if (getenv("FINDER_DEBUG")) NSLog(@"ask: %@", title);
	CGFloat W = 400, pad = 20, rowH = 30, nf = [fields count], msgH = [message length] ? 34 : 0, H = 40 + msgH + nf * rowH + 64; NSMutableArray *tf = [NSMutableArray array];
	NSWindow *w = [[TFinderWindow alloc] initWithContentRect: NSMakeRect(0, 0, W, H) styleMask: NSWindowStyleMaskBorderless backing: NSBackingStoreBuffered defer: NO]; [w setReleasedWhenClosed: NO]; [w setLevel: NSModalPanelWindowLevel]; [w setOpaque: NO]; [w setBackgroundColor: [NSColor clearColor]];
	TBulkCard *card = [[TAskCard alloc] initWithFrame: NSMakeRect(0, 0, W, H)]; [w setContentView: card];
	NSTextField *(^Label)(NSRect, NSString *, NSFont *, NSColor *) = ^NSTextField *(NSRect r, NSString *s, NSFont *f, NSColor *c) { NSTextField *t = [[NSTextField alloc] initWithFrame: r]; [t setEditable: NO]; [t setSelectable: NO]; [t setBezeled: NO]; [t setBordered: NO]; [t setDrawsBackground: NO]; [t setTextColor: c]; [t setFont: f]; [t setStringValue: s]; return t; };
	[card addSubview: Label(NSMakeRect(pad, H - 38, W - 2 * pad, 20), title, [NSFont boldSystemFontOfSize: 13], TF_TEXT)];
	if (msgH) { NSTextField *m = Label(NSMakeRect(pad, H - 38 - msgH, W - 2 * pad, msgH - 4), message, [NSFont systemFontOfSize: 11], TF_DIM); [card addSubview: m]; }
	for (NSUInteger i = 0; i < [fields count]; i++) {
		NSDictionary *d = fields[i]; NSRect r = NSMakeRect(pad, H - 40 - msgH - (i + 1) * rowH, W - 2 * pad, 24); NSTextField *t = [d[@"secure"] boolValue] ? [[NSSecureTextField alloc] initWithFrame: r] : [[NSTextField alloc] initWithFrame: r];
		[t setPlaceholderString: d[@"label"]]; [t setStringValue: d[@"value"] ?: @""]; [card addSubview: t]; [tf addObject: t];
	}
	TBulkButtons *bt = [[TBulkButtons alloc] init]; NSButton *ok = [[NSButton alloc] initWithFrame: NSMakeRect(W - pad - 110, 14, 110, 28)], *cn = [[NSButton alloc] initWithFrame: NSMakeRect(W - pad - 230, 14, 110, 28)];
	[ok setTitle: okTitle ?: @"OK"]; [cn setTitle: @"Cancel"]; for (NSButton *b in @[ ok, cn ]) { [b setBezelStyle: NSRoundedBezelStyle]; [b setTarget: bt]; } [ok setAction: @selector(ok:)]; [cn setAction: @selector(cancel:)]; [ok setKeyEquivalent: @"\r"]; [card addSubview: cn]; [card addSubview: ok];
	__weak NSWindow *ww = w; __block TBulkButtons *keep = bt;
	bt->done = ^(BOOL yes) { NSMutableArray *vals = nil; if (yes) { vals = [NSMutableArray array]; for (NSTextField *t in tf) [vals addObject: [t stringValue] ?: @""]; } [ww orderOut: nil]; keep->done = nil; keep = nil; done(vals); };
	objc_setAssociatedObject(w, "ask", @[ bt, tf ], OBJC_ASSOCIATION_RETAIN); [w center]; [w makeKeyAndOrderFront: nil]; static NSWindow *open; open = w; if ([tf count]) [w makeFirstResponder: tf[0]];
}
