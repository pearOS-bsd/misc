/*
 * NSGroupTouchBarItem.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSGroupTouchBarItem (: NSTouchBarItem), a Touch Bar item that hosts a nested
 * NSTouchBar of items.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSGroupTouchBarItem_interface.txt. Real ivars: _groupTouchBar,
 * _customizationLabel, _groupUserInterfaceLayoutDirection, _gtbiFlags.
 *
 * Measured on this Mac: initWithIdentifier: auto-creates a groupTouchBar;
 * groupUserInterfaceLayoutDirection LTR(0), prefersEqualWidths NO,
 * preferredItemWidth -1, prioritizedCompressionOptions has 4 standard options.
 * This core reproduces the group's value model + the nested touch bar + the
 * group factories. The contained-item measurement/compression layout and the
 * customization preview/palette views are TODO(stage2).
 */

#import "NSTouchBarItem.h"

NS_ASSUME_NONNULL_BEGIN

@class NSTouchBar, NSUserInterfaceCompressionOptions;

#ifndef NSUserInterfaceLayoutDirection_defined
#define NSUserInterfaceLayoutDirection_defined
typedef NS_ENUM(NSInteger, NSUserInterfaceLayoutDirection) {
    NSUserInterfaceLayoutDirectionLeftToRight = 0,
    NSUserInterfaceLayoutDirectionRightToLeft = 1,
};
#endif

@interface NSGroupTouchBarItem : NSTouchBarItem

+ (instancetype)groupItemWithIdentifier:(NSString *)identifier items:(NSArray<NSTouchBarItem *> *)items;
+ (instancetype)groupItemWithIdentifier:(NSString *)identifier items:(NSArray<NSTouchBarItem *> *)items allowedCompressionOptions:(nullable NSUserInterfaceCompressionOptions *)allowedCompressionOptions;
+ (instancetype)alertStyleGroupItemWithIdentifier:(NSString *)identifier;

@property (strong) NSTouchBar *groupTouchBar;
@property (copy) NSString *customizationLabel;
@property NSUserInterfaceLayoutDirection groupUserInterfaceLayoutDirection;  /* LTR */
@property BOOL prefersEqualWidths;                                           /* NO  */
@property CGFloat preferredItemWidth;                                        /* -1  */
@property (readonly) BOOL groupHasAlertStyle;
@property (copy) NSArray<NSUserInterfaceCompressionOptions *> *prioritizedCompressionOptions;

@end

NS_ASSUME_NONNULL_END
