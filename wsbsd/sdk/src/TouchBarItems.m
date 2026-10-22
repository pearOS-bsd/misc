/* NSScrubber and the remaining Touch Bar items: picker, popover, stepper, color picker, sharing picker, candidate list. See include/wsbsd/TouchBar.h. */
#import <wsbsd/TouchBar.h>
#import <objc/runtime.h>

extern void WsbsdTBSetSwatch(NSView *v, NSColor *c); extern NSButton *WsbsdTBMakeSwatchButton(NSColor *color, NSString *title, id target, SEL action);
static const char kState;
static NSMutableDictionary *St(id o) { NSMutableDictionary *d = objc_getAssociatedObject(o, &kState); if (!d) { d = [NSMutableDictionary dictionary]; objc_setAssociatedObject(o, &kState, d, OBJC_ASSOCIATION_RETAIN_NONATOMIC); } return d; }

/* ================= scrubber ================= */
/* GNUstep declares NSScrubber, NSScrubberLayout, NSScrubberLayoutAttributes, NSScrubberArrangedView and NSScrubberItemView as empty classes: their behaviour is added as categories (state in St()); the other classes are new */
@implementation NSScrubberLayoutAttributes (WsbsdTouchBar)
+ (instancetype)layoutAttributesForItemAtIndex:(NSInteger)i { NSScrubberLayoutAttributes *a = [[self alloc] init]; a.itemIndex = i; a.alpha = 1; return a; }
- (NSInteger)itemIndex { return [St(self)[@"i"] integerValue]; } - (void)setItemIndex:(NSInteger)i { St(self)[@"i"] = @(i); }
- (NSRect)frame { return [St(self)[@"f"] rectValue]; } - (void)setFrame:(NSRect)f { St(self)[@"f"] = [NSValue valueWithRect: f]; }
- (CGFloat)alpha { NSNumber *n = St(self)[@"a"]; return n ? [n doubleValue] : 1; } - (void)setAlpha:(CGFloat)a { St(self)[@"a"] = @(a); }
- (id)copyWithZone:(NSZone *)z { NSScrubberLayoutAttributes *a = [[[self class] allocWithZone: z] init]; a.itemIndex = self.itemIndex; a.frame = self.frame; a.alpha = self.alpha; return a; }
@end
@implementation NSScrubberLayout (WsbsdTouchBar)
+ (Class)layoutAttributesClass { return [NSScrubberLayoutAttributes class]; }
- (NSScrubber *)scrubber { return [St(self)[@"scr"] nonretainedObjectValue]; } - (void)setScrubber:(NSScrubber *)s { St(self)[@"scr"] = [NSValue valueWithNonretainedObject: s]; }
- (NSSize)scrubberContentSize { return NSZeroSize; } - (NSRect)visibleRect { NSScrubber *s = [self scrubber]; return s ? [s bounds] : NSZeroRect; } - (BOOL)automaticallyMirrorsInRightToLeftLayout { return YES; }
- (void)invalidateLayout { [[self scrubber] reloadData]; } - (void)prepareLayout {}
- (NSScrubberLayoutAttributes *)layoutAttributesForItemAtIndex:(NSInteger)i { return nil; }
- (NSSet *)layoutAttributesForItemsInRect:(NSRect)r { NSMutableSet *out = [NSMutableSet set]; NSInteger n = [[self scrubber] numberOfItems]; for (NSInteger i = 0; i < n; i++) { NSScrubberLayoutAttributes *a = [self layoutAttributesForItemAtIndex: i]; if (a && NSIntersectsRect(a.frame, r)) [out addObject: a]; } return out; }
- (BOOL)shouldInvalidateLayoutForSelectionChange { return NO; } - (BOOL)shouldInvalidateLayoutForHighlightChange { return NO; } - (BOOL)shouldInvalidateLayoutForChangeFromVisibleRect:(NSRect)a toVisibleRect:(NSRect)b { return NO; }
@end
@implementation NSScrubberFlowLayout
- (instancetype)init { if ((self = [super init])) { _itemSpacing = 8; _itemSize = NSMakeSize(50, 30); } return self; }
- (NSSize)scrubberContentSize { NSInteger n = [[self scrubber] numberOfItems]; return NSMakeSize(n ? n * _itemSize.width + (n - 1) * _itemSpacing : 0, _itemSize.height); }
- (NSScrubberLayoutAttributes *)layoutAttributesForItemAtIndex:(NSInteger)i { NSScrubberLayoutAttributes *a = [NSScrubberLayoutAttributes layoutAttributesForItemAtIndex: i]; a.frame = NSMakeRect(i * (_itemSize.width + _itemSpacing), 0, _itemSize.width, _itemSize.height); return a; }
- (void)invalidateLayoutForItemsAtIndexes:(NSIndexSet *)ix { [[self scrubber] reloadData]; }
@end
@implementation NSScrubberProportionalLayout
- (instancetype)init { return [self initWithNumberOfVisibleItems: 5]; }
- (instancetype)initWithNumberOfVisibleItems:(NSInteger)n { if ((self = [super init])) _numberOfVisibleItems = MAX(1, n); return self; }
- (NSSize)scrubberContentSize { NSInteger n = [[self scrubber] numberOfItems]; CGFloat w = [[self scrubber] bounds].size.width / _numberOfVisibleItems; return NSMakeSize(w * n, [[self scrubber] bounds].size.height); }
- (NSScrubberLayoutAttributes *)layoutAttributesForItemAtIndex:(NSInteger)i { CGFloat w = [[self scrubber] bounds].size.width / _numberOfVisibleItems; NSScrubberLayoutAttributes *a = [NSScrubberLayoutAttributes layoutAttributesForItemAtIndex: i]; a.frame = NSMakeRect(i * w, 0, w, [[self scrubber] bounds].size.height); return a; }
@end

@interface WsbsdSelStyle : NSScrubberSelectionStyle { @public int kind; } @end
@interface WsbsdSelView : NSView { @public int kind; } @end
@implementation WsbsdSelView
- (BOOL)isFlipped { return YES; }
- (void)drawRect:(NSRect)r { NSRect b = NSInsetRect([self bounds], 1, 1); if (kind == 1) { [[NSColor colorWithCalibratedWhite: 0.5 alpha: 0.9] setFill]; [[NSBezierPath bezierPathWithRoundedRect: b xRadius: 6 yRadius: 6] fill]; } else { NSBezierPath *p = [NSBezierPath bezierPathWithRoundedRect: b xRadius: 6 yRadius: 6]; [p setLineWidth: 2]; [[NSColor colorWithCalibratedRed: 0.1 green: 0.5 blue: 1 alpha: 1] setStroke]; [p stroke]; } }
@end
@implementation NSScrubberSelectionStyle
+ (NSScrubberSelectionStyle *)outlineOverlayStyle { WsbsdSelStyle *s = [WsbsdSelStyle new]; s->kind = 0; return s; }
+ (NSScrubberSelectionStyle *)roundedBackgroundStyle { WsbsdSelStyle *s = [WsbsdSelStyle new]; s->kind = 1; return s; }
- (NSScrubberSelectionStyle *)init { return [super init]; }
- (NSView *)makeSelectionView { return nil; }
@end
@implementation WsbsdSelStyle
- (NSView *)makeSelectionView { WsbsdSelView *v = [[WsbsdSelView alloc] initWithFrame: NSMakeRect(0, 0, 10, 10)]; v->kind = kind; return v; }
@end

@implementation NSScrubberArrangedView (WsbsdTouchBar)
- (BOOL)isFlipped { return YES; }
- (void)applyLayoutAttributes:(NSScrubberLayoutAttributes *)la { [self setFrame: la.frame]; [self setAlphaValue: la.alpha]; }
- (BOOL)isSelected { return [St(self)[@"sel"] boolValue]; } - (void)setSelected:(BOOL)b { St(self)[@"sel"] = @(b); [self setNeedsDisplay: YES]; }
- (BOOL)isHighlighted { return [St(self)[@"hi"] boolValue]; } - (void)setHighlighted:(BOOL)b { St(self)[@"hi"] = @(b); [self setNeedsDisplay: YES]; }
@end
@implementation NSScrubberTextItemView
- (instancetype)initWithFrame:(NSRect)f { if ((self = [super initWithFrame: f])) { NSTextField *t = [NSTextField labelWithString: @""]; [t setAlignment: NSTextAlignmentCenter]; [t setTextColor: [NSColor whiteColor]]; [t setFont: [NSFont systemFontOfSize: 15]]; _textField = t; [self addSubview: t]; } return self; }
- (NSString *)title { return [_textField stringValue]; } - (void)setTitle:(NSString *)t { [_textField setStringValue: t ?: @""]; [self _layoutText]; }
- (void)_layoutText { [_textField sizeToFit]; NSSize s = [_textField frame].size, b = [self bounds].size; [_textField setFrame: NSMakeRect(floor((b.width - MIN(s.width, b.width)) / 2), floor((b.height - s.height) / 2), MIN(s.width, b.width), s.height)]; }
- (void)setFrame:(NSRect)f { [super setFrame: f]; [self _layoutText]; }
@end
@implementation NSScrubberImageItemView
- (instancetype)initWithFrame:(NSRect)f { if ((self = [super initWithFrame: f])) { _imageView = [[NSImageView alloc] initWithFrame: NSMakeRect(0, 0, f.size.width, f.size.height)]; [self addSubview: _imageView]; } return self; }
- (NSImage *)image { return [_imageView image]; } - (void)setImage:(NSImage *)i { [_imageView setImage: i]; }
- (NSImageAlignment)imageAlignment { return [_imageView imageAlignment]; } - (void)setImageAlignment:(NSImageAlignment)a { [_imageView setImageAlignment: a]; }
- (void)setFrame:(NSRect)f { [super setFrame: f]; [_imageView setFrame: NSMakeRect(0, 0, f.size.width, f.size.height)]; }
@end

#define SS(key) St(self)[@key]
@implementation NSScrubber (WsbsdTouchBar)
- (NSMutableDictionary *)_classes { NSMutableDictionary *d = SS("classes"); if (!d) d = St(self)[@"classes"] = [NSMutableDictionary dictionary]; return d; }
- (NSMutableArray *)_items { NSMutableArray *d = SS("items"); if (!d) d = St(self)[@"items"] = [NSMutableArray array]; return d; }
- (NSView *)_doc { NSView *d = SS("doc"); if (!d) { d = [[NSView alloc] initWithFrame: [self bounds]]; St(self)[@"doc"] = d; [self addSubview: d]; } return d; }
- (CGFloat)_offset { return [SS("off") doubleValue]; }
- (id<NSScrubberDataSource>)dataSource { return [SS("ds") nonretainedObjectValue]; } - (void)setDataSource:(id<NSScrubberDataSource>)d { St(self)[@"ds"] = [NSValue valueWithNonretainedObject: d]; [self reloadData]; }
- (id<NSScrubberDelegate>)delegate { return [SS("dg") nonretainedObjectValue]; } - (void)setDelegate:(id<NSScrubberDelegate>)d { St(self)[@"dg"] = [NSValue valueWithNonretainedObject: d]; }
- (NSScrubberLayout *)scrubberLayout { NSScrubberLayout *l = SS("layout"); if (!l) { l = [NSScrubberFlowLayout new]; [l setScrubber: self]; St(self)[@"layout"] = l; } return l; }
- (void)setScrubberLayout:(NSScrubberLayout *)l { [[self scrubberLayout] setScrubber: nil]; St(self)[@"layout"] = l; [l setScrubber: self]; [self reloadData]; }
- (NSScrubberMode)mode { return (NSScrubberMode)[SS("mode") integerValue]; } - (void)setMode:(NSScrubberMode)m { St(self)[@"mode"] = @(m); }
- (BOOL)isContinuous { return [SS("cont") boolValue]; } - (void)setContinuous:(BOOL)b { St(self)[@"cont"] = @(b); }
- (BOOL)floatsSelectionViews { return [SS("float") boolValue]; } - (void)setFloatsSelectionViews:(BOOL)b { St(self)[@"float"] = @(b); }
- (NSInteger)selectedIndex { NSNumber *n = SS("sel"); return n ? [n integerValue] : -1; } - (void)setSelectedIndex:(NSInteger)i { St(self)[@"sel"] = @(i); [self _applySelection]; }
- (NSInteger)highlightedIndex { NSNumber *n = SS("hl"); return n ? [n integerValue] : -1; } - (void)setHighlightedIndex:(NSInteger)i { St(self)[@"hl"] = @(i); [self _applySelection]; }
- (NSScrubberSelectionStyle *)selectionBackgroundStyle { return SS("bgstyle"); } - (void)setSelectionBackgroundStyle:(NSScrubberSelectionStyle *)s { St(self)[@"bgstyle"] = s ?: [NSNull null]; [self _applySelection]; }
- (NSScrubberSelectionStyle *)selectionOverlayStyle { return SS("ovstyle"); } - (void)setSelectionOverlayStyle:(NSScrubberSelectionStyle *)s { St(self)[@"ovstyle"] = s ?: [NSNull null]; [self _applySelection]; }
- (NSScrubberAlignment)itemAlignment { return (NSScrubberAlignment)[SS("align") integerValue]; } - (void)setItemAlignment:(NSScrubberAlignment)a { St(self)[@"align"] = @(a); [self reloadData]; }
- (BOOL)showsArrowButtons { return [SS("arrows") boolValue]; } - (void)setShowsArrowButtons:(BOOL)b { St(self)[@"arrows"] = @(b); }
- (BOOL)showsAdditionalContentIndicators { return [SS("more") boolValue]; } - (void)setShowsAdditionalContentIndicators:(BOOL)b { St(self)[@"more"] = @(b); }
- (NSColor *)backgroundColor { return SS("bg"); } - (void)setBackgroundColor:(NSColor *)c { St(self)[@"bg"] = c ?: [NSNull null]; [self setNeedsDisplay: YES]; }
- (NSView *)backgroundView { return SS("bgview"); } - (void)setBackgroundView:(NSView *)v { [(NSView *)SS("bgview") removeFromSuperview]; St(self)[@"bgview"] = v ?: [NSNull null]; if (v) { [v setFrame: [self bounds]]; [self addSubview: v positioned: NSWindowBelow relativeTo: nil]; } }
- (BOOL)isFlipped { return YES; }
- (NSInteger)numberOfItems { id<NSScrubberDataSource> d = [self dataSource]; return [d respondsToSelector: @selector(numberOfItemsForScrubber:)] ? [d numberOfItemsForScrubber: self] : 0; }
- (void)registerClass:(Class)c forItemIdentifier:(NSScrubberItemIdentifier)i { if (c) { [self _classes][i] = c; (void)[[c alloc] initWithFrame: NSMakeRect(0, 0, 1, 1)]; /* the runtime initializes the class here, not inside the data source callback (it recursed there) */ } else [[self _classes] removeObjectForKey: i]; }
- (NSScrubberItemView *)makeItemWithIdentifier:(NSScrubberItemIdentifier)i owner:(id)o { Class c = [self _classes][i]; if (getenv("WSBSD_TBDUMP")) fprintf(stderr, "makeItem %s class=%p %s\n", [i UTF8String], c, c ? class_getName(c) : "-"); return c ? [[c alloc] initWithFrame: NSMakeRect(0, 0, 50, 30)] : nil; }
- (NSScrubberItemView *)itemViewForItemAtIndex:(NSInteger)i { NSArray *it = [self _items]; return i >= 0 && i < (NSInteger)[it count] ? it[i] : nil; }
- (void)reloadData
{
	NSMutableArray *items = [self _items]; for (NSView *v in items) [v removeFromSuperview]; [items removeAllObjects]; [(NSView *)SS("selview") removeFromSuperview]; [St(self) removeObjectForKey: @"selview"];
	id<NSScrubberDataSource> ds = [self dataSource]; if (!ds) return; NSInteger n = [self numberOfItems]; NSScrubberLayout *layout = [self scrubberLayout]; [layout prepareLayout]; NSView *doc = [self _doc];
	for (NSInteger i = 0; i < n; i++) { NSScrubberItemView *v = [ds scrubber: self viewForItemAtIndex: i]; if (!v) v = [[NSScrubberItemView alloc] initWithFrame: NSZeroRect]; NSScrubberLayoutAttributes *a = [layout layoutAttributesForItemAtIndex: i]; if (a) [v applyLayoutAttributes: a]; [doc addSubview: v]; [items addObject: v]; }
	NSSize cs = [layout scrubberContentSize]; CGFloat H = [self bounds].size.height; [doc setFrame: NSMakeRect(0, 0, MAX(cs.width, [self bounds].size.width), H)];
	for (NSView *v in items) { NSRect f = [v frame]; f.origin.y = floor((H - f.size.height) / 2); [v setFrame: f]; }
	if ([self itemAlignment] == NSScrubberAlignmentCenter && cs.width < [self bounds].size.width) { CGFloat dx = floor(([self bounds].size.width - cs.width) / 2); for (NSView *v in items) { NSRect f = [v frame]; f.origin.x += dx; [v setFrame: f]; } }
	[self _clampOffset]; [self _applySelection]; [self setNeedsDisplay: YES];
}
- (void)_clampOffset { NSView *doc = [self _doc]; CGFloat max = MAX(0, [doc frame].size.width - [self bounds].size.width), o = MAX(0, MIN([self _offset], max)); St(self)[@"off"] = @(o); [doc setFrameOrigin: NSMakePoint(-o, 0)]; }
- (void)_applySelection
{
	[(NSView *)SS("selview") removeFromSuperview]; [St(self) removeObjectForKey: @"selview"]; NSArray *items = [self _items]; NSInteger sel = [self selectedIndex], hl = [self highlightedIndex];
	for (NSInteger i = 0; i < (NSInteger)[items count]; i++) { [items[i] setSelected: i == sel]; [items[i] setHighlighted: i == hl]; }
	NSScrubberSelectionStyle *bg = [self selectionBackgroundStyle], *ov = [self selectionOverlayStyle]; if ((id)bg == [NSNull null]) bg = nil; if ((id)ov == [NSNull null]) ov = nil; NSScrubberSelectionStyle *st = bg ?: ov;
	if (st && sel >= 0 && sel < (NSInteger)[items count]) { NSView *v = [st makeSelectionView]; if (v) { NSView *it = items[sel]; [v setFrame: [it frame]]; [[self _doc] addSubview: v positioned: bg ? NSWindowBelow : NSWindowAbove relativeTo: it]; St(self)[@"selview"] = v; } }
}
- (NSRange)visibleRange { NSArray *items = [self _items]; NSInteger first = -1, last = -1; for (NSInteger i = 0; i < (NSInteger)[items count]; i++) { NSRect f = NSOffsetRect([items[i] frame], -[self _offset], 0); if (NSIntersectsRect(f, [self bounds])) { if (first < 0) first = i; last = i; } } return first < 0 ? NSMakeRange(0, 0) : NSMakeRange(first, last - first + 1); }
- (void)scrollItemAtIndex:(NSInteger)i toAlignment:(NSScrubberAlignment)a { NSArray *items = [self _items]; if (i < 0 || i >= (NSInteger)[items count]) return; NSRect f = [items[i] frame]; CGFloat o = [self _offset]; switch (a) { case NSScrubberAlignmentLeading: o = f.origin.x; break; case NSScrubberAlignmentTrailing: o = NSMaxX(f) - [self bounds].size.width; break; case NSScrubberAlignmentCenter: o = NSMidX(f) - [self bounds].size.width / 2; break; default: break; } St(self)[@"off"] = @(o); [self _clampOffset]; }
- (void)insertItemsAtIndexes:(NSIndexSet *)i { [self reloadData]; } - (void)removeItemsAtIndexes:(NSIndexSet *)i { [self reloadData]; } - (void)reloadItemsAtIndexes:(NSIndexSet *)i { [self reloadData]; } - (void)moveItemAtIndex:(NSInteger)a toIndex:(NSInteger)b { [self reloadData]; }
- (void)performSequentialBatchUpdates:(void (^)(void))u { if (u) u(); [self reloadData]; }
- (NSInteger)_indexAtPoint:(NSPoint)p { NSArray *items = [self _items]; NSPoint q = NSMakePoint(p.x + [self _offset], p.y); for (NSInteger i = 0; i < (NSInteger)[items count]; i++) if (NSPointInRect(q, NSInsetRect([items[i] frame], -4, -20))) return i; return -1; }
- (void)mouseDown:(NSEvent *)e
{
	NSPoint p = [self convertPoint: [e locationInWindow] fromView: nil]; St(self)[@"down"] = [NSValue valueWithPoint: p]; St(self)[@"downoff"] = @([self _offset]); St(self)[@"dragged"] = @NO; id<NSScrubberDelegate> d = [self delegate];
	if ([d respondsToSelector: @selector(didBeginInteractingWithScrubber:)]) [d didBeginInteractingWithScrubber: self];
	NSInteger i = [self _indexAtPoint: p]; if (i >= 0) { self.highlightedIndex = i; if ([d respondsToSelector: @selector(scrubber:didHighlightItemAtIndex:)]) [d scrubber: self didHighlightItemAtIndex: i]; }
}
- (void)mouseDragged:(NSEvent *)e
{
	NSPoint p = [self convertPoint: [e locationInWindow] fromView: nil], down = [SS("down") pointValue]; id<NSScrubberDelegate> d = [self delegate]; BOOL dragged = [SS("dragged") boolValue];
	if ([self mode] == NSScrubberModeFree && ([[self _doc] frame].size.width > [self bounds].size.width) && (fabs(p.x - down.x) > 4 || dragged)) { St(self)[@"dragged"] = @YES; St(self)[@"off"] = @([SS("downoff") doubleValue] - (p.x - down.x)); [self _clampOffset]; if ([d respondsToSelector: @selector(scrubber:didChangeVisibleRange:)]) [d scrubber: self didChangeVisibleRange: [self visibleRange]]; return; }
	NSInteger i = [self _indexAtPoint: p]; if (i >= 0 && i != [self highlightedIndex]) { self.highlightedIndex = i; if ([d respondsToSelector: @selector(scrubber:didHighlightItemAtIndex:)]) [d scrubber: self didHighlightItemAtIndex: i]; if ([self isContinuous] && [self mode] == NSScrubberModeFixed) { self.selectedIndex = i; if ([d respondsToSelector: @selector(scrubber:didSelectItemAtIndex:)]) [d scrubber: self didSelectItemAtIndex: i]; } }
}
- (void)mouseUp:(NSEvent *)e
{
	NSPoint p = [self convertPoint: [e locationInWindow] fromView: nil]; id<NSScrubberDelegate> d = [self delegate]; NSInteger i = [SS("dragged") boolValue] ? -1 : [self _indexAtPoint: p]; self.highlightedIndex = -1;
	if (i >= 0) { self.selectedIndex = i; if ([d respondsToSelector: @selector(scrubber:didSelectItemAtIndex:)]) [d scrubber: self didSelectItemAtIndex: i]; }
	if ([d respondsToSelector: @selector(didFinishInteractingWithScrubber:)]) [d didFinishInteractingWithScrubber: self];
}
- (void)drawRect:(NSRect)r { NSColor *c = [self backgroundColor]; if (c && (id)c != [NSNull null]) { [c setFill]; [[NSBezierPath bezierPathWithRoundedRect: [self bounds] xRadius: 6 yRadius: 6] fill]; } }
@end

/* ================= picker ================= */
@implementation NSPickerTouchBarItem (WsbsdTouchBar)
static NSSegmentedControl *Seg(NSPickerTouchBarItem *i) { NSSegmentedControl *s = St(i)[@"seg"]; if (!s) { s = [[NSSegmentedControl alloc] initWithFrame: NSMakeRect(0, 0, 180, 30)]; St(i)[@"seg"] = s; } return s; }
static void SegFit(NSSegmentedControl *s) { NSInteger n = [s segmentCount]; for (NSInteger k = 0; k < n; k++) [s setWidth: 0 forSegment: k]; }
+ (instancetype)pickerTouchBarItemWithIdentifier:(NSTouchBarItemIdentifier)i labels:(NSArray *)labels selectionMode:(NSPickerTouchBarItemSelectionMode)m target:(id)t action:(SEL)a
{ NSPickerTouchBarItem *it = [[self alloc] initWithIdentifier: i]; NSSegmentedControl *s = Seg(it); [s setSegmentCount: [labels count]]; for (NSUInteger k = 0; k < [labels count]; k++) [s setLabel: labels[k] forSegment: k]; [it setSelectionMode: m]; [s setTarget: t]; [s setAction: a]; if (m == NSPickerTouchBarItemSelectionModeSelectOne && [labels count]) [s setSelectedSegment: 0]; return it; }
+ (instancetype)pickerTouchBarItemWithIdentifier:(NSTouchBarItemIdentifier)i images:(NSArray *)images selectionMode:(NSPickerTouchBarItemSelectionMode)m target:(id)t action:(SEL)a
{ NSPickerTouchBarItem *it = [[self alloc] initWithIdentifier: i]; NSSegmentedControl *s = Seg(it); [s setSegmentCount: [images count]]; for (NSUInteger k = 0; k < [images count]; k++) [s setImage: images[k] forSegment: k]; [it setSelectionMode: m]; [s setTarget: t]; [s setAction: a]; if (m == NSPickerTouchBarItemSelectionModeSelectOne && [images count]) [s setSelectedSegment: 0]; return it; }
- (NSView *)view { return Seg(self); }
- (NSInteger)selectedIndex { return [Seg(self) selectedSegment]; } - (void)setSelectedIndex:(NSInteger)i { [Seg(self) setSelectedSegment: i]; }
- (NSColor *)selectionColor { return St(self)[@"selcol"]; } - (void)setSelectionColor:(NSColor *)c { St(self)[@"selcol"] = c ?: [NSNull null]; }
- (NSPickerTouchBarItemSelectionMode)selectionMode { return (NSPickerTouchBarItemSelectionMode)[St(self)[@"mode"] integerValue]; }
- (void)setSelectionMode:(NSPickerTouchBarItemSelectionMode)m { St(self)[@"mode"] = @(m); [Seg(self) setTrackingMode: m == NSPickerTouchBarItemSelectionModeSelectOne ? NSSegmentSwitchTrackingSelectOne : m == NSPickerTouchBarItemSelectionModeSelectAny ? NSSegmentSwitchTrackingSelectAny : NSSegmentSwitchTrackingMomentary]; }
- (NSPickerTouchBarItemControlRepresentation)controlRepresentation { return (NSPickerTouchBarItemControlRepresentation)[St(self)[@"rep"] integerValue]; } - (void)setControlRepresentation:(NSPickerTouchBarItemControlRepresentation)r { St(self)[@"rep"] = @(r); }
- (NSInteger)numberOfOptions { return [Seg(self) segmentCount]; } - (void)setNumberOfOptions:(NSInteger)n { [Seg(self) setSegmentCount: n]; SegFit(Seg(self)); }
- (NSString *)collapsedRepresentationLabel { return St(self)[@"cl"]; } - (void)setCollapsedRepresentationLabel:(NSString *)l { St(self)[@"cl"] = [l copy]; }
- (NSImage *)collapsedRepresentationImage { return St(self)[@"ci"]; } - (void)setCollapsedRepresentationImage:(NSImage *)i { St(self)[@"ci"] = i ?: [NSNull null]; }
- (id)target { return [Seg(self) target]; } - (void)setTarget:(id)t { [Seg(self) setTarget: t]; } - (SEL)action { return [Seg(self) action]; } - (void)setAction:(SEL)a { [Seg(self) setAction: a]; }
- (BOOL)isEnabled { return [Seg(self) isEnabled]; } - (void)setEnabled:(BOOL)e { [Seg(self) setEnabled: e]; }
- (NSString *)customizationLabel { return St(self)[@"label"]; } - (void)setCustomizationLabel:(NSString *)l { St(self)[@"label"] = [l copy]; }
- (void)setImage:(NSImage *)im atIndex:(NSInteger)k { [Seg(self) setImage: im forSegment: k]; } - (NSImage *)imageAtIndex:(NSInteger)k { return [Seg(self) imageForSegment: k]; }
- (void)setLabel:(NSString *)l atIndex:(NSInteger)k { [Seg(self) setLabel: l forSegment: k]; } - (NSString *)labelAtIndex:(NSInteger)k { return [Seg(self) labelForSegment: k]; }
- (void)setEnabled:(BOOL)e atIndex:(NSInteger)k { [Seg(self) setEnabled: e forSegment: k]; } - (BOOL)isEnabledAtIndex:(NSInteger)k { return [Seg(self) isEnabledForSegment: k]; }
@end

/* ================= popover ================= */
@interface WsbsdPopoverButton : NSButton @end
@implementation WsbsdPopoverButton - (void)mouseDown:(NSEvent *)e { NSPopoverTouchBarItem *it = objc_getAssociatedObject(self, "item"); [it showPopover: self]; } @end
@implementation NSPopoverTouchBarItem (WsbsdTouchBar)
- (NSView *)view
{
	NSView *c = St(self)[@"collapsed"]; if (c) return c;
	NSButton *b = St(self)[@"btn"]; if (!b) { b = [[NSButtonTouchBarItem buttonTouchBarItemWithIdentifier: [self identifier] title: [self collapsedRepresentationLabel] image: [self collapsedRepresentationImage] target: self action: @selector(showPopover:)] view] ? (NSButton *)[[NSButtonTouchBarItem buttonTouchBarItemWithIdentifier: [self identifier] title: [self collapsedRepresentationLabel] image: [self collapsedRepresentationImage] target: self action: @selector(showPopover:)] view] : nil; St(self)[@"btn"] = b; }
	return b;
}
- (NSTouchBar *)popoverTouchBar { return St(self)[@"pop"]; } - (void)setPopoverTouchBar:(NSTouchBar *)b { St(self)[@"pop"] = b ?: [NSNull null]; }
- (NSTouchBar *)pressAndHoldTouchBar { return St(self)[@"hold"]; } - (void)setPressAndHoldTouchBar:(NSTouchBar *)b { St(self)[@"hold"] = b ?: [NSNull null]; }
- (NSView *)collapsedRepresentation { return St(self)[@"collapsed"]; } - (void)setCollapsedRepresentation:(NSView *)v { if (v) St(self)[@"collapsed"] = v; else [St(self) removeObjectForKey: @"collapsed"]; }
- (NSImage *)collapsedRepresentationImage { return St(self)[@"ci"]; } - (void)setCollapsedRepresentationImage:(NSImage *)i { St(self)[@"ci"] = i ?: [NSNull null]; [St(self) removeObjectForKey: @"btn"]; }
- (NSString *)collapsedRepresentationLabel { return St(self)[@"cl"]; } - (void)setCollapsedRepresentationLabel:(NSString *)l { St(self)[@"cl"] = [l copy] ?: [NSNull null]; [St(self) removeObjectForKey: @"btn"]; }
- (BOOL)showsCloseButton { NSNumber *n = St(self)[@"close"]; return n ? [n boolValue] : YES; } - (void)setShowsCloseButton:(BOOL)b { St(self)[@"close"] = @(b); }
- (NSString *)customizationLabel { return St(self)[@"label"]; } - (void)setCustomizationLabel:(NSString *)l { St(self)[@"label"] = [l copy]; }
- (void)showPopover:(id)sender { NSTouchBar *b = [self popoverTouchBar]; if ((id)b == [NSNull null]) b = nil; if (b) [WsbsdTouchBarHost _presentBar: b closeButton: [self showsCloseButton]]; }
- (void)dismissPopover:(id)sender { NSTouchBar *b = [self popoverTouchBar]; if ((id)b != [NSNull null] && b) [WsbsdTouchBarHost _dismissBar: b]; }
- (NSGestureRecognizer *)makeStandardActivatePopoverGestureRecognizer { return [[NSClickGestureRecognizer alloc] initWithTarget: self action: @selector(showPopover:)]; }
@end

/* ================= stepper ================= */
@implementation NSStepperTouchBarItem (WsbsdTouchBar)
+ (instancetype)stepperTouchBarItemWithIdentifier:(NSTouchBarItemIdentifier)i formatter:(NSFormatter *)f { NSStepperTouchBarItem *it = [[self alloc] initWithIdentifier: i]; St(it)[@"fmt"] = f ?: [NSNull null]; St(it)[@"max"] = @100; St(it)[@"min"] = @0; St(it)[@"inc"] = @1; St(it)[@"val"] = @0; return it; }
- (double)maxValue { return [St(self)[@"max"] doubleValue]; } - (void)setMaxValue:(double)v { St(self)[@"max"] = @(v); [self _refresh]; }
- (double)minValue { return [St(self)[@"min"] doubleValue]; } - (void)setMinValue:(double)v { St(self)[@"min"] = @(v); [self _refresh]; }
- (double)increment { NSNumber *n = St(self)[@"inc"]; return n ? [n doubleValue] : 1; } - (void)setIncrement:(double)v { St(self)[@"inc"] = @(v); }
- (double)value { return [St(self)[@"val"] doubleValue]; } - (void)setValue:(double)v { St(self)[@"val"] = @(MAX([self minValue], MIN([self maxValue], v))); [self _refresh]; }
- (id)target { return [St(self)[@"target"] nonretainedObjectValue]; } - (void)setTarget:(id)t { St(self)[@"target"] = [NSValue valueWithNonretainedObject: t]; } - (SEL)action { return NSSelectorFromString(St(self)[@"action"]); } - (void)setAction:(SEL)a { St(self)[@"action"] = NSStringFromSelector(a); }
- (NSString *)customizationLabel { return St(self)[@"label"]; } - (void)setCustomizationLabel:(NSString *)l { St(self)[@"label"] = [l copy]; }
- (void)_refresh { NSTextField *t = St(self)[@"text"]; if (!t) return; NSFormatter *f = St(self)[@"fmt"]; if ((id)f == [NSNull null]) f = nil; [t setStringValue: f ? [f stringForObjectValue: @([self value])] : [NSString stringWithFormat: @"%g", [self value]]]; }
- (void)_step:(NSButton *)b { [self setValue: [self value] + ([b tag] ? -[self increment] : [self increment])]; SEL a = [self action]; id t = [self target]; if (a) [NSApp sendAction: a to: t from: self]; }
- (NSView *)view
{
	NSView *v = St(self)[@"view"]; if (v) return v; v = [[NSView alloc] initWithFrame: NSMakeRect(0, 0, 150, 30)];
	NSTextField *t = [NSTextField labelWithString: @""]; [t setTextColor: [NSColor whiteColor]]; [t setAlignment: NSTextAlignmentCenter]; [t setFrame: NSMakeRect(0, 5, 70, 20)]; [v addSubview: t]; St(self)[@"text"] = t;
	NSButton *minus = [NSButton buttonWithTitle: @"-" target: self action: @selector(_step:)]; [minus setTag: 1]; [minus setFrame: NSMakeRect(74, 0, 36, 30)]; NSButton *plus = [NSButton buttonWithTitle: @"+" target: self action: @selector(_step:)]; [plus setFrame: NSMakeRect(114, 0, 36, 30)];
	[v addSubview: minus]; [v addSubview: plus]; St(self)[@"view"] = v; [self _refresh]; return v;
}
@end

/* ================= color picker ================= */
@implementation NSColorPickerTouchBarItem (WsbsdTouchBar)
+ (instancetype)colorPickerWithIdentifier:(NSTouchBarItemIdentifier)i { NSColorPickerTouchBarItem *it = [[self alloc] initWithIdentifier: i]; St(it)[@"color"] = [NSColor redColor]; return it; }
+ (instancetype)textColorPickerWithIdentifier:(NSTouchBarItemIdentifier)i { NSColorPickerTouchBarItem *it = [self colorPickerWithIdentifier: i]; St(it)[@"kind"] = @"text"; St(it)[@"color"] = [NSColor blackColor]; return it; }
+ (instancetype)strokeColorPickerWithIdentifier:(NSTouchBarItemIdentifier)i { NSColorPickerTouchBarItem *it = [self colorPickerWithIdentifier: i]; St(it)[@"kind"] = @"stroke"; return it; }
+ (instancetype)colorPickerWithIdentifier:(NSTouchBarItemIdentifier)i buttonImage:(NSImage *)img { NSColorPickerTouchBarItem *it = [self colorPickerWithIdentifier: i]; St(it)[@"img"] = img ?: [NSNull null]; return it; }
- (NSColor *)color { return St(self)[@"color"]; } - (void)setColor:(NSColor *)c { St(self)[@"color"] = c ?: [NSColor blackColor]; NSView *b = St(self)[@"swatch"]; if (b) { WsbsdTBSetSwatch(b, St(self)[@"color"]); } }
- (BOOL)showsAlpha { return [St(self)[@"alpha"] boolValue]; } - (void)setShowsAlpha:(BOOL)b { St(self)[@"alpha"] = @(b); }
- (NSColorList *)colorList { return St(self)[@"list"]; } - (void)setColorList:(NSColorList *)l { St(self)[@"list"] = l ?: [NSNull null]; }
- (id)target { return [St(self)[@"target"] nonretainedObjectValue]; } - (void)setTarget:(id)t { St(self)[@"target"] = [NSValue valueWithNonretainedObject: t]; } - (SEL)action { return NSSelectorFromString(St(self)[@"action"]); } - (void)setAction:(SEL)a { St(self)[@"action"] = NSStringFromSelector(a); }
- (BOOL)isEnabled { NSNumber *n = St(self)[@"en"]; return n ? [n boolValue] : YES; } - (void)setEnabled:(BOOL)e { St(self)[@"en"] = @(e); }
- (NSString *)customizationLabel { return St(self)[@"label"]; } - (void)setCustomizationLabel:(NSString *)l { St(self)[@"label"] = [l copy]; }
- (void)_pick:(NSButton *)b { NSArray *cols = St(self)[@"cols"]; self.color = cols[[b tag]]; SEL a = [self action]; if (a) [NSApp sendAction: a to: [self target] from: self]; [WsbsdTouchBarHost _dismissBar: St(self)[@"bar"]]; }
- (void)_show:(id)sender
{
	NSTouchBar *bar = St(self)[@"bar"]; if (!bar) { bar = [NSTouchBar new]; St(self)[@"bar"] = bar; }
	NSArray *cols = @[ [NSColor redColor], [NSColor orangeColor], [NSColor yellowColor], [NSColor greenColor], [NSColor cyanColor], [NSColor blueColor], [NSColor purpleColor], [NSColor magentaColor], [NSColor brownColor], [NSColor whiteColor], [NSColor grayColor], [NSColor blackColor] ]; St(self)[@"cols"] = cols;
	NSMutableSet *items = [NSMutableSet set]; NSMutableArray *ids = [NSMutableArray array];
	for (NSUInteger i = 0; i < [cols count]; i++) { NSCustomTouchBarItem *c = [[NSCustomTouchBarItem alloc] initWithIdentifier: [NSString stringWithFormat: @"c%lu", (unsigned long)i]]; NSButton *b = WsbsdTBMakeSwatchButton(cols[i], @"", self, @selector(_pick:)); [b setTag: i]; [c setView: b]; [items addObject: c]; [ids addObject: [c identifier]]; }
	[bar setTemplateItems: items]; [bar setDefaultItemIdentifiers: ids]; [WsbsdTouchBarHost _presentBar: bar closeButton: YES];
}
- (NSView *)view
{
	NSButton *b = St(self)[@"btn"]; if (b) return b; NSImage *img = St(self)[@"img"]; if ((id)img == [NSNull null]) img = nil;
	b = WsbsdTBMakeSwatchButton([self color], St(self)[@"kind"] ? ([St(self)[@"kind"] isEqual: @"text"] ? @"A" : @"S") : @"", self, @selector(_show:)); if (img) [b setImage: img]; St(self)[@"btn"] = b; St(self)[@"swatch"] = b; return b;
}
@end

/* ================= sharing picker, candidate list ================= */
@implementation NSSharingServicePickerTouchBarItem (WsbsdTouchBar)
- (id)delegate { return [St(self)[@"del"] nonretainedObjectValue]; } - (void)setDelegate:(id)d { St(self)[@"del"] = [NSValue valueWithNonretainedObject: d]; }
- (BOOL)isEnabled { NSNumber *n = St(self)[@"en"]; return n ? [n boolValue] : YES; } - (void)setEnabled:(BOOL)e { St(self)[@"en"] = @(e); [(NSButton *)St(self)[@"btn"] setEnabled: e]; }
- (NSImage *)buttonImage { return St(self)[@"img"]; } - (void)setButtonImage:(NSImage *)i { St(self)[@"img"] = i ?: [NSNull null]; [(NSButton *)St(self)[@"btn"] setImage: i]; }
- (NSString *)buttonTitle { return St(self)[@"title"]; } - (void)setButtonTitle:(NSString *)t { St(self)[@"title"] = [t copy] ?: [NSNull null]; [(NSButton *)St(self)[@"btn"] setTitle: t ?: @""]; }
- (NSString *)customizationLabel { return St(self)[@"label"]; } - (void)setCustomizationLabel:(NSString *)l { St(self)[@"label"] = [l copy]; }
- (void)_share:(id)sender { /* the services are listed by the sharing picker of the application (NSSharingServicePicker) */ id<NSSharingServicePickerTouchBarItemDelegate> d = [self delegate]; Class pc = NSClassFromString(@"NSSharingServicePicker"); if ([d respondsToSelector: @selector(itemsForSharingServicePickerTouchBarItem:)] && pc) { NSArray *items = [d itemsForSharingServicePickerTouchBarItem: self]; id p = [[pc alloc] performSelector: @selector(initWithItems:) withObject: items ?: @[]]; NSView *b = St(self)[@"btn"]; NSMethodSignature *ms = [p methodSignatureForSelector: @selector(showRelativeToRect:ofView:preferredEdge:)]; if (ms) { NSInvocation *iv = [NSInvocation invocationWithMethodSignature: ms]; NSRect r = [b bounds]; NSRectEdge edge = NSMinYEdge; [iv setTarget: p]; [iv setSelector: @selector(showRelativeToRect:ofView:preferredEdge:)]; [iv setArgument: &r atIndex: 2]; [iv setArgument: &b atIndex: 3]; [iv setArgument: &edge atIndex: 4]; [iv invoke]; } } }
- (NSView *)view { NSButton *b = St(self)[@"btn"]; if (!b) { NSImage *img = [self buttonImage]; if ((id)img == [NSNull null]) img = nil; b = [NSButton buttonWithTitle: [self buttonTitle] ?: @"" target: self action: @selector(_share:)]; [b setImage: img ?: [NSImage imageNamed: @"NSTouchBarShareTemplate"]]; [b setFrameSize: NSMakeSize(64, 30)]; St(self)[@"btn"] = b; } return b; }
@end
@implementation NSCandidateListTouchBarItem (WsbsdTouchBar)
- (id)delegate { return [St(self)[@"del"] nonretainedObjectValue]; } - (void)setDelegate:(id)d { St(self)[@"del"] = [NSValue valueWithNonretainedObject: d]; }
- (BOOL)isCandidateListVisible { return [St(self)[@"cands"] count] > 0; }
- (void (^)(BOOL))updateWithInsertionPointVisibility { return St(self)[@"upd"]; } - (void)setUpdateWithInsertionPointVisibility:(void (^)(BOOL))b { St(self)[@"upd"] = [b copy] ?: [NSNull null]; }
- (NSView *)client { return [St(self)[@"client"] nonretainedObjectValue]; } - (void)setClient:(NSView *)c { St(self)[@"client"] = [NSValue valueWithNonretainedObject: c]; }
- (NSString *)customizationLabel { return St(self)[@"label"]; } - (void)setCustomizationLabel:(NSString *)l { St(self)[@"label"] = [l copy]; }
- (void)setCandidates:(NSArray *)c forSelectedRange:(NSRange)r inString:(NSString *)s { St(self)[@"cands"] = [c copy] ?: @[]; NSScrubber *sc = [self _scrubber]; [sc reloadData]; }
- (NSInteger)numberOfItemsForScrubber:(NSScrubber *)s { return [St(self)[@"cands"] count]; }
- (NSScrubberItemView *)scrubber:(NSScrubber *)s viewForItemAtIndex:(NSInteger)i { NSScrubberTextItemView *v = [s makeItemWithIdentifier: @"cand" owner: nil]; id c = St(self)[@"cands"][i]; [v setTitle: [c isKindOfClass: [NSString class]] ? c : [c description]]; NSFont *f = [NSFont systemFontOfSize: 15]; CGFloat w = [[v title] sizeWithAttributes: @{ NSFontAttributeName: f }].width + 24; [v setFrameSize: NSMakeSize(w, 30)]; return v; }
- (void)scrubber:(NSScrubber *)s didSelectItemAtIndex:(NSInteger)i { id<NSCandidateListTouchBarItemDelegate> d = [self delegate]; if ([d respondsToSelector: @selector(candidateListTouchBarItem:endSelectingCandidateAtIndex:)]) [d candidateListTouchBarItem: self endSelectingCandidateAtIndex: i]; }
- (NSScrubber *)_scrubber { NSScrubber *s = St(self)[@"scr"]; if (!s) { s = [[NSScrubber alloc] initWithFrame: NSMakeRect(0, 0, 420, 30)]; [s registerClass: [NSScrubberTextItemView class] forItemIdentifier: @"cand"]; NSScrubberFlowLayout *l = [NSScrubberFlowLayout new]; l.itemSize = NSMakeSize(80, 30); l.itemSpacing = 4; [s setScrubberLayout: l]; [s setMode: NSScrubberModeFree]; [s setDataSource: self]; [s setDelegate: self]; St(self)[@"scr"] = s; } return s; }
- (NSView *)view { return [self _scrubber]; }
@end

@implementation NSGroupTouchBarItem (WsbsdTouchBarAlert)
+ (instancetype)alertStyleGroupItemWithIdentifier:(NSTouchBarItemIdentifier)i { NSGroupTouchBarItem *g = [self groupItemWithIdentifier: i items: @[]]; objc_setAssociatedObject(g, "alert", @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC); return g; }
@end
