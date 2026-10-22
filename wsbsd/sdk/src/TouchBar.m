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
static id self_palette(void) { static id o; if (!o) o = [NSObject new]; return o; }
static NSString *CustomKey(NSTouchBar *b) { NSString *c = [b customizationIdentifier]; return [c length] ? [@"NSTouchBar Configuration " stringByAppendingString: c] : nil; }
- (NSArray *)itemIdentifiers { NSString *k = CustomKey(self); NSArray *saved = k ? [[NSUserDefaults standardUserDefaults] arrayForKey: k] : nil; if (saved) { NSArray *allowed = [self customizationAllowedItemIdentifiers]; NSMutableArray *r = [NSMutableArray array]; for (NSString *i in saved) if (!allowed || [allowed containsObject: i] || [i hasPrefix: @"NSTouchBarItemIdentifier"]) [r addObject: i]; for (NSString *i in [self customizationRequiredItemIdentifiers]) if (![r containsObject: i]) [r addObject: i]; return r; } return [self defaultItemIdentifiers] ?: @[]; }
- (void)_wsSaveItems:(NSArray *)ids { NSString *k = CustomKey(self); if (!k) return; if (ids) [[NSUserDefaults standardUserDefaults] setObject: ids forKey: k]; else [[NSUserDefaults standardUserDefaults] removeObjectForKey: k]; St(self)[@"items"] = nil; [St(self) removeObjectForKey: @"items"]; }
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

/* ---- the template images AppKit names for the Touch Bar (NSImageNameTouchBar*Template), drawn white ---- */
typedef void (^GlyphDraw)(void);
static NSBezierPath *Line(CGFloat x1, CGFloat y1, CGFloat x2, CGFloat y2) { NSBezierPath *p = [NSBezierPath bezierPath]; [p moveToPoint: NSMakePoint(x1, y1)]; [p lineToPoint: NSMakePoint(x2, y2)]; [p setLineWidth: 1.8]; [p setLineCapStyle: NSRoundLineCapStyle]; [p setLineJoinStyle: NSRoundLineJoinStyle]; return p; }
static void Chevron(CGFloat dx, CGFloat dy) { NSBezierPath *p = [NSBezierPath bezierPath]; [p moveToPoint: NSMakePoint(10 - dx * 3 + dy * 5, 10 - dy * 3 + dx * 5)]; [p lineToPoint: NSMakePoint(10 + dx * 4, 10 + dy * 4)]; [p lineToPoint: NSMakePoint(10 - dx * 3 - dy * 5, 10 - dy * 3 - dx * 5)]; [p setLineWidth: 2]; [p setLineCapStyle: NSRoundLineCapStyle]; [p setLineJoinStyle: NSRoundLineJoinStyle]; [p stroke]; }
static void Tri(CGFloat x, CGFloat w, BOOL right) { NSBezierPath *p = [NSBezierPath bezierPath]; if (right) { [p moveToPoint: NSMakePoint(x, 4)]; [p lineToPoint: NSMakePoint(x + w, 10)]; [p lineToPoint: NSMakePoint(x, 16)]; } else { [p moveToPoint: NSMakePoint(x + w, 4)]; [p lineToPoint: NSMakePoint(x, 10)]; [p lineToPoint: NSMakePoint(x + w, 16)]; } [p closePath]; [p fill]; }
static NSDictionary *GlyphTable(void)
{
	return @{
		@"GoBack": ^{ Chevron(-1, 0); }, @"GoForward": ^{ Chevron(1, 0); }, @"GoUp": ^{ Chevron(0, 1); }, @"GoDown": ^{ Chevron(0, -1); },
		@"Search": ^{ NSBezierPath *c = [NSBezierPath bezierPathWithOvalInRect: NSMakeRect(3.5, 7.5, 9, 9)]; [c setLineWidth: 1.8]; [c stroke]; [Line(11.5, 8.5, 16.5, 3.5) stroke]; },
		@"Bookmarks": ^{ NSBezierPath *b = [NSBezierPath bezierPathWithRect: NSMakeRect(3.5, 3.5, 13, 13)]; [b setLineWidth: 1.8]; [b stroke]; [Line(10, 3.5, 10, 16.5) stroke]; },
		@"Add": ^{ [Line(10, 4, 10, 16) stroke]; [Line(4, 10, 16, 10) stroke]; }, @"Remove": ^{ [Line(4, 10, 16, 10) stroke]; },
		@"Refresh": ^{ NSBezierPath *a = [NSBezierPath bezierPath]; [a appendBezierPathWithArcWithCenter: NSMakePoint(10, 10) radius: 6 startAngle: 30 endAngle: 330]; [a setLineWidth: 1.8]; [a stroke]; NSBezierPath *h = [NSBezierPath bezierPath]; [h moveToPoint: NSMakePoint(15.2, 13)]; [h lineToPoint: NSMakePoint(16.5, 7.8)]; [h lineToPoint: NSMakePoint(11.3, 9.6)]; [h closePath]; [h fill]; },
		@"Sidebar": ^{ NSBezierPath *b = [NSBezierPath bezierPathWithRoundedRect: NSMakeRect(3.5, 4.5, 13, 11) xRadius: 1.5 yRadius: 1.5]; [b setLineWidth: 1.8]; [b stroke]; [Line(8, 4.5, 8, 15.5) stroke]; },
		@"Share": ^{ NSBezierPath *b = [NSBezierPath bezierPath]; [b moveToPoint: NSMakePoint(6, 8)]; [b lineToPoint: NSMakePoint(4, 8)]; [b lineToPoint: NSMakePoint(4, 3.5)]; [b lineToPoint: NSMakePoint(16, 3.5)]; [b lineToPoint: NSMakePoint(16, 8)]; [b lineToPoint: NSMakePoint(14, 8)]; [b setLineWidth: 1.8]; [b stroke]; [Line(10, 4.5, 10, 16) stroke]; [Line(6.5, 12.5, 10, 16) stroke]; [Line(13.5, 12.5, 10, 16) stroke]; },
		@"Delete": ^{ [Line(4.5, 15, 15.5, 15) stroke]; NSBezierPath *b = [NSBezierPath bezierPath]; [b moveToPoint: NSMakePoint(6, 15)]; [b lineToPoint: NSMakePoint(6.8, 4)]; [b lineToPoint: NSMakePoint(13.2, 4)]; [b lineToPoint: NSMakePoint(14, 15)]; [b setLineWidth: 1.8]; [b stroke]; [Line(8.5, 17, 11.5, 17) stroke]; },
		@"Play": ^{ Tri(6, 10, YES); }, @"Pause": ^{ [[NSBezierPath bezierPathWithRect: NSMakeRect(5, 4, 3.5, 12)] fill]; [[NSBezierPath bezierPathWithRect: NSMakeRect(11.5, 4, 3.5, 12)] fill]; },
		@"Rewind": ^{ Tri(2, 8, NO); Tri(10, 8, NO); }, @"FastForward": ^{ Tri(2, 8, YES); Tri(10, 8, YES); },
		@"NewFolder": ^{ NSBezierPath *b = [NSBezierPath bezierPathWithRoundedRect: NSMakeRect(3, 4.5, 14, 10) xRadius: 1.5 yRadius: 1.5]; [b setLineWidth: 1.8]; [b stroke]; [Line(3, 14.5, 8, 14.5) stroke]; [Line(10, 7, 10, 12) stroke]; [Line(7.5, 9.5, 12.5, 9.5) stroke]; },
		@"TextLeftAlign": ^{ [Line(4, 16, 16, 16) stroke]; [Line(4, 12, 12, 12) stroke]; [Line(4, 8, 16, 8) stroke]; [Line(4, 4, 11, 4) stroke]; },
		@"TextCenterAlign": ^{ [Line(4, 16, 16, 16) stroke]; [Line(6, 12, 14, 12) stroke]; [Line(4, 8, 16, 8) stroke]; [Line(7, 4, 13, 4) stroke]; },
		@"TextRightAlign": ^{ [Line(4, 16, 16, 16) stroke]; [Line(8, 12, 16, 12) stroke]; [Line(4, 8, 16, 8) stroke]; [Line(9, 4, 16, 4) stroke]; },
		@"TextJustifiedAlign": ^{ [Line(4, 16, 16, 16) stroke]; [Line(4, 12, 16, 12) stroke]; [Line(4, 8, 16, 8) stroke]; [Line(4, 4, 16, 4) stroke]; },
		@"Download": ^{ [Line(10, 16, 10, 5) stroke]; [Line(6.5, 8.5, 10, 5) stroke]; [Line(13.5, 8.5, 10, 5) stroke]; [Line(4, 3.5, 16, 3.5) stroke]; },
	};
}
static void RegisterGlyphs(void)
{
	NSDictionary *t = GlyphTable();
	for (NSString *k in t) {
		NSString *name = [NSString stringWithFormat: @"NSTouchBar%@Template", k]; if ([NSImage imageNamed: name]) continue;
		NSImage *img = [[NSImage alloc] initWithSize: NSMakeSize(20, 20)]; [img lockFocus]; [[NSColor whiteColor] setStroke]; [[NSColor whiteColor] setFill]; ((GlyphDraw)t[k])(); [img unlockFocus]; [img setTemplate: YES]; [img setName: name];
	}
}
/* an image in the colour of the strip: template images (black glyphs) are drawn white */
static NSImage *Tinted(NSImage *img, NSColor *c)
{
	if (!img) return nil; NSSize sz = [img size]; if (sz.width < 1 || sz.height < 1) return img;
	NSImage *out = [[NSImage alloc] initWithSize: sz]; [out lockFocus]; [img drawInRect: NSMakeRect(0, 0, sz.width, sz.height) fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1]; [c set]; NSRectFillUsingOperation(NSMakeRect(0, 0, sz.width, sz.height), NSCompositeSourceIn); [out unlockFocus]; return out;
}

/* the dark rounded button of the Touch Bar */
@interface WsbsdTBButton : NSButton @end
@interface WsbsdTBSwatchButton : WsbsdTBButton { @public NSColor *swatchColor; } @end
@implementation WsbsdTBButton
- (BOOL)isFlipped { return YES; }
- (void)drawRect:(NSRect)r
{
	NSRect b = NSInsetRect([self bounds], 0.5, 1.5); NSColor *fill = [(NSCell *)[self cell] isHighlighted] ? [NSColor colorWithCalibratedWhite: 0.45 alpha: 1] : [NSColor colorWithCalibratedWhite: 0.22 alpha: 1];
	NSColor *tint = [self respondsToSelector: @selector(bezelColor)] ? [self performSelector: @selector(bezelColor)] : nil; if (tint && ![(NSCell *)[self cell] isHighlighted]) fill = tint;
	NSColor *sw = [self isKindOfClass: [WsbsdTBSwatchButton class]] ? ((WsbsdTBSwatchButton *)self)->swatchColor : nil; BOOL letter = sw && [[self title] length];
	if (sw && !letter) fill = sw;
	[fill setFill]; [[NSBezierPath bezierPathWithRoundedRect: b xRadius: 6 yRadius: 6] fill]; if (sw && !letter) return;
	if (letter) { NSDictionary *la = @{ NSForegroundColorAttributeName: [NSColor whiteColor], NSFontAttributeName: [NSFont boldSystemFontOfSize: 15] }; NSSize lz = [[self title] sizeWithAttributes: la]; [[self title] drawAtPoint: NSMakePoint(floor((b.size.width - lz.width) / 2), floor((b.size.height - lz.height) / 2) - 2) withAttributes: la]; [sw setFill]; [[NSBezierPath bezierPathWithRoundedRect: NSMakeRect(b.origin.x + 12, b.size.height - 8, b.size.width - 24, 4) xRadius: 2 yRadius: 2] fill]; return; }
	NSImage *img = Tinted([self image], [self isEnabled] ? [NSColor whiteColor] : [NSColor grayColor]); NSString *t = [self title]; NSDictionary *at = @{ NSForegroundColorAttributeName: [self isEnabled] ? [NSColor whiteColor] : [NSColor grayColor], NSFontAttributeName: [NSFont systemFontOfSize: 15] };
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
@implementation WsbsdTBSwatchButton @end
/* a button that shows a colour (the swatches of the colour picker); the class is chosen at creation, a class swap would lose associated objects */
NSButton *WsbsdTBMakeSwatchButton(NSColor *color, NSString *title, id target, SEL action) { WsbsdTBSwatchButton *b = [[WsbsdTBSwatchButton alloc] initWithFrame: NSMakeRect(0, 0, 64, 30)]; [b setBordered: NO]; [b setTitle: title ?: @""]; [b setTarget: target]; [b setAction: action]; b->swatchColor = color; return b; }
void WsbsdTBSetSwatch(NSView *v, NSColor *c) { if ([v isKindOfClass: [WsbsdTBSwatchButton class]]) { ((WsbsdTBSwatchButton *)v)->swatchColor = c; [v setNeedsDisplay: YES]; } }
@implementation WsbsdTBButton (Bezel) - (NSColor *)bezelColor { return objc_getAssociatedObject(self, "bezelColor"); } @end

/* a segmented control in the strip: separated dark segments */
@interface WsbsdTBSegmented : NSSegmentedControl @end
@implementation WsbsdTBSegmented
- (BOOL)isFlipped { return YES; }
- (void)drawRect:(NSRect)r
{
	NSInteger n = [self segmentCount]; if (n < 1) return; CGFloat w = floor(([self bounds].size.width - 4 * (n - 1)) / n), x = 0;
	for (NSInteger i = 0; i < n; i++) {
		NSRect b = NSMakeRect(x, 1.5, w, [self bounds].size.height - 3); BOOL en = [self isEnabled] && [self isEnabledForSegment: i], sel = [self selectedSegment] == i && [self trackingMode] != NSSegmentSwitchTrackingMomentary;
		[(sel ? [NSColor colorWithCalibratedWhite: 0.45 alpha: 1] : [NSColor colorWithCalibratedWhite: 0.22 alpha: 1]) setFill]; [[NSBezierPath bezierPathWithRoundedRect: b xRadius: 6 yRadius: 6] fill];
		NSColor *fg = en ? [NSColor whiteColor] : [NSColor grayColor]; NSImage *img = Tinted([self imageForSegment: i], fg); NSString *t = [self labelForSegment: i];
		if (img) { NSSize is = [img size]; NSRect ir = NSMakeRect(b.origin.x + floor((b.size.width - MIN(is.width, 20)) / 2), b.origin.y + floor((b.size.height - 20) / 2), MIN(is.width, 20), 20); [img drawInRect: ir fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1]; }
		else if ([t length]) { NSDictionary *at = @{ NSForegroundColorAttributeName: fg, NSFontAttributeName: [NSFont systemFontOfSize: 15] }; NSSize ts = [t sizeWithAttributes: at]; [t drawAtPoint: NSMakePoint(b.origin.x + floor((b.size.width - ts.width) / 2), b.origin.y + floor((b.size.height - ts.height) / 2)) withAttributes: at]; }
		x += w + 4;
	}
}
@end
/* the views of AppKit that applications put in the strip get the look of the strip */
static void Restyle(NSView *v)
{
	if (object_getClass(v) == [NSButton class]) { if ([(NSButton *)v image] && [[(NSButton *)v title] isEqual: @"Button"]) [(NSButton *)v setTitle: @""]; [(NSButton *)v setBordered: NO]; object_setClass(v, [WsbsdTBButton class]); NSSize sz = [v frame].size; NSButton *b = (NSButton *)v; CGFloat want = [[b title] length] ? MAX(sz.width, [[b title] sizeWithAttributes: @{ NSFontAttributeName: [NSFont systemFontOfSize: 15] }].width + 28) : 64; [v setFrameSize: NSMakeSize(MAX(want, 64), 30)]; }
	else if (object_getClass(v) == [NSSegmentedControl class]) { NSSegmentedControl *sc = (NSSegmentedControl *)v; object_setClass(v, [WsbsdTBSegmented class]); for (NSInteger i = 0; i < [sc segmentCount]; i++) [sc setWidth: 60 forSegment: i]; [v setFrameSize: NSMakeSize(60 * [sc segmentCount] + 4 * ([sc segmentCount] - 1), 30)]; }
	for (NSView *s in [v subviews]) Restyle(s);
}


/* the strip of views of a bar */
@interface WsbsdTBStrip : NSView { @public NSArray *entries; NSView *principal; } @end   /* entries: NSView, or NSNumber (fixed width) or NSNull (flexible) */
@implementation WsbsdTBStrip
- (BOOL)isFlipped { return YES; }
- (CGFloat)_width:(id)e { return [e isKindOfClass: [NSView class]] ? [e frame].size.width : [e isKindOfClass: [NSNumber class]] ? [e doubleValue] : 0; }
- (void)_place:(NSView *)v at:(CGFloat)x { CGFloat H = [self bounds].size.height, h = MIN([v frame].size.height, H); [v setFrame: NSMakeRect(x, floor((H - h) / 2), [v frame].size.width, h)]; if ([v superview] != self) [self addSubview: v]; }
/* a run of entries between x0 and x1: flexible spaces share what the fixed ones leave; the run is laid out from x0 */
- (void)_run:(NSArray *)run from:(CGFloat)x0 to:(CGFloat)x1
{
	CGFloat fixed = 0; NSUInteger flex = 0, n = [run count], i = 0; for (id e in run) { if ([e isKindOfClass: [NSNull class]]) flex++; else fixed += [self _width: e]; } fixed += 8 * (n ? n - 1 : 0);
	CGFloat free = MAX(0, (x1 - x0) - fixed), x = x0;
	for (id e in run) { CGFloat w = [e isKindOfClass: [NSNull class]] ? (flex ? free / flex : 0) : [self _width: e]; if ([e isKindOfClass: [NSView class]]) [self _place: e at: x]; x += w + (++i < n ? 8 : 0); }
}
- (void)layoutEntries
{
	CGFloat W = [self bounds].size.width; NSUInteger pi = principal ? [entries indexOfObjectIdenticalTo: principal] : NSNotFound;
	if (pi == NSNotFound) { [self _run: entries from: 0 to: W]; return; }
	CGFloat pw = [principal frame].size.width, px = MAX(0, floor((W - pw) / 2)); NSArray *left = [entries subarrayWithRange: NSMakeRange(0, pi)], *right = [entries subarrayWithRange: NSMakeRange(pi + 1, [entries count] - pi - 1)];
	[self _place: principal at: px]; [self _run: left from: 0 to: MAX(0, px - 8)];
	CGFloat rw = 8 * ([right count] ? [right count] - 1 : 0); for (id e in right) if (![e isKindOfClass: [NSNull class]]) rw += [self _width: e];
	[self _run: right from: MAX(px + pw + 8, W - rw) to: W];
}
- (void)resizeSubviewsWithOldSize:(NSSize)o { [self layoutEntries]; }
- (void)setFrame:(NSRect)f { [super setFrame: f]; [self layoutEntries]; }
@end
static void AddEntries(NSMutableArray *a, NSMutableSet *shown, NSArray *bars, NSUInteger level, NSSet *skip, CGFloat *w, NSView **principal)
{
	NSTouchBar *bar = bars[level];
	for (NSString *ident in [bar itemIdentifiers]) {
		if ([skip containsObject: ident]) continue;
		if ([ident isEqual: NSTouchBarItemIdentifierOtherItemsProxy]) { if (level + 1 < [bars count]) AddEntries(a, shown, bars, level + 1, skip, w, principal); continue; }
		if ([ident isEqual: NSTouchBarItemIdentifierFlexibleSpace]) { [a addObject: [NSNull null]]; continue; }
		if ([ident isEqual: NSTouchBarItemIdentifierFixedSpaceSmall]) { [a addObject: @8]; *w += 8; continue; }
		if ([ident isEqual: NSTouchBarItemIdentifierFixedSpaceLarge]) { [a addObject: @24]; *w += 24; continue; }
		if ([shown containsObject: ident]) continue;
		NSTouchBarItem *it = [bar itemForIdentifier: ident]; NSView *v = [it view];
		if (getenv("WSBSD_TBDUMP")) fprintf(stderr, "touchbar item %s -> %s %s\n", [ident UTF8String], v ? object_getClassName(v) : "nil", v ? [NSStringFromRect([v frame]) UTF8String] : "");
		if (!v) continue; Restyle(v);  [shown addObject: ident]; objc_setAssociatedObject(v, "prio", @([it visibilityPriority]), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		if (level == 0 && [ident isEqual: [bar principalItemIdentifier]]) *principal = v;
		[a addObject: v]; *w += [v frame].size.width;
	}
}
static NSArray *EntriesForBars(NSArray *bars, NSSet *skip, CGFloat *natural, NSView **principal)
{
	NSMutableArray *a = [NSMutableArray array]; CGFloat w = 0; AddEntries(a, [NSMutableSet set], bars, 0, skip, &w, principal);
	if (natural) *natural = w + 8 * ([a count] ? [a count] - 1 : 0); return a;
}
static NSArray *EntriesForBar(NSTouchBar *bar, NSSet *skip, CGFloat *natural) { NSView *p = nil; return EntriesForBars(@[ bar ], skip, natural, &p); }
/* what does not fit leaves, the lowest visibility priority first */
static NSArray *FitEntries(NSArray *entries, CGFloat width, NSView *principal)
{
	NSMutableArray *a = [entries mutableCopy];
	for (;;) {
		CGFloat w = 8 * ([a count] ? [a count] - 1 : 0); for (id e in a) w += [e isKindOfClass: [NSView class]] ? [e frame].size.width : [e isKindOfClass: [NSNumber class]] ? [e doubleValue] : 0;
		if (w <= width) break; NSInteger drop = -1; float low = 1e9; for (NSInteger i = (NSInteger)[a count] - 1; i >= 0; i--) { id e = a[i]; if (![e isKindOfClass: [NSView class]] || e == principal) continue; float p = [objc_getAssociatedObject(e, "prio") floatValue]; if (p < low) { low = p; drop = i; } }
		if (drop < 0) break; [(NSView *)a[drop] removeFromSuperview]; [a removeObjectAtIndex: drop];
	}
	return a;
}
static NSView *StripForBars(NSArray *bars, CGFloat width, NSSet *skip)
{
	CGFloat nat; NSView *principal = nil; NSArray *e = EntriesForBars(bars, skip, &nat, &principal); if (width > 0) e = FitEntries(e, width, principal);
	WsbsdTBStrip *s = [[WsbsdTBStrip alloc] initWithFrame: NSMakeRect(0, 0, width > 0 ? width : nat, 30)]; s->entries = e; s->principal = principal; [s layoutEntries]; return s;
}
static NSView *StripForBar(NSTouchBar *bar, CGFloat width, NSSet *skip) { return StripForBars(@[ bar ], width, skip); }

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
/* the system controls behind the control strip: volume and mute through mixer(8), brightness through backlight(8); the values are kept when the commands do not exist (no sound card, no panel) */
@interface WsbsdSysControls : NSObject
+ (double)volume; + (void)setVolume:(double)v; + (BOOL)muted; + (void)setMuted:(BOOL)m; + (double)brightness; + (void)setBrightness:(double)b;
@end
static NSString *RunTool(NSString *path, NSArray *args)
{
	if (![[NSFileManager defaultManager] isExecutableFileAtPath: path]) return nil;
	NSTask *t = [[NSTask alloc] init]; [t setLaunchPath: path]; [t setArguments: args]; NSPipe *p = [NSPipe pipe]; [t setStandardOutput: p]; [t setStandardError: [NSPipe pipe]];
	@try { [t launch]; } @catch (id e) { return nil; } NSData *d = [[p fileHandleForReading] readDataToEndOfFile]; [t waitUntilExit]; return [[NSString alloc] initWithData: d encoding: NSUTF8StringEncoding];
}
static double gVol = 0.5, gBri = 0.7; static BOOL gMute;
@implementation WsbsdSysControls
+ (double)volume { NSString *o = RunTool(@"/usr/sbin/mixer", @[ @"-s", @"vol" ]); if (!o) o = RunTool(@"/usr/sbin/mixer", @[ @"vol" ]); NSRange r = [o rangeOfString: @"="]; if (r.location != NSNotFound) { double v = [[o substringFromIndex: NSMaxRange(r)] doubleValue]; if (v > 1) v /= 100; gVol = v; } return gVol; }
+ (void)setVolume:(double)v { gVol = MAX(0, MIN(1, v)); RunTool(@"/usr/sbin/mixer", @[ [NSString stringWithFormat: @"vol=%.2f", gVol] ]); }
+ (BOOL)muted { return gMute; }
+ (void)setMuted:(BOOL)m { gMute = m; RunTool(@"/usr/sbin/mixer", @[ m ? @"vol.mute=1" : @"vol.mute=0" ]); }
+ (double)brightness { NSString *o = RunTool(@"/usr/bin/backlight", @[]); if ([o length]) { double v = [o doubleValue]; if (v > 0) gBri = v / 100; } return gBri; }
+ (void)setBrightness:(double)b { gBri = MAX(0.05, MIN(1, b)); RunTool(@"/usr/bin/backlight", @[ [NSString stringWithFormat: @"%d", (int)(gBri * 100)] ]); }
@end

@interface WsbsdTBControlStrip : NSView @end
@implementation WsbsdTBControlStrip
- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstMouse:(NSEvent *)e { return YES; }
static void Speaker(CGFloat x, CGFloat cy) { NSBezierPath *sp = [NSBezierPath bezierPath]; [sp moveToPoint: NSMakePoint(x - 9, cy - 3)]; [sp lineToPoint: NSMakePoint(x - 5, cy - 3)]; [sp lineToPoint: NSMakePoint(x + 1, cy - 8)]; [sp lineToPoint: NSMakePoint(x + 1, cy + 8)]; [sp lineToPoint: NSMakePoint(x - 5, cy + 3)]; [sp lineToPoint: NSMakePoint(x - 9, cy + 3)]; [sp closePath]; [sp fill]; }
- (void)drawRect:(NSRect)r
{
	NSColor *w = [NSColor colorWithCalibratedWhite: 0.9 alpha: 1]; [w setStroke]; [w setFill]; CGFloat cy = [self bounds].size.height / 2, x = 24;
	NSBezierPath *p = [NSBezierPath bezierPathWithOvalInRect: NSMakeRect(x - 4, cy - 4, 8, 8)]; [p setLineWidth: 1.5]; [p stroke];
	for (int i = 0; i < 8; i++) { double a = i * M_PI / 4; NSBezierPath *l = [NSBezierPath bezierPath]; [l moveToPoint: NSMakePoint(x + cos(a) * 7, cy + sin(a) * 7)]; [l lineToPoint: NSMakePoint(x + cos(a) * 10, cy + sin(a) * 10)]; [l setLineWidth: 1.5]; [l stroke]; }
	x = 78; Speaker(x, cy); for (int i = 1; i <= 2; i++) { NSBezierPath *a = [NSBezierPath bezierPath]; [a appendBezierPathWithArcWithCenter: NSMakePoint(x + 2, cy) radius: 4 + i * 4 startAngle: -40 endAngle: 40]; [a setLineWidth: 1.5]; [a stroke]; }
	x = 132; Speaker(x, cy); if ([WsbsdSysControls muted]) { NSBezierPath *c = [NSBezierPath bezierPath]; [c moveToPoint: NSMakePoint(x + 5, cy - 5)]; [c lineToPoint: NSMakePoint(x + 14, cy + 5)]; [c setLineWidth: 1.5]; [c stroke]; }
	x = 172; NSBezierPath *o = [NSBezierPath bezierPathWithOvalInRect: NSMakeRect(x - 9, cy - 9, 18, 18)]; [o setLineWidth: 2]; [[NSColor colorWithCalibratedRed: 0.55 green: 0.45 blue: 1 alpha: 1] setStroke]; [o stroke];
}
- (void)mouseDown:(NSEvent *)e
{
	CGFloat x = [self convertPoint: [e locationInWindow] fromView: nil].x; WsbsdTouchBarHost *h = [WsbsdTouchBarHost sharedHost];
	if (x < 50) [h showSystemSlider: 0]; else if (x < 105) [h showSystemSlider: 1]; else if (x < 152) { [WsbsdSysControls setMuted: ![WsbsdSysControls muted]]; [self setNeedsDisplay: YES]; } else { if (getenv("WSBSD_TBDUMP")) fprintf(stderr, "control strip: Siri\n"); }
}
@end
@implementation NSApplication (WsbsdTouchBar)
- (void)toggleTouchBarCustomizationPalette:(id)sender { WsbsdTouchBarHost *h = [WsbsdTouchBarHost sharedHost]; if ([self isTouchBarCustomizationPaletteVisible]) { [WsbsdTouchBarHost _dismissBar: St(self_palette())[@"p"]]; St(self_palette())[@"p"] = nil; [St(self_palette()) removeObjectForKey: @"p"]; return; } NSTouchBar *b = [h currentTouchBar]; if ([[b customizationIdentifier] length]) [h _showPalette: b]; }
- (BOOL)isTouchBarCustomizationPaletteVisible { NSTouchBar *p = St(self_palette())[@"p"]; return p && [p isVisible]; }
@end
static NSMutableArray *TrayItems(void) { static NSMutableArray *a; if (!a) a = [NSMutableArray array]; return a; }
@implementation NSTouchBarItem (WsbsdSystemTray)
+ (void)addSystemTrayItem:(NSTouchBarItem *)item { if (item && ![TrayItems() containsObject: item]) { [TrayItems() addObject: item]; [[WsbsdTouchBarHost sharedHost] update]; } }
+ (void)removeSystemTrayItem:(NSTouchBarItem *)item { [TrayItems() removeObject: item]; [[WsbsdTouchBarHost sharedHost] update]; }
@end
@implementation NSTouchBar (WsbsdSystemModal)
+ (void)presentSystemModalTouchBar:(NSTouchBar *)b placement:(long long)p systemTrayItemIdentifier:(NSTouchBarItemIdentifier)i { [WsbsdTouchBarHost _presentBar: b closeButton: NO]; }
+ (void)presentSystemModalTouchBar:(NSTouchBar *)b systemTrayItemIdentifier:(NSTouchBarItemIdentifier)i { [WsbsdTouchBarHost _presentBar: b closeButton: NO]; }
+ (void)dismissSystemModalTouchBar:(NSTouchBar *)b { [WsbsdTouchBarHost _dismissBar: b]; }
+ (void)minimizeSystemModalTouchBar:(NSTouchBar *)b { [WsbsdTouchBarHost _dismissBar: b]; }
@end
/* ---- the host: the bar of the key window in a panel at the bottom of the screen ---- */
@implementation WsbsdTouchBarHost { NSTouchBar *_bar; NSPanel *_panel; NSView *_content; NSString *_signature; NSMutableArray *_overrides; NSMutableDictionary *_closeFlags; }
@synthesize currentTouchBar = _bar, panel = _panel;
+ (instancetype)sharedHost { static WsbsdTouchBarHost *h; static dispatch_once_t once; dispatch_once(&once, ^{ RegisterGlyphs(); h = [WsbsdTouchBarHost new]; h->_overrides = [NSMutableArray array]; h->_closeFlags = [NSMutableDictionary dictionary]; }); return h; }
+ (void)_presentBar:(NSTouchBar *)bar closeButton:(BOOL)close { WsbsdTouchBarHost *h = [self sharedHost]; if (!bar) return; [h->_overrides removeObjectIdenticalTo: bar]; [h->_overrides addObject: bar]; h->_closeFlags[[NSValue valueWithNonretainedObject: bar]] = @(close); [h update]; }
+ (void)_dismissBar:(NSTouchBar *)bar { WsbsdTouchBarHost *h = [self sharedHost]; if (bar) [h->_overrides removeObjectIdenticalTo: bar]; [h update]; }
/* the bars of the responder chain from the first responder up: the first is shown, the others fill the "other items" proxy */
static NSArray *BarChain(NSResponder *r)
{
	NSMutableArray *a = [NSMutableArray array];
	for (; r; r = [r nextResponder]) { NSTouchBar *b = [r touchBar]; if (!b) { b = [r makeTouchBar]; if (b) [r setTouchBar: b]; } if (b && ![a containsObject: b]) [a addObject: b]; }
	return a;
}
- (NSArray *)_chain
{
	if ([_overrides count]) return @[ [_overrides lastObject] ];
	if (![NSApp isActive]) return @[]; NSWindow *w = [NSApp keyWindow]; if (w == _panel) w = [NSApp mainWindow]; if (!w) return @[];
	NSMutableArray *a = [BarChain([w firstResponder] ?: w) mutableCopy]; NSTouchBar *wb = [w touchBar]; if (wb && ![a containsObject: wb]) [a addObject: wb]; NSTouchBar *ab = [NSApp touchBar]; if (ab && ![a containsObject: ab]) [a addObject: ab];
	return a;
}
- (void)_ensurePanel
{
	if (_panel) return; NSRect sf = [[NSScreen mainScreen] frame];
	_panel = [[NSPanel alloc] initWithContentRect: NSMakeRect(NSMidX(sf) - 560, 40, 1120, 46) styleMask: NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel backing: NSBackingStoreBuffered defer: NO];
	[_panel setLevel: NSStatusWindowLevel]; [_panel setBecomesKeyOnlyIfNeeded: YES]; [_panel setHidesOnDeactivate: NO]; [_panel setBackgroundColor: [NSColor clearColor]]; [_panel setOpaque: NO]; [_panel setHasShadow: NO]; [_panel setTitle: @"Touch Bar"]; [_panel setReleasedWhenClosed: NO];
}
- (void)_sysSlide:(NSSlider *)sl { double v = [sl doubleValue]; if ([sl tag] == 0) [WsbsdSysControls setBrightness: v]; else { [WsbsdSysControls setVolume: v]; if (gMute && v > 0) [WsbsdSysControls setMuted: NO]; } }
/* tapping brightness or volume in the control strip opens a bar with a slider (the expanded control strip) */
- (void)showSystemSlider:(int)which
{
	NSTouchBar *bar = [NSTouchBar new]; NSSliderTouchBarItem *it = [[NSSliderTouchBarItem alloc] initWithIdentifier: which ? @"com.apple.system.volume" : @"com.apple.system.brightness"]; NSSlider *sl = [it slider]; [sl setMinValue: 0]; [sl setMaxValue: 1]; [sl setTag: which]; [sl setFrameSize: NSMakeSize(420, 30)]; [it setDoubleValue: which ? [WsbsdSysControls volume] : [WsbsdSysControls brightness]]; [sl setTarget: self]; [sl setAction: @selector(_sysSlide:)]; [sl setContinuous: YES];
	[bar setTemplateItems: [NSSet setWithObject: it]]; [bar setDefaultItemIdentifiers: @[ NSTouchBarItemIdentifierFlexibleSpace, [it identifier], NSTouchBarItemIdentifierFlexibleSpace ]]; [WsbsdTouchBarHost _presentBar: bar closeButton: YES];
}
/* the customization palette: every allowed item as a switch, the items in the bar highlighted; Done leaves, Default restores */
- (void)_toggleItem:(NSButton *)b { NSTouchBar *bar = objc_getAssociatedObject(b, "palBar"); NSString *ident = objc_getAssociatedObject(b, "palId"); NSMutableArray *cur = [[bar itemIdentifiers] mutableCopy]; if ([cur containsObject: ident]) { if (![[bar customizationRequiredItemIdentifiers] containsObject: ident]) [cur removeObject: ident]; } else [cur addObject: ident]; [bar _wsSaveItems: cur]; [self _showPalette: bar]; }
- (void)_resetItems:(NSButton *)b { NSTouchBar *bar = objc_getAssociatedObject(b, "palBar"); [bar _wsSaveItems: nil]; [self _showPalette: bar]; }
- (void)_showPalette:(NSTouchBar *)target
{
	NSTouchBar *pal = [NSTouchBar new]; NSMutableSet *items = [NSMutableSet set]; NSMutableArray *ids = [NSMutableArray array]; NSArray *cur = [target itemIdentifiers];
	for (NSString *ident in [target customizationAllowedItemIdentifiers]) {
		if ([ident hasPrefix: @"NSTouchBarItemIdentifier"]) continue; NSTouchBarItem *it = [target itemForIdentifier: ident]; NSString *label = [it customizationLabel] ?: ident;
		NSButtonTouchBarItem *b = [NSButtonTouchBarItem buttonTouchBarItemWithIdentifier: [@"pal." stringByAppendingString: ident] title: label target: self action: @selector(_toggleItem:)]; WsbsdTBButton *v = (WsbsdTBButton *)[b view]; objc_setAssociatedObject(v, "palBar", target, OBJC_ASSOCIATION_ASSIGN); objc_setAssociatedObject(v, "palId", ident, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		[b setBezelColor: [cur containsObject: ident] ? [NSColor colorWithCalibratedRed: 0.1 green: 0.45 blue: 1 alpha: 1] : nil]; [items addObject: b]; [ids addObject: [b identifier]];
	}
	NSButtonTouchBarItem *rs = [NSButtonTouchBarItem buttonTouchBarItemWithIdentifier: @"pal.default" title: @"Default" target: self action: @selector(_resetItems:)]; objc_setAssociatedObject([rs view], "palBar", target, OBJC_ASSOCIATION_ASSIGN); [items addObject: rs]; [ids addObject: NSTouchBarItemIdentifierFlexibleSpace]; [ids addObject: @"pal.default"];
	[pal setTemplateItems: items]; [pal setDefaultItemIdentifiers: ids]; if (St(self_palette())[@"p"]) [WsbsdTouchBarHost _dismissBar: St(self_palette())[@"p"]]; St(self_palette())[@"p"] = pal; [WsbsdTouchBarHost _presentBar: pal closeButton: YES];
}
- (void)invalidate { _signature = nil; }
- (void)_escape:(id)sender { [NSApp sendAction: @selector(cancelOperation:) to: nil from: sender]; }
- (void)_close:(id)sender { [_overrides removeLastObject]; [self update]; }
- (void)update
{
	NSArray *chain = [self _chain]; NSTouchBar *b = [chain firstObject];
	if (!b) { if (_panel && [_panel isVisible]) [_panel orderOut: nil]; [_bar _wsSetVisible: NO]; _bar = nil; _signature = nil; return; }
	BOOL isOverride = [_overrides count] > 0, closeBtn = isOverride && [_closeFlags[[NSValue valueWithNonretainedObject: b]] boolValue];
	NSString *esc = isOverride ? nil : [b escapeKeyReplacementItemIdentifier]; NSMutableString *sig = [NSMutableString stringWithFormat: @"%d|%d", isOverride, closeBtn];
	for (NSTouchBarItem *t in TrayItems()) [sig appendFormat: @"|tray:%p", t]; for (NSTouchBar *c in chain) [sig appendFormat: @"|%p:%@:%@", c, [[c itemIdentifiers] componentsJoinedByString: @","], [c escapeKeyReplacementItemIdentifier] ?: @""];
	[self _ensurePanel];
	if (b != _bar || ![sig isEqual: _signature]) {
		[_bar _wsSetVisible: NO]; _bar = b; _signature = sig; [_content removeFromSuperview];
		NSView *root = [[WsbsdTBBackground alloc] initWithFrame: NSMakeRect(0, 0, 1120, 46)]; NSTouchBarItem *e = esc ? [b itemForIdentifier: esc] : nil; CGFloat x = 17, csw = 190;
		NSView *ev = [e view]; if (ev) Restyle(ev);
		if (!ev) { NSButtonTouchBarItem *eb = closeBtn ? [NSButtonTouchBarItem buttonTouchBarItemWithIdentifier: @"close" title: @"x" target: self action: @selector(_close:)] : [NSButtonTouchBarItem buttonTouchBarItemWithIdentifier: @"esc" title: @"esc" target: self action: @selector(_escape:)]; ev = [eb view]; [ev setFrameSize: NSMakeSize(64, 30)]; objc_setAssociatedObject(root, "escItem", eb, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
		[ev setFrameOrigin: NSMakePoint(x, 8)]; [root addSubview: ev]; x += [ev frame].size.width + 17;
		CGFloat trayW = 0; NSMutableArray *trayViews = [NSMutableArray array]; for (NSTouchBarItem *t in TrayItems()) { NSView *tv = [t view]; if (!tv) continue; Restyle(tv); [trayViews addObject: tv]; trayW += [tv frame].size.width + 8; }
		CGFloat tx = 1120 - 17 - csw - trayW; for (NSView *tv in trayViews) { [tv setFrameOrigin: NSMakePoint(tx, 8)]; [root addSubview: tv]; tx += [tv frame].size.width + 8; }
		NSView *strip = StripForBars(chain, 1120 - 17 - csw - trayW - 17 - x, esc ? [NSSet setWithObject: esc] : nil); [strip setFrameOrigin: NSMakePoint(x, 8)]; [root addSubview: strip];
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
