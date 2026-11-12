/*
 * NSTextRange.h — 1:1 reimplementation (behavioral core) of AppKit/TextKit 2's
 * NSTextRange and the NSTextLocation protocol.
 *
 * Interface evidence (real UIFoundation, re-exported by AppKit.framework,
 * macOS 27 build 26A5416b, arm64e) in evidence/-NSTextRange_interface.txt.
 * Real ivars: _location, _endLocation (both id<NSTextLocation>).
 *
 * A text range is a half-open interval [location, endLocation) over abstract
 * locations that compare via -compare:. This core reproduces the measured
 * geometry: isEmpty (location==endLocation), containsLocation: (start<=loc<end),
 * containsRange:, intersectsWithTextRange: (positive-length overlap),
 * union/intersection (intersection is nil when disjoint), equality. The
 * document-backed -textRangeWithAdjustment:rangeProvider: traversal is
 * TODO(stage2).
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol NSTextLocation <NSObject>
- (NSComparisonResult)compare:(id<NSTextLocation>)location;
@end

@interface NSTextRange : NSObject

- (instancetype)initWithLocation:(id<NSTextLocation>)location endLocation:(nullable id<NSTextLocation>)endLocation;
- (instancetype)initWithLocation:(id<NSTextLocation>)location;

@property (readonly, getter=isEmpty) BOOL empty;
@property (readonly) id<NSTextLocation> location;
@property (readonly) id<NSTextLocation> endLocation;

- (BOOL)isEqualToTextRange:(NSTextRange *)textRange;
- (BOOL)containsLocation:(id<NSTextLocation>)location;
- (BOOL)containsRange:(NSTextRange *)textRange;
- (BOOL)intersectsWithTextRange:(NSTextRange *)textRange;

- (nullable NSTextRange *)textRangeByFormingUnionWithTextRange:(NSTextRange *)textRange;
- (nullable NSTextRange *)textRangeByIntersectingWithTextRange:(NSTextRange *)textRange;

@end

NS_ASSUME_NONNULL_END
