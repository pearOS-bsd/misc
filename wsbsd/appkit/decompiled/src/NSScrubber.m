/*
 * NSScrubber.m — behavioral-1:1 data/selection core. See NSScrubber.h.
 */

#import "NSScrubber.h"

@implementation NSScrubber {
    __weak id<NSScrubberDataSource> _dataSource;
    __weak id<NSScrubberDelegate> _delegate;
    NSScrubberLayout *_scrubberLayout;
    NSInteger _numberOfItems;
    NSInteger _highlightedIndex;
    NSInteger _selectedIndex;
    NSInteger _tag;
    NSScrubberMode _mode;
    NSScrubberAlignment _itemAlignment;
    BOOL _continuous, _floatsSelectionViews, _showsArrowButtons, _showsAdditionalContentIndicators;
    NSColor *_backgroundColor;
    NSView *_backgroundView;
    NSScrubberSelectionStyle *_selectionBackgroundStyle, *_selectionOverlayStyle;
}

- (instancetype)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _numberOfItems = 0;
        _highlightedIndex = -1;
        _selectedIndex = -1;            /* measured */
        _mode = NSScrubberModeFixed;
        _itemAlignment = NSScrubberAlignmentNone;
        /* backgroundColor defaults to semantic controlBackgroundColor = stage2 */
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder { return [self initWithFrame:NSZeroRect]; }

- (id<NSScrubberDataSource>)dataSource { return _dataSource; }
- (void)setDataSource:(id<NSScrubberDataSource>)d { _dataSource = d; [self reloadData]; }
- (id<NSScrubberDelegate>)delegate { return _delegate; }
- (void)setDelegate:(id<NSScrubberDelegate>)d { _delegate = d; }
- (NSScrubberLayout *)scrubberLayout { return _scrubberLayout; }
- (void)setScrubberLayout:(NSScrubberLayout *)l { _scrubberLayout = l; }

- (NSInteger)numberOfItems { return _numberOfItems; }
- (NSInteger)highlightedIndex { return _highlightedIndex; }

- (NSInteger)selectedIndex { return _selectedIndex; }
- (void)setSelectedIndex:(NSInteger)index
{
    if (index < -1) index = -1;
    if (index >= _numberOfItems) index = _numberOfItems - 1;
    if (index == _selectedIndex) return;
    _selectedIndex = index;
    if (index >= 0 && [_delegate respondsToSelector:@selector(scrubber:didSelectItemAtIndex:)])
        [_delegate scrubber:self didSelectItemAtIndex:index];
}

- (NSInteger)tag { return _tag; }
- (void)setTag:(NSInteger)t { _tag = t; }
- (NSScrubberMode)mode { return _mode; }
- (void)setMode:(NSScrubberMode)m { _mode = m; }
- (NSScrubberAlignment)itemAlignment { return _itemAlignment; }
- (void)setItemAlignment:(NSScrubberAlignment)a { _itemAlignment = a; }
- (BOOL)isContinuous { return _continuous; }
- (void)setContinuous:(BOOL)v { _continuous = v; }
- (BOOL)floatsSelectionViews { return _floatsSelectionViews; }
- (void)setFloatsSelectionViews:(BOOL)v { _floatsSelectionViews = v; }
- (BOOL)showsArrowButtons { return _showsArrowButtons; }
- (void)setShowsArrowButtons:(BOOL)v { _showsArrowButtons = v; }
- (BOOL)showsAdditionalContentIndicators { return _showsAdditionalContentIndicators; }
- (void)setShowsAdditionalContentIndicators:(BOOL)v { _showsAdditionalContentIndicators = v; }
- (NSColor *)backgroundColor { return _backgroundColor; }
- (void)setBackgroundColor:(NSColor *)c { _backgroundColor = c; }
- (NSView *)backgroundView { return _backgroundView; }
- (void)setBackgroundView:(NSView *)v { _backgroundView = v; }
- (NSScrubberSelectionStyle *)selectionBackgroundStyle { return _selectionBackgroundStyle; }
- (void)setSelectionBackgroundStyle:(NSScrubberSelectionStyle *)s { _selectionBackgroundStyle = s; }
- (NSScrubberSelectionStyle *)selectionOverlayStyle { return _selectionOverlayStyle; }
- (void)setSelectionOverlayStyle:(NSScrubberSelectionStyle *)s { _selectionOverlayStyle = s; }

- (void)reloadData
{
    _numberOfItems = _dataSource ? [_dataSource numberOfItemsForScrubber:self] : 0;
    if (_selectedIndex >= _numberOfItems) _selectedIndex = _numberOfItems - 1;
    if (_numberOfItems == 0) _selectedIndex = -1;
    /* TODO(stage2): rebuild the item views through the layout + scroll view. */
}

- (NSView *)itemViewForItemAtIndex:(NSInteger)index
{
    if (index < 0 || index >= _numberOfItems || !_dataSource) return nil;
    return [_dataSource scrubber:self viewForItemAtIndex:index];  /* stage2: reuse cache */
}

- (void)scrollItemAtIndex:(NSInteger)index toAlignment:(NSScrubberAlignment)alignment
{
    /* TODO(stage2): scroll the backing NSScrollView so item `index` lands at the
     * requested alignment. */
}

@end
