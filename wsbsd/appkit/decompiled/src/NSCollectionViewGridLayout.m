/*
 * NSCollectionViewGridLayout.m — behavioral-1:1 config core.
 * See NSCollectionViewGridLayout.h (defaults measured on this Mac).
 */

#import "NSCollectionViewGridLayout.h"

@implementation NSCollectionViewGridLayout {
    NSUInteger   _maxGridRows;
    NSUInteger   _maxGridColumns;
    NSSize       _minItemSize;
    NSSize       _maxItemSize;
    NSEdgeInsets _margins;
    CGFloat      _minimumInteritemSpacing;
    CGFloat      _minimumLineSpacing;
    NSArray     *_backgroundColors;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _maxGridRows = 0;
        _maxGridColumns = 0;
        _minItemSize = NSZeroSize;
        _maxItemSize = NSZeroSize;
        _margins = NSEdgeInsetsZero;
        _minimumInteritemSpacing = 0.0;
        _minimumLineSpacing = 0.0;
        _backgroundColors = @[];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder { return [self init]; /* stage2: decode */ }

#define GRID_SET(getter, setter, ivar, type, neq) \
    - (type)getter { return ivar; } \
    - (void)setter:(type)v { if (neq) { ivar = v; [self invalidateLayout]; } }

GRID_SET(maximumNumberOfRows, setMaximumNumberOfRows, _maxGridRows, NSUInteger, _maxGridRows != v)
GRID_SET(maximumNumberOfColumns, setMaximumNumberOfColumns, _maxGridColumns, NSUInteger, _maxGridColumns != v)
GRID_SET(minimumInteritemSpacing, setMinimumInteritemSpacing, _minimumInteritemSpacing, CGFloat, _minimumInteritemSpacing != v)
GRID_SET(minimumLineSpacing, setMinimumLineSpacing, _minimumLineSpacing, CGFloat, _minimumLineSpacing != v)
GRID_SET(minimumItemSize, setMinimumItemSize, _minItemSize, NSSize, !NSEqualSizes(_minItemSize, v))
GRID_SET(maximumItemSize, setMaximumItemSize, _maxItemSize, NSSize, !NSEqualSizes(_maxItemSize, v))

- (NSEdgeInsets)margins { return _margins; }
- (void)setMargins:(NSEdgeInsets)v
{
    if (v.top != _margins.top || v.left != _margins.left ||
        v.bottom != _margins.bottom || v.right != _margins.right) {
        _margins = v;
        [self invalidateLayout];
    }
}

- (NSArray *)backgroundColors { return _backgroundColors; }
- (void)setBackgroundColors:(NSArray *)v
{
    _backgroundColors = [v copy] ?: @[];
    [self invalidateLayout];
}

@end
