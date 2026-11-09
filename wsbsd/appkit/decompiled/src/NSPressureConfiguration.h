/*
 * NSPressureConfiguration.h — 1:1 reimplementation (core). NSObject.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSPressureConfiguration : NSObject {
 *       q _pressureBehavior;
 *   }
 *   @property (Tq,R) pressureBehavior;
 *   -initWithPressureBehavior: -set
 *
 * The Force Touch pressure behaviour a view opts into. The core stores the
 * behaviour; -set pushes it to the current event's trackpad configuration
 * (a Multitouch/window-server call) and is stage2.
 */
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NSPressureBehavior) {
    NSPressureBehaviorUnknown = -1,
    NSPressureBehaviorPrimaryDefault = 0,
    NSPressureBehaviorPrimaryClick = 1,
    NSPressureBehaviorPrimaryGeneric = 2,
    NSPressureBehaviorPrimaryAccelerator = 3,
    NSPressureBehaviorPrimaryDeepClick = 5,
    NSPressureBehaviorPrimaryDeepDrag = 6,
};

@interface NSPressureConfiguration : NSObject

- (instancetype)initWithPressureBehavior:(NSPressureBehavior)pressureBehavior;
@property (readonly) NSPressureBehavior pressureBehavior;
- (void)set;

@end

NS_ASSUME_NONNULL_END
