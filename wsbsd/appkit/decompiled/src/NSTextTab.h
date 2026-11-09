/*
 * NSTextTab.h — 1:1 reimplementation (core). NSObject <NSCopying, NSSecureCoding>.
 * Public AppKit text API; ships in UIFoundation in the shared cache.
 *
 * Evidence: interface from the dyld shared cache (UIFoundation, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … UIFoundation --objc`:
 *
 *   @interface NSTextTab : NSObject <NSCopying, NSCoding, NSSecureCoding> {
 *       {?="alignment"b4"refCount"b24"unused"b4} _flags;   // alignment b0-3
 *       d _location;
 *       @ _reserved;                                        // options dict
 *   }
 *   @property (Tq,R) alignment;  (Td,R) location;  (T@"NSDictionary",R) options;
 *   -initWithTextAlignment:location:options: -initWithType:location:
 *
 * A text tab stop: an alignment (packed into _flags b0-3), a location in points
 * and an options dictionary. The legacy -initWithType:location: maps the old
 * NSTextTabType onto (alignment, options) — decimal tabs carry a column-
 * terminator option. The terminator character set itself is stage2.
 */
#import <Foundation/Foundation.h>
#import "NSParagraphStyle.h"   /* NSTextAlignment */

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, NSTextTabType) {
    NSLeftTabStopType = 0,
    NSRightTabStopType = 1,
    NSCenterTabStopType = 2,
    NSDecimalTabStopType = 3,
};

extern NSString * const NSTabColumnTerminatorsAttributeName;

@interface NSTextTab : NSObject <NSCopying>

- (instancetype)initWithTextAlignment:(NSTextAlignment)alignment
                             location:(CGFloat)loc
                              options:(NSDictionary<NSString *, id> *)options;
- (instancetype)initWithType:(NSTextTabType)type location:(CGFloat)loc;

@property (readonly) NSTextAlignment alignment;
@property (readonly) CGFloat location;
@property (readonly, copy) NSDictionary<NSString *, id> *options;

@end

NS_ASSUME_NONNULL_END
