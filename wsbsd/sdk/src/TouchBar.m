/* The Touch Bar: see include/wsbsd/TouchBar.h. GNUstep's NSTouchBar and item classes are empty; the behaviour is added here as categories with the state in an associated dictionary. */
#import <wsbsd/TouchBar.h>
#import <objc/runtime.h>

NSString *const NSTouchBarItemIdentifierFixedSpaceSmall = @"NSTouchBarItemIdentifierFixedSpaceSmall";
NSString *const NSTouchBarItemIdentifierFixedSpaceLarge = @"NSTouchBarItemIdentifierFixedSpaceLarge";
NSString *const NSTouchBarItemIdentifierFlexibleSpace = @"NSTouchBarItemIdentifierFlexibleSpace";
NSString *const NSTouchBarItemIdentifierOtherItemsProxy = @"NSTouchBarItemIdentifierOtherItemsProxy";
NSString *const NSTouchBarItemIdentifierCharacterPicker = @"NSTouchBarItemIdentifierCharacterPicker";
NSString *const NSTouchBarItemIdentifierTextFormat = @"NSTouchBarItemIdentifierTextFormat";
NSString *const NSTouchBarItemIdentifierTextAlignment = @"NSTouchBarItemIdentifierTextAlignment";
NSString *const NSTouchBarItemIdentifierTextColorPicker = @"NSTouchBarItemIdentifierTextColorPicker";
NSString *const NSTouchBarItemIdentifierTextStyle = @"NSTouchBarItemIdentifierTextStyle";
NSString *const NSTouchBarItemIdentifierTextList = @"NSTouchBarItemIdentifierTextList";
NSString *const NSTouchBarItemIdentifierTextHighlight = @"NSTouchBarItemIdentifierTextHighlight";
NSString *const NSTouchBarItemIdentifierCandidateList = @"NSTouchBarItemIdentifierCandidateList";

static const char kState;
static NSMutableDictionary *St(id o) { NSMutableDictionary *d = objc_getAssociatedObject(o, &kState); if (!d) { d = [NSMutableDictionary dictionary]; objc_setAssociatedObject(o, &kState, d, OBJC_ASSOCIATION_RETAIN_NONATOMIC); } return d; }
#define PROP(cls, getter, setter, type, key, copy) \
	- (type)getter { return St(self)[@key]; } - (void)setter:(type)v { if (v) St(self)[@key] = copy; else [St(self) removeObjectForKey:@key]; }
#define NUM(getter, setter, type, key, conv) - (type)getter { return [St(self)[@key] conv]; } - (void)setter:(type)v { St(self)[@key] = @(v); }

/* ---- the bar ---- */
@implementation NSTouchBar (WsbsdTouchBar)
- (id<NSTouchBarDelegate>)delegate { return [St(self)[@"delegate"] nonretainedObjectValue]; }
- (void)setDelegate:(id<NSTouchBarDelegate>)d { St(self)[@"delegate"] = [NSValue valueWithNonretainedObject: d]; }
PROP(NSTouchBar, customizationIdentifier, setCustomizationIdentifier, NSString *, "ci", [v copy])
PROP(NSTouchBar, customizationAllowedItemIdentifiers, setCustomizationAllowedItemIdentifiers, NSArray *, "ca", [v copy])
PROP(NSTouchBar, customizationRequiredItemIdentifiers, setCustomizationRequiredItemIdentifiers, NSArray *, "cr", [v copy])
PROP(NSTouchBar, defaultItemIdentifiers, setDefaultItemIdentifiers, NSArray *, "di", [v copy])
PROP(NSTouchBar, principalItemIdentifier, setPrincipalItemIdentifier, NSString *, "pi", [v copy])
PROP(NSTouchBar, escapeKeyReplacementItemIdentifier, setEscapeKeyReplacementItemIdentifier, NSString *, "ek", [v copy])
- (NSSet *)templateItems { return St(self)[@"ti"]; } - (void)setTemplateItems:(NSSet *)s { St(self)[@"ti"] = [s copy] ?: [NSSet set]; [St(self) removeObjectForKey: @"items"]; }
- (NSArray *)itemIdentifiers { return [self defaultItemIdentifiers] ?: @[]; }
- (BOOL)isVisible { return [St(self)[@"visible"] boolValue]; }
- (void)_wsSetVisible:(BOOL)v { St(self)[@"visible"] = @(v); }
- (NSTouchBarItem *)itemForIdentifier:(NSTouchBarItemIdentifier)ident
{
	NSMutableDictionary *cache = St(self)[@"items"]; if (!cache) cache = St(self)[@"items"] = [NSMutableDictionary dictionary];
	NSTouchBarItem *it = cache[ident]; if (it) return it;
	for (NSTouchBarItem *t in [self templateItems]) if ([[t identifier] isEqual: ident]) { it = t; break; }
	id<NSTouchBarDelegate> d = [self delegate];
	if (!it && [d respondsToSelector: @selector(touchBar:makeItemForIdentifier:)]) it = [d touchBar: self makeItemForIdentifier: ident];
	if (it) cache[ident] = it; return it;
}
+ (BOOL)isAutomaticCustomizeTouchBarMenuItemEnabled { return NO; }
@end

/* ---- items ---- */
@implementation NSTouchBarItem (WsbsdTouchBar)
- (instancetype)initWithIdentifier:(NSTouchBarItemIdentifier)i { if ((self = [self init])) St(self)[@"id"] = [i copy]; return self; }
- (NSTouchBarItemIdentifier)identifier { return St(self)[@"id"]; }
- (float)visibilityPriority { return [St(self)[@"prio"] floatValue]; } - (void)setVisibilityPriority:(float)p { St(self)[@"prio"] = @(p); }
- (NSView *)view { return nil; } - (NSViewController *)viewController { return nil; } - (NSString *)customizationLabel { return nil; }
- (BOOL)isVisible { return [self view] != nil && [[self view] window] != nil; }
@end

@implementation NSCustomTouchBarItem (WsbsdTouchBar)
- (NSView *)view { NSViewController *vc = St(self)[@"vc"]; return St(self)[@"view"] ?: [vc view]; } - (void)setView:(NSView *)v { if (v) St(self)[@"view"] = v; else [St(self) removeObjectForKey: @"view"]; }
- (NSViewController *)viewController { return St(self)[@"vc"]; } - (void)setViewController:(NSViewController *)vc { if (vc) St(self)[@"vc"] = vc; else [St(self) removeObjectForKey: @"vc"]; }
- (NSString *)customizationLabel { return St(self)[@"label"]; } - (void)setCustomizationLabel:(NSString *)l { St(self)[@"label"] = [l copy]; }
@end

/* the dark rounded button of the Touch Bar */
@interface WsbsdTBButton : NSButton @end
@implementation WsbsdTBButton
- (BOOL)isFlipped { return YES; }
- (void)drawRect:(NSRect)r
{
	NSRect b = NSInsetRect([self bounds], 0.5, 1.5); NSColor *fill = [(NSCell *)[self cell] isHighlighted] ? [NSColor colorWithCalibratedWhite: 0.45 alpha: 1] : [NSColor colorWithCalibratedWhite: 0.22 alpha: 1];
	NSColor *tint = [self respondsToSelector: @selector(bezelColor)] ? [self performSelector: @selector(bezelColor)] : nil; if (tint && ![(NSCell *)[self cell] isHighlighted]) fill = tint;
	[fill setFill]; [[NSBezierPath bezierPathWithRoundedRect: b xRadius: 6 yRadius: 6] fill];
	NSImage *img = [self image]; NSString *t = [self title]; NSDictionary *at = @{ NSForegroundColorAttributeName: [self isEnabled] ? [NSColor whiteColor] : [NSColor grayColor], NSFontAttributeName: [NSFont systemFontOfSize: 15] };
	NSSize ts = [t sizeWithAttributes: at], is = img ? [img size] : NSZeroSize; CGFloat total = ts.width + (img && [t length] ? 6 : 0) + (img ? MIN(is.width, 20) : 0), x = floor((b.size.width - total) / 2);
	if (img) { NSRect ir = NSMakeRect(x, floor((b.size.height - 20) / 2) + 1, MIN(is.width, 20), 20); [img drawInRect: ir fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1]; x += ir.size.width + 6; }
	if ([t length]) [t drawAtPoint: NSMakePoint(x, floor((b.size.height - ts.height) / 2)) withAttributes: at];
}
@end

@implementation NSButtonTouchBarItem (WsbsdTouchBar)
static WsbsdTBButton *Btn(NSButtonTouchBarItem *i) { WsbsdTBButton *b = St(i)[@"btn"]; if (!b) { b = [[WsbsdTBButton alloc] initWithFrame: NSMakeRect(0, 0, 60, 30)]; [b setBordered: NO]; St(i)[@"btn"] = b; } return b; }
static void Fit(NSButtonTouchBarItem *i) { WsbsdTBButton *b = Btn(i); NSString *t = [b title]; CGFloat w = [t length] ? [t sizeWithAttributes: @{ NSFontAttributeName: [NSFont systemFontOfSize: 15] }].width + 28 : 0; if ([b image]) w += ([t length] ? 6 : 0) + 20 + ([t length] ? 0 : 28); [b setFrameSize: NSMakeSize(MAX(w, 64), 30)]; [b setNeedsDisplay: YES]; }
+ (instancetype)buttonTouchBarItemWithIdentifier:(NSTouchBarItemIdentifier)i title:(NSString *)t image:(NSImage *)img target:(id)tg action:(SEL)a { NSButtonTouchBarItem *it = [[self alloc] initWithIdentifier: i]; WsbsdTBButton *b = Btn(it); [b setTitle: t ?: @""]; [b setImage: img]; [b setTarget: tg]; [b setAction: a]; Fit(it); return it; }
+ (instancetype)buttonTouchBarItemWithIdentifier:(NSTouchBarItemIdentifier)i title:(NSString *)t target:(id)tg action:(SEL)a { return [self buttonTouchBarItemWithIdentifier: i title: t image: nil target: tg action: a]; }
+ (instancetype)buttonTouchBarItemWithIdentifier:(NSTouchBarItemIdentifier)i image:(NSImage *)img target:(id)tg action:(SEL)a { return [self buttonTouchBarItemWithIdentifier: i title: nil image: img target: tg action: a]; }
- (NSView *)view { return Btn(self); }
- (NSString *)title { return [Btn(self) title]; } - (void)setTitle:(NSString *)t { [Btn(self) setTitle: t ?: @""]; Fit(self); }
- (NSImage *)image { return [Btn(self) image]; } - (void)setImage:(NSImage *)i { [Btn(self) setImage: i]; Fit(self); }
- (NSColor *)bezelColor { return St(self)[@"bezel"]; } - (void)setBezelColor:(NSColor *)c { St(self)[@"bezel"] = c ?: [NSNull null]; objc_setAssociatedObject(Btn(self), "bezelColor", c, OBJC_ASSOCIATION_RETAIN_NONATOMIC); [Btn(self) setNeedsDisplay: YES]; }
- (id)target { return [Btn(self) target]; } - (void)setTarget:(id)t { [Btn(self) setTarget: t]; }
- (SEL)action { return [Btn(self) action]; } - (void)setAction:(SEL)a { [Btn(self) setAction: a]; }
- (BOOL)isEnabled { return [Btn(self) isEnabled]; } - (void)setEnabled:(BOOL)e { [Btn(self) setEnabled: e]; [Btn(self) setNeedsDisplay: YES]; }
- (NSString *)customizationLabel { return St(self)[@"label"]; } - (void)setCustomizationLabel:(NSString *)l { St(self)[@"label"] = [l copy]; }
@end
@implementation WsbsdTBButton (Bezel) - (NSColor *)bezelColor { return objc_getAssociatedObject(self, "bezelColor"); } @end

/* the strip of views of a bar */
@interface WsbsdTBStrip : NSView { @public NSArray *entries; } @end   /* entries: NSView, or NSNumber (fixed width) or NSNull (flexible) */
@implementation WsbsdTBStrip
- (BOOL)isFlipped { return YES; }
- (void)layoutEntries
{
	CGFloat fixed = 0; NSUInteger flex = 0, n = [entries count], i = 0;
	for (id e in entries) { if ([e isKindOfClass: [NSView class]]) fixed += [e frame].size.width; else if ([e isKindOfClass: [NSNumber class]]) fixed += [e doubleValue]; else flex++; }
	fixed += 8 * (n ? n - 1 : 0); CGFloat free = MAX(0, [self bounds].size.width - fixed), x = 0, H = [self bounds].size.height;
	for (id e in entries) { CGFloat w = 0; if ([e isKindOfClass: [NSView class]]) { NSView *v = e; w = [v frame].size.width; [v setFrame: NSMakeRect(x, floor((H - MIN([v frame].size.height, H)) / 2), w, MIN([v frame].size.height, H))]; if ([v superview] != self) [self addSubview: v]; }
		else if ([e isKindOfClass: [NSNumber class]]) w = [e doubleValue]; else w = flex ? free / flex : 0; x += w + (++i < n ? 8 : 0); }
}
- (void)resizeSubviewsWithOldSize:(NSSize)o { [self layoutEntries]; }
- (void)setFrame:(NSRect)f { [super setFrame: f]; [self layoutEntries]; }
@end
static NSArray *EntriesForBar(NSTouchBar *bar, NSSet *skip, CGFloat *natural)
{
	NSMutableArray *a = [NSMutableArray array]; CGFloat w = 0;
	for (NSString *ident in [bar itemIdentifiers]) {
		if ([skip containsObject: ident] || [ident isEqual: NSTouchBarItemIdentifierOtherItemsProxy]) continue;
		if ([ident isEqual: NSTouchBarItemIdentifierFlexibleSpace]) { [a addObject: [NSNull null]]; continue; }
		if ([ident isEqual: NSTouchBarItemIdentifierFixedSpaceSmall]) { [a addObject: @8]; w += 8; continue; }
		if ([ident isEqual: NSTouchBarItemIdentifierFixedSpaceLarge]) { [a addObject: @24]; w += 24; continue; }
		NSView *v = [[bar itemForIdentifier: ident] view]; if (!v) continue; [a addObject: v]; w += [v frame].size.width;
	}
	if (natural) *natural = w + 8 * ([a count] ? [a count] - 1 : 0); return a;
}
static NSView *StripForBar(NSTouchBar *bar, CGFloat width, NSSet *skip)
{
	CGFloat nat; NSArray *e = EntriesForBar(bar, skip, &nat); WsbsdTBStrip *s = [[WsbsdTBStrip alloc] initWithFrame: NSMakeRect(0, 0, width > 0 ? width : nat, 30)]; s->entries = e; [s layoutEntries]; return s;
}

@implementation NSGroupTouchBarItem (WsbsdTouchBar)
+ (instancetype)groupItemWithIdentifier:(NSTouchBarItemIdentifier)i items:(NSArray *)items
{
	NSGroupTouchBarItem *g = [[self alloc] initWithIdentifier: i]; NSTouchBar *b = [NSTouchBar new]; NSMutableSet *t = [NSMutableSet set]; NSMutableArray *ids = [NSMutableArray array];
	for (NSTouchBarItem *it in items) { [t addObject: it]; [ids addObject: [it identifier]]; } [b setTemplateItems: t]; [b setDefaultItemIdentifiers: ids]; [g setGroupTouchBar: b]; return g;
}
- (NSTouchBar *)groupTouchBar { return St(self)[@"bar"]; } - (void)setGroupTouchBar:(NSTouchBar *)b { St(self)[@"bar"] = b; [St(self) removeObjectForKey: @"view"]; }
- (NSView *)view { NSView *v = St(self)[@"view"]; if (!v) { NSTouchBar *b = [self groupTouchBar]; if (!b) return nil; CGFloat nat; EntriesForBar(b, nil, &nat); v = StripForBar(b, nat, nil); St(self)[@"view"] = v; } return v; }
- (NSString *)customizationLabel { return St(self)[@"label"]; } - (void)setCustomizationLabel:(NSString *)l { St(self)[@"label"] = [l copy]; }
@end

@implementation NSSliderTouchBarItem (WsbsdTouchBar)
- (NSSlider *)slider { NSSlider *s = St(self)[@"slider"]; if (!s) { s = [[NSSlider alloc] initWithFrame: NSMakeRect(0, 0, 200, 30)]; St(self)[@"slider"] = s; } return s; }
- (void)setSlider:(NSSlider *)s { St(self)[@"slider"] = s; }
- (NSView *)view { return [self slider]; }
- (double)doubleValue { return [[self slider] doubleValue]; } - (void)setDoubleValue:(double)d { [[self slider] setDoubleValue: d]; }
- (id)target { return [[self slider] target]; } - (void)setTarget:(id)t { [[self slider] setTarget: t]; }
- (SEL)action { return [[self slider] action]; } - (void)setAction:(SEL)a { [[self slider] setAction: a]; }
- (NSString *)customizationLabel { return St(self)[@"label"]; } - (void)setCustomizationLabel:(NSString *)l { St(self)[@"label"] = [l copy]; }
@end

/* ---- the responder chain ---- */
@implementation NSResponder (WsbsdTouchBar)
- (NSTouchBar *)touchBar { return St(self)[@"touchBar"]; }
- (void)setTouchBar:(NSTouchBar *)b { if (b) St(self)[@"touchBar"] = b; else [St(self) removeObjectForKey: @"touchBar"]; }
- (NSTouchBar *)makeTouchBar { return nil; }
@end

/* the black rounded background of the strip, and the control strip at its right (brightness, volume, mute, Siri) */
@interface WsbsdTBBackground : NSView @end
@implementation WsbsdTBBackground
- (BOOL)isFlipped { return YES; }
- (void)drawRect:(NSRect)r { [[NSColor clearColor] set]; NSRectFill([self bounds]); [[NSColor colorWithCalibratedWhite: 0.02 alpha: 1] setFill]; [[NSBezierPath bezierPathWithRoundedRect: NSInsetRect([self bounds], 1, 1) xRadius: 9 yRadius: 9] fill]; [[NSColor colorWithCalibratedWhite: 0.28 alpha: 1] setStroke]; [[NSBezierPath bezierPathWithRoundedRect: NSInsetRect([self bounds], 1.5, 1.5) xRadius: 9 yRadius: 9] stroke]; }
@end
@interface WsbsdTBControlStrip : NSView @end
@implementation WsbsdTBControlStrip
- (BOOL)isFlipped { return YES; }
- (void)drawRect:(NSRect)r
{
	NSColor *w = [NSColor colorWithCalibratedWhite: 0.9 alpha: 1]; [w setStroke]; [w setFill]; CGFloat cy = [self bounds].size.height / 2, x = 20;
	/* brightness: a disc with rays */
	NSBezierPath *p = [NSBezierPath bezierPathWithOvalInRect: NSMakeRect(x - 4, cy - 4, 8, 8)]; [p setLineWidth: 1.5]; [p stroke];
	for (int i = 0; i < 8; i++) { double a = i * M_PI / 4; NSBezierPath *l = [NSBezierPath bezierPath]; [l moveToPoint: NSMakePoint(x + cos(a) * 7, cy + sin(a) * 7)]; [l lineToPoint: NSMakePoint(x + cos(a) * 10, cy + sin(a) * 10)]; [l setLineWidth: 1.5]; [l stroke]; }
	/* volume: a speaker with waves */
	x = 85; NSBezierPath *sp = [NSBezierPath bezierPath]; [sp moveToPoint: NSMakePoint(x - 9, cy - 3)]; [sp lineToPoint: NSMakePoint(x - 5, cy - 3)]; [sp lineToPoint: NSMakePoint(x + 1, cy - 8)]; [sp lineToPoint: NSMakePoint(x + 1, cy + 8)]; [sp lineToPoint: NSMakePoint(x - 5, cy + 3)]; [sp lineToPoint: NSMakePoint(x - 9, cy + 3)]; [sp closePath]; [sp fill];
	for (int i = 1; i <= 2; i++) { NSBezierPath *a = [NSBezierPath bezierPath]; [a appendBezierPathWithArcWithCenter: NSMakePoint(x + 2, cy) radius: 4 + i * 4 startAngle: -40 endAngle: 40]; [a setLineWidth: 1.5]; [a stroke]; }
	/* mute: a speaker crossed out */
	x = 150; NSBezierPath *m = [NSBezierPath bezierPath]; [m moveToPoint: NSMakePoint(x - 9, cy - 3)]; [m lineToPoint: NSMakePoint(x - 5, cy - 3)]; [m lineToPoint: NSMakePoint(x + 1, cy - 8)]; [m lineToPoint: NSMakePoint(x + 1, cy + 8)]; [m lineToPoint: NSMakePoint(x - 5, cy + 3)]; [m lineToPoint: NSMakePoint(x - 9, cy + 3)]; [m closePath]; [m fill];
	NSBezierPath *c = [NSBezierPath bezierPath]; [c moveToPoint: NSMakePoint(x + 5, cy - 5)]; [c lineToPoint: NSMakePoint(x + 14, cy + 5)]; [c setLineWidth: 1.5]; [c stroke];
	/* Siri: a ring with a gradient-less dot */
	x = 215; NSBezierPath *o = [NSBezierPath bezierPathWithOvalInRect: NSMakeRect(x - 9, cy - 9, 18, 18)]; [o setLineWidth: 2]; [[NSColor colorWithCalibratedRed: 0.55 green: 0.45 blue: 1 alpha: 1] setStroke]; [o stroke];
}
- (void)mouseDown:(NSEvent *)e
{
	CGFloat x = [self convertPoint: [e locationInWindow] fromView: nil].x; const char *cmd = x < 55 ? NULL : x < 118 ? "volume" : x < 182 ? "mute" : NULL; (void)cmd;
}
@end
/* ---- the host: the bar of the key window in a panel at the bottom of the screen ---- */
@implementation WsbsdTouchBarHost { NSTouchBar *_bar; NSPanel *_panel; NSView *_content; NSString *_signature; }
@synthesize currentTouchBar = _bar, panel = _panel;
+ (instancetype)sharedHost { static WsbsdTouchBarHost *h; static dispatch_once_t once; dispatch_once(&once, ^{ h = [WsbsdTouchBarHost new]; }); return h; }
static NSTouchBar *BarOfResponder(NSResponder *r)
{
	for (; r; r = [r nextResponder]) {
		NSTouchBar *b = [r touchBar]; if (!b) { b = [r makeTouchBar]; if (b) [r setTouchBar: b]; } if (b) return b;
	}
	return nil;
}
- (NSTouchBar *)_resolve
{
	if (![NSApp isActive]) return nil; NSWindow *w = [NSApp keyWindow]; if (w == _panel) w = [NSApp mainWindow]; if (!w) return nil;
	NSTouchBar *b = BarOfResponder([w firstResponder] ?: w); if (!b) b = [w touchBar]; if (!b) b = [NSApp touchBar]; return b;
}
- (void)_ensurePanel
{
	if (_panel) return; NSRect sf = [[NSScreen mainScreen] frame];
	_panel = [[NSPanel alloc] initWithContentRect: NSMakeRect(NSMidX(sf) - 560, 40, 1120, 46) styleMask: NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel backing: NSBackingStoreBuffered defer: NO];
	[_panel setLevel: NSStatusWindowLevel]; [_panel setBecomesKeyOnlyIfNeeded: YES]; [_panel setHidesOnDeactivate: NO]; [_panel setBackgroundColor: [NSColor clearColor]]; [_panel setOpaque: NO]; [_panel setHasShadow: NO]; [_panel setTitle: @"Touch Bar"]; [_panel setReleasedWhenClosed: NO];
}
- (void)_escape:(id)sender { [NSApp sendAction: @selector(cancelOperation:) to: nil from: sender]; }
- (void)update
{
	NSTouchBar *b = [self _resolve];
	if (!b) { if (_panel && [_panel isVisible]) [_panel orderOut: nil]; [_bar _wsSetVisible: NO]; _bar = nil; _signature = nil; return; }
	NSString *esc = [b escapeKeyReplacementItemIdentifier]; NSString *sig = [NSString stringWithFormat: @"%p|%@|%@", b, [[b itemIdentifiers] componentsJoinedByString: @","], esc ?: @""];
	[self _ensurePanel];
	if (b != _bar || ![sig isEqual: _signature]) {
		[_bar _wsSetVisible: NO]; _bar = b; _signature = sig; [_content removeFromSuperview];
		NSView *root = [[WsbsdTBBackground alloc] initWithFrame: NSMakeRect(0, 0, 1120, 46)]; NSTouchBarItem *e = esc ? [b itemForIdentifier: esc] : nil; CGFloat x = 17, csw = 245;
		NSView *ev = [e view]; if (!ev) { NSButtonTouchBarItem *eb = [NSButtonTouchBarItem buttonTouchBarItemWithIdentifier: @"esc" title: @"esc" target: self action: @selector(_escape:)]; ev = [eb view]; [ev setFrameSize: NSMakeSize(64, 30)]; objc_setAssociatedObject(root, "escItem", eb, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
		[ev setFrameOrigin: NSMakePoint(x, 8)]; [root addSubview: ev]; x += [ev frame].size.width + 17;
		NSView *strip = StripForBar(b, 1120 - 17 - csw - 17 - x, esc ? [NSSet setWithObject: esc] : nil); [strip setFrameOrigin: NSMakePoint(x, 8)]; [root addSubview: strip];
		WsbsdTBControlStrip *cs = [[WsbsdTBControlStrip alloc] initWithFrame: NSMakeRect(1120 - 17 - csw, 8, csw, 30)]; [root addSubview: cs];
		_content = root; [_panel setContentView: root];
	}
	[b _wsSetVisible: YES]; if (![_panel isVisible]) [_panel orderFront: nil];
}
@end

/* the host runs from the main queue as soon as there is an application (a constructor cannot touch Objective-C classes yet) */
static void TBPoll(void *ctx)
{
	@autoreleasepool { const char *e = getenv("WSBSD_TOUCHBAR"); if (NSApp && !(e && !strcmp(e, "0"))) [[WsbsdTouchBarHost sharedHost] update]; }
	dispatch_after_f(dispatch_time(DISPATCH_TIME_NOW, 300 * NSEC_PER_MSEC), dispatch_get_main_queue(), NULL, TBPoll);
}
__attribute__((constructor)) static void TBStart(void) { dispatch_async_f(dispatch_get_main_queue(), NULL, TBPoll); }
