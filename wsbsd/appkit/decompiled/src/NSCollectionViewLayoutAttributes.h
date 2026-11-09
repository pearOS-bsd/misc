/*
 * NSCollectionViewLayoutAttributes.h — 1:1 reimplementation (core).
 * NSObject <NSCopying>.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSCollectionViewLayoutAttributes : NSObject <NSCopying> {
 *       {CGPoint} _center;  {CGSize} _size;  {CGRect} _frame;  d _alpha;
 *       {CATransform3D} _transform;  @"NSIndexPath" _indexPath;
 *       {?="…isHidden"b1…} _layoutFlags;  q _zIndex;
 *   }
 *   +layoutAttributesForItemWithIndexPath: -frame -setFrame: -bounds -setBounds:
 *   -center -setCenter: -size -setSize: -alpha -zIndex -isHidden -indexPath
 *
 * Positioning info for one collection-view element. frame is the source of
 * truth; center/bounds/size are derived (frame = {center − size/2, size}).
 * The 3D transform and the decoration/supplementary/gap element kinds are stage2.
 */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSCollectionViewLayoutAttributes : NSObject <NSCopying>

+ (instancetype)layoutAttributesForItemWithIndexPath:(NSIndexPath *)indexPath;

@property CGRect frame;
@property CGRect bounds;
@property CGPoint center;
@property CGSize size;
@property CGFloat alpha;
@property NSInteger zIndex;
@property (getter=isHidden) BOOL hidden;
@property (getter=isFloating) BOOL floating;
@property (nullable, strong) NSIndexPath *indexPath;

@end

NS_ASSUME_NONNULL_END
