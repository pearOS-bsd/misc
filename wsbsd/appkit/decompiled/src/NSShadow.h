/*
 * NSShadow.h — 1:1 reimplementation (core). NSObject <NSCopying, NSSecureCoding>.
 * Public AppKit API; ships in UIFoundation in the shared cache.
 *
 * Evidence: interface from the dyld shared cache (UIFoundation, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … UIFoundation --objc`:
 *
 *   @interface NSShadow : NSObject <NSCopying, NSSecureCoding> {
 *       Q _shadowFlags;
 *       {CGSize} _shadowOffset;
 *       d _shadowBlurRadius;
 *       @"NSColor" _shadowColor;
 *   }
 *   @property (T{CGSize},V_shadowOffset) shadowOffset;
 *   @property (Td,V_shadowBlurRadius) shadowBlurRadius;
 *   @property (T@"NSColor",C) shadowColor;
 *   +shadow +defaultShadowColor -initWithShadow: -set -applyToGraphicsContext:
 *
 * A plain value object. -set / -applyToGraphicsContext: push the shadow onto a
 * graphics context and are stage2.
 */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "NSColor.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSShadow : NSObject <NSCopying>

- (instancetype)init;
- (instancetype)initWithShadow:(NSShadow *)shadow;

@property CGSize shadowOffset;
@property CGFloat shadowBlurRadius;
@property (nullable, copy) NSColor *shadowColor;

@end

NS_ASSUME_NONNULL_END
