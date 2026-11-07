/*
 * NSStackView.h — 1:1 reimplementation (core). NSView subclass.
 * Evidence ../evidence/stack: orientation @0x1fc, spacing @0x218 (double),
 * arrangedSubviews is a maintained array; addArrangedSubview: appends and adds
 * the view as a subview. Auto-layout / gravity areas are stage2.
 */
#import "NSView.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NSUserInterfaceLayoutOrientation) {
    NSUserInterfaceLayoutOrientationHorizontal = 0,
    NSUserInterfaceLayoutOrientationVertical = 1,
};

@interface NSStackView : NSView
@property NSUserInterfaceLayoutOrientation orientation;
@property CGFloat spacing;
@property (readonly, copy) NSArray<NSView *> *arrangedSubviews;
- (void)addArrangedSubview:(NSView *)view;
- (void)removeArrangedSubview:(NSView *)view;
@end

NS_ASSUME_NONNULL_END
