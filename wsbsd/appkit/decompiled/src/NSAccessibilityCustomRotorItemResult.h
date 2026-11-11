/*
 * NSAccessibilityCustomRotorItemResult.h — 1:1 reimplementation of AppKit's
 * NSAccessibilityCustomRotorItemResult, one result a custom rotor's search
 * delegate returns.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSAccessibilityCustomRotorItemResult_interface.txt. Real ivars:
 * _targetElement (weak), _targetRange, _customLabel, _itemLoadingToken.
 *
 * Measured on this Mac: targetRange defaults to {NSNotFound, 0}. Two
 * initializers — initWithTargetElement: and initWithItemLoadingToken:customLabel:.
 * Pure value object — no stage2.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol NSAccessibilityElement;

@interface NSAccessibilityCustomRotorItemResult : NSObject

- (instancetype)initWithTargetElement:(id<NSAccessibilityElement>)targetElement;
- (instancetype)initWithItemLoadingToken:(id<NSSecureCoding>)itemLoadingToken customLabel:(NSString *)customLabel;

@property (nullable, weak, readonly) id<NSAccessibilityElement> targetElement;
@property (nullable, readonly) id<NSSecureCoding> itemLoadingToken;
@property NSRange targetRange;                   /* default {NSNotFound, 0} */
@property (nullable, copy) NSString *customLabel;

@end

NS_ASSUME_NONNULL_END
