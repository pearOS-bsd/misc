/*
 * NSPopover.h — 1:1 reimplementation (core). NSResponder subclass.
 * Evidence ../evidence/popover: behavior (ivar), _flags @0xa70 (animates = bit 0,
 * isShown = bit 4), contentSize @0xa78 (NSSize), contentViewController (ivar).
 * show/close positioning and the backing window are stage2.
 */
#import "NSResponder.h"
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NSPopoverBehavior) {
    NSPopoverBehaviorApplicationDefined = 0,
    NSPopoverBehaviorTransient = 1,
    NSPopoverBehaviorSemitransient = 2,
};

@interface NSPopover : NSResponder
@property NSPopoverBehavior behavior;
@property (getter=isShown, readonly) BOOL shown;
@property BOOL animates;
@property CGSize contentSize;
@property (nullable, strong) id contentViewController;
@end

NS_ASSUME_NONNULL_END
