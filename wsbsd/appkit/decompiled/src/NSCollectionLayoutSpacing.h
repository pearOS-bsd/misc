/*
 * NSCollectionLayoutSpacing.h — 1:1 reimplementation (behavioral core) of
 * AppKit's NSCollectionLayoutSpacing, a compositional-layout spacing value
 * (fixed or flexible).
 *
 * Interface evidence (runtime measurement against real AppKit, macOS 27 build
 * 26A5416b, arm64e — class not emitted in the dyld --objc slices) in
 * evidence/-NSCollectionLayoutSpacing_interface.txt. Fully standalone.
 */

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSCollectionLayoutSpacing : NSObject <NSCopying>

+ (instancetype)flexibleSpacing:(CGFloat)flexibleSpacing;
+ (instancetype)fixedSpacing:(CGFloat)fixedSpacing;

@property (readonly) CGFloat spacing;
@property (readonly) BOOL isFlexibleSpacing;
@property (readonly) BOOL isFixedSpacing;

@end

NS_ASSUME_NONNULL_END
