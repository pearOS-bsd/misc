/*
 * NSIndexPath.h — 1:1 reimplementation (behavioral core) of Foundation's
 * NSIndexPath, an immutable ordered list of NSUInteger indexes.
 *
 * Interface evidence (real Foundation, macOS 27 build 26A5416b, arm64e) in
 * evidence/-NSIndexPath_interface.txt. Standalone; no CoreFoundation bridge.
 */

#import <Foundation/NSObject.h>
#import <Foundation/NSRange.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSIndexPath : NSObject <NSCopying, NSSecureCoding>

+ (instancetype)indexPathWithIndex:(NSUInteger)index;
+ (instancetype)indexPathWithIndexes:(const NSUInteger *)indexes length:(NSUInteger)length;
- (instancetype)initWithIndex:(NSUInteger)index;
- (instancetype)initWithIndexes:(const NSUInteger *)indexes length:(NSUInteger)length;

@property (readonly) NSUInteger length;
- (NSUInteger)indexAtPosition:(NSUInteger)position;
- (void)getIndexes:(NSUInteger *)indexes range:(NSRange)positionRange;

- (NSIndexPath *)indexPathByAddingIndex:(NSUInteger)index;
- (NSIndexPath *)indexPathByRemovingLastIndex;

- (NSComparisonResult)compare:(NSIndexPath *)otherObject;

@end

NS_ASSUME_NONNULL_END
