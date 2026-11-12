/*
 * NSCollectionView.m — behavioral-1:1 core. See the header.
 */

#import "NSCollectionView.h"

@implementation NSCollectionView {
    __weak id<NSCollectionViewDataSource> _dataSource;
    __weak id _delegate;
    NSCollectionViewLayout *_collectionViewLayout;
    BOOL _selectable;
    BOOL _allowsMultipleSelection;
    BOOL _allowsEmptySelection;
    NSArray<NSColor *> *_backgroundColors;
    NSSet<NSIndexPath *> *_selectionIndexPaths;
}

- (instancetype)initWithFrame:(CGRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        _allowsEmptySelection = YES;   /* measured */
        _selectionIndexPaths = [NSSet set];
        _backgroundColors = @[];   /* real default holds 1 system background color (NSColor/stage2) */
        /* selectable=NO, allowsMultipleSelection=NO (measured) */
    }
    return self;
}

- (id<NSCollectionViewDataSource>)dataSource { return _dataSource; }
- (void)setDataSource:(id<NSCollectionViewDataSource>)d { _dataSource = d; }
- (id)delegate { return _delegate; }
- (void)setDelegate:(id)d { _delegate = d; }
- (NSCollectionViewLayout *)collectionViewLayout { return _collectionViewLayout; }
- (void)setCollectionViewLayout:(NSCollectionViewLayout *)l { _collectionViewLayout = l; }
- (BOOL)isSelectable { return _selectable; }
- (void)setSelectable:(BOOL)v { _selectable = v; }
- (BOOL)allowsMultipleSelection { return _allowsMultipleSelection; }
- (void)setAllowsMultipleSelection:(BOOL)v { _allowsMultipleSelection = v; }
- (BOOL)allowsEmptySelection { return _allowsEmptySelection; }
- (void)setAllowsEmptySelection:(BOOL)v { _allowsEmptySelection = v; }
- (NSArray<NSColor *> *)backgroundColors { return _backgroundColors; }
- (void)setBackgroundColors:(NSArray<NSColor *> *)c { _backgroundColors = [c copy] ?: @[]; }
- (NSSet<NSIndexPath *> *)selectionIndexPaths { return _selectionIndexPaths; }
- (void)setSelectionIndexPaths:(NSSet<NSIndexPath *> *)s { _selectionIndexPaths = [s copy] ?: [NSSet set]; }

- (NSInteger)numberOfSections
{
    if ([_dataSource respondsToSelector:@selector(numberOfSectionsInCollectionView:)])
        return [_dataSource numberOfSectionsInCollectionView:self];
    return 1;   /* measured default with no data source */
}

- (NSInteger)numberOfItemsInSection:(NSInteger)section
{
    if ([_dataSource respondsToSelector:@selector(collectionView:numberOfItemsInSection:)])
        return [_dataSource collectionView:self numberOfItemsInSection:section];
    return 0;
}

- (void)reloadData { /* TODO(stage2): rebuild item views from the data source + layout */ }

@end
