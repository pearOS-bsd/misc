/* NSControl / NSButton / NSMenu methods of newer macOS that GNUstep lacks and that act through the cell or the menu view: controlSize, lineBreakMode, highlighted, usesSingleLineMode, image scaling,
 * symbol configuration (a symbol image of the button is re-made with it), highlightedItem, setItemArray:, size and minimumWidth of a menu, cancelTracking. Compiled without ARC. */
#import <AppKit/AppKit.h>
#import <objc/runtime.h>

static char kMinW, kSymCfg, kSingle;
@implementation NSControl (WsdControl)
- (NSControlSize)controlSize { return [[self cell] respondsToSelector: @selector(controlSize)] ? [(NSCell *)[self cell] controlSize] : NSRegularControlSize; }
- (void)setControlSize:(NSControlSize)s { [(NSCell *)[self cell] setControlSize: s]; [self setNeedsDisplay: YES]; }
- (NSLineBreakMode)lineBreakMode { return [(NSCell *)[self cell] lineBreakMode]; }
- (void)setLineBreakMode:(NSLineBreakMode)m { [(NSCell *)[self cell] setLineBreakMode: m]; [self setNeedsDisplay: YES]; }
- (BOOL)isHighlighted { return [(NSCell *)[self cell] isHighlighted]; }
- (void)setHighlighted:(BOOL)b { [(NSCell *)[self cell] setHighlighted: b]; [self setNeedsDisplay: YES]; }
- (BOOL)usesSingleLineMode { return [objc_getAssociatedObject(self, &kSingle) boolValue]; }
- (void)setUsesSingleLineMode:(BOOL)b { objc_setAssociatedObject(self, &kSingle, [NSNumber numberWithBool: b], OBJC_ASSOCIATION_RETAIN_NONATOMIC); [(NSCell *)[self cell] setWraps: !b]; [self setNeedsDisplay: YES]; }
@end

@implementation NSButton (WsdButton)
- (NSImageScaling)imageScaling { return [(NSButtonCell *)[self cell] imageScaling]; }
- (void)setImageScaling:(NSImageScaling)s { [(NSButtonCell *)[self cell] setImageScaling: s]; [self setNeedsDisplay: YES]; }
- (id)symbolConfiguration { return objc_getAssociatedObject(self, &kSymCfg); }
- (void)setSymbolConfiguration:(id)c
{
	objc_setAssociatedObject(self, &kSymCfg, c, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	NSImage *i = [self image]; if (i && c && [i respondsToSelector: @selector(imageWithSymbolConfiguration:)]) { NSImage *n = [i imageWithSymbolConfiguration: c]; if (n) [self setImage: n]; }
}
@end

@interface NSMenu (WsdMenuPrivate) @end
@implementation NSMenu (WsdMenu)
- (NSMenuItem *)highlightedItem { NSInteger i = [[self menuRepresentation] highlightedItemIndex]; return i >= 0 && i < [self numberOfItems] ? [self itemAtIndex: i] : nil; }
- (void)setItemArray:(NSArray *)items
{
	for (NSInteger i = [self numberOfItems] - 1; i >= 0; i--) [self removeItemAtIndex: i];
	for (NSMenuItem *it in items) [self addItem: it];
}
- (NSSize)size { NSMenuView *v = [self menuRepresentation]; [v sizeToFit]; return [v frame].size; }
- (CGFloat)minimumWidth { return [objc_getAssociatedObject(self, &kMinW) doubleValue]; }
- (void)setMinimumWidth:(CGFloat)w { objc_setAssociatedObject(self, &kMinW, [NSNumber numberWithDouble: w], OBJC_ASSOCIATION_RETAIN_NONATOMIC); [[self menuRepresentation] sizeToFit]; }
- (void)cancelTracking { for (NSMenu *m = self; m; m = [m supermenu]) { NSWindow *w = [[m menuRepresentation] window]; if (w && [w isVisible] && ![m isTornOff] && [m supermenu]) [w orderOut: nil]; } [[[self menuRepresentation] window] orderOut: nil]; }
- (void)cancelTrackingWithoutAnimation { [self cancelTracking]; }
@end


/* NSScrollView magnification: the clip view's bounds are the frame divided by the magnification, so the document is scaled about the point that stays in place (the centre by default);
 * minMagnification / maxMagnification clamp (0.25 and 4 as on macOS), magnifyToFitRect: picks the magnification that shows the rectangle. */
static char kMag, kMagMin, kMagMax;
@interface NSScrollView (WsdMagnification) @end
@implementation NSScrollView (WsdMagnification)
- (CGFloat)magnification { NSNumber *n = objc_getAssociatedObject(self, &kMag); return n ? [n doubleValue] : 1.0; }
- (CGFloat)minMagnification { NSNumber *n = objc_getAssociatedObject(self, &kMagMin); return n ? [n doubleValue] : 0.25; }
- (CGFloat)maxMagnification { NSNumber *n = objc_getAssociatedObject(self, &kMagMax); return n ? [n doubleValue] : 4.0; }
- (void)setMinMagnification:(CGFloat)m { objc_setAssociatedObject(self, &kMagMin, [NSNumber numberWithDouble: m], OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (void)setMaxMagnification:(CGFloat)m { objc_setAssociatedObject(self, &kMagMax, [NSNumber numberWithDouble: m], OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (void)setMagnification:(CGFloat)m centeredAtPoint:(NSPoint)p        /* p in document coordinates */
{
	m = MAX([self minMagnification], MIN([self maxMagnification], m));
	NSClipView *clip = [self contentView]; NSRect cf = [clip frame], b = [clip bounds];
	NSPoint rel = NSMakePoint(b.size.width > 0 ? (p.x - b.origin.x) / b.size.width : 0.5, b.size.height > 0 ? (p.y - b.origin.y) / b.size.height : 0.5);   /* where p sits in the visible rectangle */
	NSSize nb = NSMakeSize(cf.size.width / m, cf.size.height / m);
	objc_setAssociatedObject(self, &kMag, [NSNumber numberWithDouble: m], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	[clip setBoundsSize: nb];
	NSPoint o = NSMakePoint(p.x - rel.x * nb.width, p.y - rel.y * nb.height);
	[clip scrollToPoint: [clip constrainScrollPoint: o]]; [self reflectScrolledClipView: clip];
	[self setNeedsDisplay: YES];
}
- (void)setMagnification:(CGFloat)m { NSRect b = [[self contentView] bounds]; [self setMagnification: m centeredAtPoint: NSMakePoint(NSMidX(b), NSMidY(b))]; }
- (void)magnifyToFitRect:(NSRect)r
{
	NSRect cf = [[self contentView] frame]; if (r.size.width <= 0 || r.size.height <= 0) return;
	CGFloat m = MIN(cf.size.width / r.size.width, cf.size.height / r.size.height);
	[self setMagnification: m centeredAtPoint: NSMakePoint(NSMidX(r), NSMidY(r))];
}
@end
