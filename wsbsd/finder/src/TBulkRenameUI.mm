/* The dialog of Rename N Items…: a window of its own (see TFBulkRename). The names come from TFBulkRenamedNames (TBulkRename.mm). */
#import "TFinderViews.h"
#import <objc/runtime.h>

@interface TBulkRenameForm : NSObject { @public NSPopUpButton *mode, *where, *format; NSTextField *find, *repl, *text, *custom, *start, *example; NSView *v; NSArray *paths; } @end
@implementation TBulkRenameForm
- (NSDictionary *)params { return @{ @"mode": @([mode indexOfSelectedItem]), @"find": [find stringValue], @"replace": [repl stringValue], @"text": [text stringValue], @"after": @([where indexOfSelectedItem] == 1), @"format": @([format indexOfSelectedItem]), @"custom": [custom stringValue], @"start": @([start integerValue]) }; }
- (void)update:(id)s
{ if (!example) return;
	NSInteger m = [mode indexOfSelectedItem]; [find setHidden: m != 0]; [repl setHidden: m != 0]; [text setHidden: m != 1]; [format setHidden: m != 2]; [custom setHidden: m != 2]; [start setHidden: m != 2]; [where setHidden: m == 0];
	NSArray *r = TFBulkRenamedNames(@[ [paths firstObject] ], [self params]); [example setStringValue: [NSString stringWithFormat: @"Example: %@", [r firstObject] ?: @""]];
}
@end

/* the card of the dialog: dark rounded panel like an alert of the Finder */
@interface TBulkCard : NSView @end
@implementation TBulkCard
- (BOOL)isFlipped { return NO; }
- (void)drawRect:(NSRect)r { NSBezierPath *bp = [NSBezierPath bezierPathWithRoundedRect: NSInsetRect([self bounds], 0.5, 0.5) xRadius: 14 yRadius: 14]; [(TFDark() ? TFRGB(44, 44, 44) : TFRGB(236, 236, 236)) setFill]; [bp fill]; [TF_LINE setStroke]; [bp stroke]; }
@end
@interface TBulkButtons : NSObject { @public void (^done)(BOOL); } @end
@implementation TBulkButtons
- (void)ok:(id)s { if (done) done(YES); }
- (void)cancel:(id)s { if (done) done(NO); }
@end

/* asks how to rename (a window of its own, not a modal session: a modal one fights with the Finder windows for the key); the old and new names (full paths) of what changes go to done, nil when cancelled */
void TFBulkRename(NSArray *paths, void (^done)(NSArray *))
{
	TBulkRenameForm *f = [[TBulkRenameForm alloc] init]; f->paths = paths; CGFloat W = 380, H = 300, pad = 20; NSView *v = [[NSView alloc] initWithFrame: NSMakeRect(pad, 70, W - 2 * pad, 150)]; f->v = v; NSRect fw = [v bounds];
	NSTextField *(^F)(CGFloat, NSString *) = ^NSTextField *(CGFloat y, NSString *ph) { NSTextField *t = [[NSTextField alloc] initWithFrame: NSMakeRect(0, y, fw.size.width, 22)]; [t setPlaceholderString: ph]; [t setTarget: f]; [t setAction: @selector(update:)]; [v addSubview: t]; return t; };
	NSPopUpButton *(^P)(CGFloat, NSArray *) = ^NSPopUpButton *(CGFloat y, NSArray *items) { NSPopUpButton *b = [[NSPopUpButton alloc] initWithFrame: NSMakeRect(0, y, 200, 24) pullsDown: NO]; [b addItemsWithTitles: items]; [b setTarget: f]; [b setAction: @selector(update:)]; [v addSubview: b]; return b; };
	f->mode = P(126, @[ @"Replace Text", @"Add Text", @"Format" ]);
	f->find = F(94, @"Find"); f->repl = F(64, @"Replace With"); f->text = F(94, @"Add Text");
	f->format = P(92, @[ @"Name and Index", @"Name and Counter", @"Name and Date" ]); f->custom = F(62, @"Custom Format"); f->start = F(34, @"Start numbers at"); [f->start setStringValue: @"1"]; f->where = P(4, @[ @"before name", @"after name" ]);
	f->example = [[NSTextField alloc] initWithFrame: NSMakeRect(pad, 46, W - 2 * pad, 16)]; [f->example setEditable: NO]; [f->example setBezeled: NO]; [f->example setBordered: NO]; [f->example setDrawsBackground: NO]; [f->example setTextColor: TF_DIM]; [f->example setFont: [NSFont systemFontOfSize: 11]];
	NSTextField *title = [[NSTextField alloc] initWithFrame: NSMakeRect(pad, H - 40, W - 2 * pad, 20)]; [title setEditable: NO]; [title setSelectable: NO]; [title setBezeled: NO]; [title setBordered: NO]; [title setDrawsBackground: NO]; [title setTextColor: TF_TEXT]; [title setFont: [NSFont boldSystemFontOfSize: 13]]; [title setStringValue: [NSString stringWithFormat: @"Rename %lu items:", (unsigned long)[paths count]]];
	TBulkButtons *bt = [[TBulkButtons alloc] init]; NSButton *ok = [[NSButton alloc] initWithFrame: NSMakeRect(W - pad - 110, 10, 110, 28)], *cn = [[NSButton alloc] initWithFrame: NSMakeRect(W - pad - 230, 10, 110, 28)];
	[ok setTitle: @"Rename"]; [cn setTitle: @"Cancel"]; for (NSButton *b in @[ ok, cn ]) { [b setBezelStyle: NSRoundedBezelStyle]; [b setTarget: bt]; } [ok setAction: @selector(ok:)]; [cn setAction: @selector(cancel:)]; [ok setKeyEquivalent: @"\r"];
	NSWindow *w = [[TFinderWindow alloc] initWithContentRect: NSMakeRect(0, 0, W, H) styleMask: NSWindowStyleMaskBorderless backing: NSBackingStoreBuffered defer: NO]; [w setReleasedWhenClosed: NO]; [w setLevel: NSModalPanelWindowLevel]; [w setOpaque: NO]; [w setBackgroundColor: [NSColor clearColor]];
	TBulkCard *card = [[TBulkCard alloc] initWithFrame: NSMakeRect(0, 0, W, H)]; [w setContentView: card]; for (NSView *x in @[ title, v, f->example, cn, ok ]) [card addSubview: x]; [f update: nil]; [w center];
	__block TBulkButtons *keep = bt; __weak NSWindow *ww = w;
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
	TBulkCard *card = [[TBulkCard alloc] initWithFrame: NSMakeRect(0, 0, W, H)]; [w setContentView: card];
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
