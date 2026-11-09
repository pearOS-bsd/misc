/*
 * NSTextBlock.h — 1:1 reimplementation (core). NSObject <NSSecureCoding, NSCopying>.
 * Public AppKit text API; ships in UIFoundation in the shared cache.
 *
 * Evidence: interface from the dyld shared cache (UIFoundation, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … UIFoundation --objc`:
 *
 *   @interface NSTextBlock : NSObject <NSSecureCoding, NSCopying> {
 *       ^v _propVals;  Q _propMask;  Q _typeMask;  @ _primParamVal;  @ _otherParamVals;
 *   }
 *   @property (Td,R) contentWidth;  (Tq,R) contentWidthValueType;
 *   @property (Tq) verticalAlignment;  (T@"NSColor",C) backgroundColor;
 *   -setValue:type:forDimension: -valueForDimension: -valueTypeForDimension:
 *   -setWidth:type:forLayer:(edge:) -setContentWidth:type:
 *
 * A rectangular block in a text table. The core stores a (value, type) per
 * dimension and a (width, type) per (layer, edge), plus vertical alignment and
 * background colour. The actual layout/drawing of the block is stage2.
 */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, NSTextBlockValueType) {
    NSTextBlockAbsoluteValueType = 0,
    NSTextBlockPercentageValueType = 1,
};

typedef NS_ENUM(NSUInteger, NSTextBlockDimension) {
    NSTextBlockWidth = 4,
    NSTextBlockMinimumWidth = 0,
    NSTextBlockMaximumWidth = 1,
    NSTextBlockMinimumHeight = 2,
    NSTextBlockMaximumHeight = 3,
    NSTextBlockHeight = 5,
};

typedef NS_ENUM(NSInteger, NSTextBlockLayer) {
    NSTextBlockPadding = -1,
    NSTextBlockBorder = 0,
    NSTextBlockMargin = 1,
};

typedef NS_ENUM(NSUInteger, NSTextBlockVerticalAlignment) {
    NSTextBlockTopAlignment = 0,
    NSTextBlockMiddleAlignment = 1,
    NSTextBlockBottomAlignment = 2,
    NSTextBlockBaselineAlignment = 3,
};

@interface NSTextBlock : NSObject <NSCopying>

- (void)setValue:(CGFloat)val type:(NSTextBlockValueType)type forDimension:(NSTextBlockDimension)dimension;
- (CGFloat)valueForDimension:(NSTextBlockDimension)dimension;
- (NSTextBlockValueType)valueTypeForDimension:(NSTextBlockDimension)dimension;

- (void)setContentWidth:(CGFloat)val type:(NSTextBlockValueType)type;
@property (readonly) CGFloat contentWidth;
@property (readonly) NSTextBlockValueType contentWidthValueType;

- (void)setWidth:(CGFloat)val type:(NSTextBlockValueType)type forLayer:(NSTextBlockLayer)layer edge:(NSRectEdge)edge;
- (void)setWidth:(CGFloat)val type:(NSTextBlockValueType)type forLayer:(NSTextBlockLayer)layer;
- (CGFloat)widthForLayer:(NSTextBlockLayer)layer edge:(NSRectEdge)edge;
- (NSTextBlockValueType)widthValueTypeForLayer:(NSTextBlockLayer)layer edge:(NSRectEdge)edge;

@property NSTextBlockVerticalAlignment verticalAlignment;
@property (nullable, copy) id backgroundColor;   /* NSColor */

@end

NS_ASSUME_NONNULL_END
