/*
 * NSTableHeaderView.m — behavioral-1:1 core. See the header.
 */

#import "NSTableHeaderView.h"

@implementation NSTableHeaderView {
    __weak NSTableView *_tableView;
}

- (NSTableView *)tableView { return _tableView; }
- (void)setTableView:(NSTableView *)t { _tableView = t; }

- (NSInteger)draggedColumn { return -1; }    /* -1 when not dragging (measured) */
- (CGFloat)draggedDistance { return 0.0; }
- (NSInteger)resizedColumn { return -1; }    /* -1 when not resizing (measured) */

- (NSInteger)columnAtPoint:(CGPoint)point
{
    /* TODO(stage2): hit-test against the table's column rects. */
    return -1;
}

- (CGRect)headerRectOfColumn:(NSInteger)column
{
    /* TODO(stage2): rect from the table's column layout. */
    return CGRectZero;
}

@end
