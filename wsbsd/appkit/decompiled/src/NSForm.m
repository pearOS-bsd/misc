/*
 * NSForm.m — behavioral-1:1 entry-management core over NSMatrix. See NSForm.h.
 */

#import "NSForm.h"

@implementation NSForm

- (instancetype)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.cellClass = [NSFormCell class];   /* NSForm rows are NSFormCells */
        self.mode = NSListModeMatrix;
    }
    return self;
}

- (NSFormCell *)addEntry:(NSString *)title
{
    return [self insertEntry:title atIndex:self.numberOfRows];
}

- (NSFormCell *)insertEntry:(NSString *)title atIndex:(NSInteger)index
{
    [self insertRow:index];
    NSFormCell *cell = (NSFormCell *)[self cellAtRow:index column:0];
    [cell setTitle:title ?: @""];
    return cell;
}

- (void)removeEntryAtIndex:(NSInteger)index { [self removeRow:index]; }

- (NSFormCell *)cellAtIndex:(NSInteger)index { return (NSFormCell *)[self cellAtRow:index column:0]; }

- (NSInteger)indexOfCellWithTag:(NSInteger)tag
{
    for (NSInteger r = 0; r < self.numberOfRows; r++) {
        NSFormCell *c = [self cellAtIndex:r];
        if (c && c.tag == tag) return r;
    }
    return -1;
}

- (NSInteger)indexOfSelectedItem { return self.selectedRow; }

/* --- bulk setters fan out to every form cell --- */

- (void)_forEachCell:(void (^)(NSFormCell *cell))block
{
    for (NSInteger r = 0; r < self.numberOfRows; r++) {
        NSFormCell *c = [self cellAtIndex:r];
        if (c) block(c);
    }
}

- (void)setTitleAlignment:(NSTextAlignment)a { [self _forEachCell:^(NSFormCell *c){ c.titleAlignment = a; }]; }
- (void)setTitleFont:(NSFont *)f { [self _forEachCell:^(NSFormCell *c){ c.titleFont = f; }]; }
- (void)setTitleBaseWritingDirection:(NSWritingDirection)d { [self _forEachCell:^(NSFormCell *c){ c.titleBaseWritingDirection = d; }]; }
- (void)setBezeled:(BOOL)flag { [self _forEachCell:^(NSFormCell *c){ c.bezeled = flag; }]; }
- (void)setBordered:(BOOL)flag { [self _forEachCell:^(NSFormCell *c){ c.bordered = flag; }]; }

/* The editable-text portion's alignment/font/direction live in NSCell's
 * _contents/formatter tree, which our NSCell core does not yet model, so these
 * fan-outs are TODO(stage2). */
- (void)setTextAlignment:(NSTextAlignment)a { /* TODO(stage2) */ }
- (void)setTextFont:(NSFont *)f { /* TODO(stage2) */ }
- (void)setTextBaseWritingDirection:(NSWritingDirection)d { /* TODO(stage2) */ }

- (void)setEntryWidth:(CGFloat)width
{
    NSSize s = self.cellSize; s.width = width; self.cellSize = s;   /* stage2: relayout */
}

- (void)setPreferredTextFieldWidth:(CGFloat)w { [self _forEachCell:^(NSFormCell *c){ c.preferredTextFieldWidth = w; }]; }
- (CGFloat)preferredTextFieldWidth { NSFormCell *c = [self cellAtIndex:0]; return c ? c.preferredTextFieldWidth : -1; }

- (void)selectTextAtIndex:(NSInteger)index
{
    [self selectCellAtRow:index column:0];
    /* TODO(stage2): begin editing the entry's text with the window field editor. */
}

@end
