/*
 * NSAccessibilityCustomChooserSearchPredicate.h — 1:1 reimplementation of
 * AppKit's NSAccessibilityCustomChooserSearchPredicate and
 * NSAccessibilityCustomChooserItemResult, the value objects of the custom
 * accessibility chooser search protocol.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSAccessibilityCustomChooserSearchPredicate_interface.txt.
 * Pure value objects — no stage2.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class NSAccessibilityCustomChooserItemResult;

typedef NS_ENUM(NSInteger, NSAccessibilityCustomChooserSearchDirection) {
    NSAccessibilityCustomChooserSearchDirectionPrevious = 0,
    NSAccessibilityCustomChooserSearchDirectionNext     = 1,
};

@interface NSAccessibilityCustomChooserSearchPredicate : NSObject
@property (nullable, strong) NSAccessibilityCustomChooserItemResult *currentItem;
@property NSAccessibilityCustomChooserSearchDirection searchDirection;
@property (copy) NSString *filterText;
@end

@interface NSAccessibilityCustomChooserItemResult : NSObject
- (instancetype)initWithTargetElement:(id)targetElement targetRange:(nullable NSValue *)targetRange;
@property (nullable, weak) id targetElement;
@property (nullable, strong) NSValue *targetRange;
@property (nullable, copy) NSString *descriptionOverride;
@end

NS_ASSUME_NONNULL_END
