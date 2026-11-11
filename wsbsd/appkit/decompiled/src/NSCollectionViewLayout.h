/*
 * NSCollectionViewLayout.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSCollectionViewLayout, the abstract base for collection-view layouts.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSCollectionViewLayout_interface.txt. The real class is enormous
 * — the vast majority of its methods are the layout engine, orthogonal-scrolling
 * sections, layout-transition animations and invalidation-context plumbing
 * (_orthogonalScrolling*, _prepareForTransition*, _animationForReusableView*,
 * targetContentOffset*, …). All of that is TODO(stage2).
 *
 * This core reproduces the *abstract base contract* a concrete subclass (and a
 * collection view) relies on: the weak collectionView back-link, decoration-view
 * class/nib registration, the `+layoutAttributesClass` hook, invalidateLayout,
 * and the override points that return empty/nil/zero in the base so subclasses
 * only override what they implement.
 */

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "NSCollectionViewLayoutAttributes.h"

NS_ASSUME_NONNULL_BEGIN

@class NSCollectionView, NSNib, NSCollectionViewLayoutInvalidationContext;
typedef NSString * NSCollectionViewDecorationElementKind;

@interface NSCollectionViewLayout : NSObject <NSCoding>

@property (nullable, weak, readonly) NSCollectionView *collectionView;

/* class hooks */
+ (Class)layoutAttributesClass;
+ (Class)invalidationContextClass;

/* invalidation */
- (void)invalidateLayout;
- (void)invalidateLayoutWithContext:(NSCollectionViewLayoutInvalidationContext *)context;
- (BOOL)shouldInvalidateLayoutForBoundsChange:(NSRect)newBounds;

/* decoration-view registration */
- (void)registerClass:(nullable Class)viewClass forDecorationViewOfKind:(NSCollectionViewDecorationElementKind)elementKind;
- (void)registerNib:(nullable NSNib *)nib forDecorationViewOfKind:(NSCollectionViewDecorationElementKind)elementKind;

/* subclass override points (base returns empty/nil/zero) */
- (void)prepareLayout;
- (NSSize)collectionViewContentSize;
- (NSArray<NSCollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect:(NSRect)rect;
- (nullable NSCollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath;
- (nullable NSCollectionViewLayoutAttributes *)layoutAttributesForSupplementaryViewOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath;
- (nullable NSCollectionViewLayoutAttributes *)layoutAttributesForDecorationViewOfKind:(NSCollectionViewDecorationElementKind)elementKind atIndexPath:(NSIndexPath *)indexPath;

@end

NS_ASSUME_NONNULL_END
