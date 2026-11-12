/*
 * NSCollectionLayoutDimension.m — behavioral-1:1 core. See the header.
 */

#import "NSCollectionLayoutDimension.h"

typedef NS_ENUM(NSInteger, NSCollectionLayoutDimensionKind) {
    kFractionalWidth = 0,
    kFractionalHeight = 1,
    kAbsolute = 2,
    kEstimated = 3,
};

@implementation NSCollectionLayoutDimension {
    NSCollectionLayoutDimensionKind _kind;
    CGFloat _value;
}

+ (instancetype)_dimensionWithKind:(NSCollectionLayoutDimensionKind)kind value:(CGFloat)value
{
    NSCollectionLayoutDimension *d = [[self alloc] init];
    d->_kind = kind;
    d->_value = value;
    return d;
}

+ (instancetype)fractionalWidthDimension:(CGFloat)v { return [self _dimensionWithKind:kFractionalWidth value:v]; }
+ (instancetype)fractionalHeightDimension:(CGFloat)v { return [self _dimensionWithKind:kFractionalHeight value:v]; }
+ (instancetype)absoluteDimension:(CGFloat)v { return [self _dimensionWithKind:kAbsolute value:v]; }
+ (instancetype)estimatedDimension:(CGFloat)v { return [self _dimensionWithKind:kEstimated value:v]; }

- (BOOL)isFractionalWidth { return _kind == kFractionalWidth; }
- (BOOL)isFractionalHeight { return _kind == kFractionalHeight; }
- (BOOL)isAbsolute { return _kind == kAbsolute; }
- (BOOL)isEstimated { return _kind == kEstimated; }
- (CGFloat)dimension { return _value; }

- (id)copyWithZone:(NSZone *)zone
{
    return [[self class] _dimensionWithKind:_kind value:_value];
}

@end
