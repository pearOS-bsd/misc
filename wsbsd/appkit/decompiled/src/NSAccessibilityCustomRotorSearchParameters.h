/*
 * NSAccessibilityCustomRotorSearchParameters.h — 1:1 reimplementation of AppKit's
 * NSAccessibilityCustomRotorSearchParameters, the value object handed to a custom
 * rotor's item-search delegate.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSAccessibilityCustomRotorSearchParameters_interface.txt. Real
 * ivars: _currentItem, _searchDirection, _filterString. Pure value object — no
 * stage2.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class NSAccessibilityCustomRotorItemResult;

typedef NS_ENUM(NSInteger, NSAccessibilityCustomRotorSearchDirection) {
    NSAccessibilityCustomRotorSearchDirectionPrevious = 0,
    NSAccessibilityCustomRotorSearchDirectionNext     = 1,
};

@interface NSAccessibilityCustomRotorSearchParameters : NSObject

@property (nullable, strong) NSAccessibilityCustomRotorItemResult *currentItem;
@property NSAccessibilityCustomRotorSearchDirection searchDirection;
@property (copy) NSString *filterString;

@end

NS_ASSUME_NONNULL_END
