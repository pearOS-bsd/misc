/*
 * NSCollectionLayoutDimension.h — 1:1 reimplementation (behavioral core) of
 * AppKit's NSCollectionLayoutDimension, a compositional-layout size dimension
 * (fractional/absolute/estimated).
 *
 * Interface evidence (runtime measurement against real AppKit, macOS 27 build
 * 26A5416b, arm64e — the class is not emitted in the dyld --objc slices) in
 * evidence/-NSCollectionLayoutDimension_interface.txt.
 *
 * This core reproduces the four factory kinds, the mutually-exclusive kind
 * flags and the stored value. Fully standalone (no layout engine needed).
 */

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSCollectionLayoutDimension : NSObject <NSCopying>

+ (instancetype)fractionalWidthDimension:(CGFloat)fractionalWidth;
+ (instancetype)fractionalHeightDimension:(CGFloat)fractionalHeight;
+ (instancetype)absoluteDimension:(CGFloat)absoluteDimension;
+ (instancetype)estimatedDimension:(CGFloat)estimatedDimension;

@property (readonly) BOOL isFractionalWidth;
@property (readonly) BOOL isFractionalHeight;
@property (readonly) BOOL isAbsolute;
@property (readonly) BOOL isEstimated;
@property (readonly) CGFloat dimension;

@end

NS_ASSUME_NONNULL_END
