/*
 * NSSliderAccessoryBehavior.h — 1:1 reimplementation (core). NSObject <NSCoding, NSCopying>.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSSliderAccessoryBehavior : NSObject <NSCoding, NSCopying>
 *   +automaticBehavior +valueResetBehavior +valueStepBehavior
 *   +behaviorWithTarget:action: +behaviorWithHandler:
 *   -handleAction: -repeatsOnLongPressForAccessory:
 *
 * What happens when a slider accessory is pressed: a built-in behavior
 * (automatic / value-reset / value-step) or a custom handler / target-action.
 * handleAction: dispatches to the handler or target/action; the built-in
 * value-reset/value-step effects on the slider are stage2.
 */
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSSliderAccessoryBehavior : NSObject <NSCopying>

+ (instancetype)automaticBehavior;
+ (instancetype)valueResetBehavior;
+ (instancetype)valueStepBehavior;
+ (instancetype)behaviorWithTarget:(id)target action:(SEL)action;
+ (instancetype)behaviorWithHandler:(void (^)(id sender))handler;

- (void)handleAction:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END
