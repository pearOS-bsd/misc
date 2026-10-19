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

