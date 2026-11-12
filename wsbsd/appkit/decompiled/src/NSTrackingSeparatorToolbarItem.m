/*
 * NSTrackingSeparatorToolbarItem.m — behavioral-1:1 core. See the header.
 */

#import "NSTrackingSeparatorToolbarItem.h"

@implementation NSTrackingSeparatorToolbarItem {
    NSSplitView *_splitView;
    NSInteger _dividerIndex;
}

+ (instancetype)trackingSeparatorToolbarItemWithIdentifier:(NSString *)identifier
                                                 splitView:(NSSplitView *)splitView
                                              dividerIndex:(NSInteger)dividerIndex
{
    NSTrackingSeparatorToolbarItem *item = [[self alloc] initWithItemIdentifier:identifier];
    item->_splitView = splitView;
    item->_dividerIndex = dividerIndex;
    /* TODO(stage2): observe the split view's divider position and keep the
       toolbar divider aligned (alignmentSatisfied bookkeeping). */
    return item;
}

- (instancetype)initWithItemIdentifier:(NSString *)itemIdentifier
{
    self = [super initWithItemIdentifier:itemIdentifier];
    if (self) {
        _dividerIndex = 0;   /* measured */
    }
    return self;
}

- (NSSplitView *)splitView { return _splitView; }
- (void)setSplitView:(NSSplitView *)v { _splitView = v; }
- (NSInteger)dividerIndex { return _dividerIndex; }
- (void)setDividerIndex:(NSInteger)i { _dividerIndex = i; }

@end
