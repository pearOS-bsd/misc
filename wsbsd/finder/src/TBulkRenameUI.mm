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
