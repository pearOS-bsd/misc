/*
 * NSCollectionViewFlowLayout.m — behavioral-1:1 config core.
 * See NSCollectionViewFlowLayout.h for the stage2 boundary.
 */

#import "NSCollectionViewFlowLayout.h"

@implementation NSCollectionViewFlowLayout {
    CGFloat      _minimumLineSpacing;
    CGFloat      _minimumInteritemSpacing;
    NSSize       _itemSize;
    NSSize       _estimatedItemSize;
    NSCollectionViewScrollDirection _scrollDirection;
    NSSize       _headerReferenceSize;
    NSSize       _footerReferenceSize;
    NSEdgeInsets _sectionInset;
    BOOL         _sectionHeadersPinToVisibleBounds;
    BOOL         _sectionFootersPinToVisibleBounds;
    NSMutableIndexSet *_collapsedSectionIndexes;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _minimumLineSpacing      = 10.0;
        _minimumInteritemSpacing = 10.0;
        _itemSize                = NSMakeSize(50.0, 50.0);
        _estimatedItemSize       = NSZeroSize;
        _scrollDirection         = NSCollectionViewScrollDirectionVertical;
        _headerReferenceSize     = NSZeroSize;
        _footerReferenceSize     = NSZeroSize;
        _sectionInset            = NSEdgeInsetsZero;
        _sectionHeadersPinToVisibleBounds = NO;
        _sectionFootersPinToVisibleBounds = NO;
        _collapsedSectionIndexes = [NSMutableIndexSet indexSet];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder { return [self init]; /* stage2: decode */ }

/* --- config value model; each setter invalidates the cached layout --- */

#define FLOW_SCALAR(getter, setter, ivar, type) \
    - (type)getter { return ivar; } \
    - (void)setter:(type)v { if (ivar != v) { ivar = v; [self invalidateLayout]; } }

FLOW_SCALAR(minimumLineSpacing, setMinimumLineSpacing, _minimumLineSpacing, CGFloat)
FLOW_SCALAR(minimumInteritemSpacing, setMinimumInteritemSpacing, _minimumInteritemSpacing, CGFloat)
FLOW_SCALAR(scrollDirection, setScrollDirection, _scrollDirection, NSCollectionViewScrollDirection)
FLOW_SCALAR(sectionHeadersPinToVisibleBounds, setSectionHeadersPinToVisibleBounds, _sectionHeadersPinToVisibleBounds, BOOL)
FLOW_SCALAR(sectionFootersPinToVisibleBounds, setSectionFootersPinToVisibleBounds, _sectionFootersPinToVisibleBounds, BOOL)

#define FLOW_SIZE(getter, setter, ivar) \
    - (NSSize)getter { return ivar; } \
    - (void)setter:(NSSize)v { if (!NSEqualSizes(ivar, v)) { ivar = v; [self invalidateLayout]; } }

FLOW_SIZE(itemSize, setItemSize, _itemSize)
FLOW_SIZE(estimatedItemSize, setEstimatedItemSize, _estimatedItemSize)
FLOW_SIZE(headerReferenceSize, setHeaderReferenceSize, _headerReferenceSize)
FLOW_SIZE(footerReferenceSize, setFooterReferenceSize, _footerReferenceSize)

- (NSEdgeInsets)sectionInset { return _sectionInset; }
- (void)setSectionInset:(NSEdgeInsets)v
{
    if (v.top != _sectionInset.top || v.left != _sectionInset.left ||
        v.bottom != _sectionInset.bottom || v.right != _sectionInset.right) {
        _sectionInset = v;
        [self invalidateLayout];
    }
}

/* --- collapse / expand bookkeeping --- */

- (void)collapseSectionAtIndex:(NSInteger)index
{
    if (index < 0 || [_collapsedSectionIndexes containsIndex:(NSUInteger)index]) return;
    [_collapsedSectionIndexes addIndex:(NSUInteger)index];
    [self invalidateLayout];
    /* TODO(stage2): collapse scroll offsets + collapse-button visuals. */
}

- (void)expandSectionAtIndex:(NSInteger)index
{
    if (index < 0 || ![_collapsedSectionIndexes containsIndex:(NSUInteger)index]) return;
    [_collapsedSectionIndexes removeIndex:(NSUInteger)index];
    [self invalidateLayout];
}

- (BOOL)sectionAtIndexIsCollapsed:(NSUInteger)sectionIndex
{
    return [_collapsedSectionIndexes containsIndex:sectionIndex];
}

@end
