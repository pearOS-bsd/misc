/*
 * NSCollectionLayoutAnchor.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSCollectionLayoutAnchor, which anchors a supplementary item to the edges of
 * its container item in a compositional layout.
 *
 * Interface evidence (runtime measurement against real AppKit, macOS 27 build
 * 26A5416b, arm64e — class not emitted in the dyld --objc slices) in
 * evidence/-NSCollectionLayoutAnchor_interface.txt. Fully standalone.
 */

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, NSDirectionalRectEdge) {
    NSDirectionalRectEdgeNone = 0,
    NSDirectionalRectEdgeTop = 1 << 0,
    NSDirectionalRectEdgeLeading = 1 << 1,
    NSDirectionalRectEdgeBottom = 1 << 2,
    NSDirectionalRectEdgeTrailing = 1 << 3,
    NSDirectionalRectEdgeAll = NSDirectionalRectEdgeTop | NSDirectionalRectEdgeLeading | NSDirectionalRectEdgeBottom | NSDirectionalRectEdgeTrailing,
};

@interface NSCollectionLayoutAnchor : NSObject <NSCopying>

+ (instancetype)layoutAnchorWithEdges:(NSDirectionalRectEdge)edges;
+ (instancetype)layoutAnchorWithEdges:(NSDirectionalRectEdge)edges absoluteOffset:(CGPoint)absoluteOffset;
+ (instancetype)layoutAnchorWithEdges:(NSDirectionalRectEdge)edges fractionalOffset:(CGPoint)fractionalOffset;

@property (readonly) NSDirectionalRectEdge edges;
@property (readonly) CGPoint offset;
@property (readonly) BOOL isAbsoluteOffset;
@property (readonly) BOOL isFractionalOffset;

@end

NS_ASSUME_NONNULL_END
