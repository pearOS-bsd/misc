/*
 * NSScrollView.h — 1:1 reimplementation (core). NSView subclass.
 * Evidence ../evidence/scroll: _contentView (the NSClipView) at ivar 0x890,
 * _sFlags at 0x898 (borderType = bits 25-26). documentView delegates to the
 * clip view. Scroller flags are kept as plain bools (exact _sFlags bits for the
 * scrollers are stage2); the scroller views and scrolling are stage2.
 */
#import "NSView.h"
#import "NSClipView.h"
#import "NSBox.h"   /* NSBorderType */

NS_ASSUME_NONNULL_BEGIN

@interface NSScrollView : NSView
@property (strong) NSClipView *contentView;
@property (nullable, strong) NSView *documentView;
@property BOOL hasVerticalScroller;
@property BOOL hasHorizontalScroller;
@property NSBorderType borderType;
@end

NS_ASSUME_NONNULL_END
