/*
 * NSButtonCell.h — 1:1 reimplementation of AppKit's NSButtonCell (core).
 *
 * Shape from ../reference; logic from ../evidence/button. NSButtonCell is an
 * NSActionCell, so it inherits the state/_cFlags core and target/action/tag.
 * It adds the title, bezel style and button type.
 *
 * Staged: the title is kept in the shipping cell's _contents and converted by
 * _NSButtonTitleFromContents / _NSButtonSetAttributedOrPlainTitle; and
 * setButtonType: programs highlight/showsState masks via a helper. We keep the
 * observable contract here and mark the exact storage TODO(stage2) in the .m.
 */
#import "NSActionCell.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, NSButtonType) {
    NSButtonTypeMomentaryLight    = 0,
    NSButtonTypePushOnPushOff     = 1,
    NSButtonTypeToggle            = 2,
    NSButtonTypeSwitch            = 3,
    NSButtonTypeRadio             = 4,
    NSButtonTypeMomentaryChange   = 5,
    NSButtonTypeOnOff             = 6,
    NSButtonTypeMomentaryPushIn   = 7,
    NSButtonTypeAccelerator       = 8,
    NSButtonTypeMultiLevelAccelerator = 9,
};

typedef NS_ENUM(NSInteger, NSBezelStyle) {
    NSBezelStyleAutomatic      = 0,
    NSBezelStylePush           = 1,
    NSBezelStyleFlexiblePush   = 2,
    NSBezelStyleDisclosure     = 5,
    NSBezelStyleCircular       = 7,
    NSBezelStyleHelpButton     = 9,
    NSBezelStyleSmallSquare    = 10,
    NSBezelStyleToolbar        = 11,
    NSBezelStyleBadge          = 12,
};

@interface NSButtonCell : NSActionCell

@property (copy) NSString *title;
@property NSBezelStyle bezelStyle;
- (void)setButtonType:(NSButtonType)type;

@end

NS_ASSUME_NONNULL_END
