/*
 * NSScroller.h — 1:1 reimplementation (core). NSControl subclass.
 * Evidence ../evidence/scroller: knobProportion @0x8a8, doubleValue @0x88c
 * (both double, clamped to [0,1]); scrollerStyle = _sFlags2 @0x54c bit 9.
 * Hit-testing / knob drawing / live scroll are stage2.
 */
#import "NSControl.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NSScrollerStyle) {
    NSScrollerStyleLegacy = 0,
    NSScrollerStyleOverlay = 1,
};

@interface NSScroller : NSControl
@property CGFloat knobProportion;
@property double doubleValue;
@property NSScrollerStyle scrollerStyle;
@end

NS_ASSUME_NONNULL_END
