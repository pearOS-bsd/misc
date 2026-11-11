/*
 * NSSliderAccessory.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSSliderAccessory and its companion NSSliderAccessoryBehavior (the leading/
 * trailing accessory shown at a slider's ends, macOS 15+).
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSSliderAccessory_interface.txt. NSSliderAccessory's real ivars
 * are _content, _container, _behavior, _enabled (the huge method tail is the
 * inherited NSAccessibility protocol).
 *
 * Measured on this Mac: accessoryWithImage: returns an object; isEnabled
 * defaults YES; NSSliderAccessoryBehavior vends concrete automatic/valueStep/
 * valueReset behaviors plus target/action + handler behaviors; repeatsOnLongPress
 * is derived from the behavior.
 *
 * This core reproduces the accessory identity (image/enabled/behavior, weak
 * enclosingSlider/container) and the behavior value object. The slider-bar
 * rendering, hit testing and the full accessibility element surface are
 * TODO(stage2).
 */

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@class NSImage, NSSlider, NSSliderAccessory;

@interface NSSliderAccessoryBehavior : NSObject <NSCoding, NSCopying>
@property (class, readonly, copy) NSSliderAccessoryBehavior *automaticBehavior;
@property (class, readonly, copy) NSSliderAccessoryBehavior *valueStepBehavior;
@property (class, readonly, copy) NSSliderAccessoryBehavior *valueResetBehavior;
+ (NSSliderAccessoryBehavior *)behaviorWithTarget:(nullable id)target action:(SEL)action;
+ (NSSliderAccessoryBehavior *)behaviorWithHandler:(void (^)(NSSliderAccessory *accessory))handler;
- (BOOL)repeatsOnLongPressForAccessory:(NSSliderAccessory *)accessory;
- (void)handleAction:(NSSliderAccessory *)accessory;
@end

@interface NSSliderAccessory : NSObject <NSCoding>

+ (NSSliderAccessory *)accessoryWithImage:(NSImage *)image;

@property (copy) NSSliderAccessoryBehavior *behavior;
@property (getter=isEnabled) BOOL enabled;                 /* default YES */
@property (nullable, weak) NSSlider *enclosingSlider;
@property (readonly) BOOL repeatsOnLongPress;

@end

NS_ASSUME_NONNULL_END
