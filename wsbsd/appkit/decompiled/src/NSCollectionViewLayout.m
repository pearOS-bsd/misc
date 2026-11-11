/*
 * NSCollectionViewLayout.m — behavioral-1:1 abstract-base core.
 * See NSCollectionViewLayout.h for the stage2 boundary.
 */

#import "NSCollectionViewLayout.h"

@interface NSCollectionViewLayout () {
    NSMutableDictionary<NSString *, Class> *_decorationViewClassDict;
    NSMutableDictionary<NSString *, id>    *_decorationViewNibDict;
    BOOL _prepared;
}
@end

@implementation NSCollectionViewLayout {
    __weak NSCollectionView *_collectionView;
}

+ (Class)layoutAttributesClass { return [NSCollectionViewLayoutAttributes class]; }
+ (Class)invalidationContextClass
{
    /* TODO(stage2): return NSCollectionViewLayoutInvalidationContext. */
    return NSClassFromString(@"NSCollectionViewLayoutInvalidationContext");
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _decorationViewClassDict = [NSMutableDictionary dictionary];
        _decorationViewNibDict   = [NSMutableDictionary dictionary];
        _prepared = NO;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder { return [self init]; /* stage2: decode */ }
- (void)encodeWithCoder:(NSCoder *)coder { /* TODO(stage2) */ }

- (NSCollectionView *)collectionView { return _collectionView; }

/* set by the collection view when the layout is installed. */
- (void)_setCollectionView:(NSCollectionView *)cv { _collectionView = cv; }

- (BOOL)_isPrepared { return _prepared; }
- (void)_setPrepared:(BOOL)p { _prepared = p; }

/* --- invalidation --- */

- (void)invalidateLayout
{
    _prepared = NO;
    /* TODO(stage2): enqueue a layout pass on the collection view core. */
}

- (void)invalidateLayoutWithContext:(NSCollectionViewLayoutInvalidationContext *)context
{
    /* Base honours a full invalidation; targeted contexts are stage2. */
    _prepared = NO;
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(NSRect)newBounds { return NO; }

/* --- decoration-view registration (nil removes) --- */

- (void)registerClass:(Class)viewClass forDecorationViewOfKind:(NSCollectionViewDecorationElementKind)kind
{
    if (!kind) return;
    if (viewClass) {
        _decorationViewClassDict[kind] = viewClass;
        [_decorationViewNibDict removeObjectForKey:kind];
    } else {
        [_decorationViewClassDict removeObjectForKey:kind];
    }
}

- (void)registerNib:(id)nib forDecorationViewOfKind:(NSCollectionViewDecorationElementKind)kind
{
    if (!kind) return;
    if (nib) {
        _decorationViewNibDict[kind] = nib;
        [_decorationViewClassDict removeObjectForKey:kind];
    } else {
        [_decorationViewNibDict removeObjectForKey:kind];
    }
}

- (Class)_decorationViewClassForKind:(NSString *)kind { return _decorationViewClassDict[kind]; }
- (id)_decorationViewNibForKind:(NSString *)kind { return _decorationViewNibDict[kind]; }

/* --- subclass override points: base returns empty/nil/zero --- */

- (void)prepareLayout { /* base no-op; subclasses build their layout here */ }
- (NSSize)collectionViewContentSize { return NSZeroSize; }
- (NSArray<NSCollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect:(NSRect)rect { return @[]; }
- (NSCollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath { return nil; }
- (NSCollectionViewLayoutAttributes *)layoutAttributesForSupplementaryViewOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath { return nil; }
- (NSCollectionViewLayoutAttributes *)layoutAttributesForDecorationViewOfKind:(NSCollectionViewDecorationElementKind)elementKind atIndexPath:(NSIndexPath *)indexPath { return nil; }

@end
