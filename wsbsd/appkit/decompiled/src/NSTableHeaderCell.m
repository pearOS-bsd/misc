/*
 * NSTableHeaderCell.m — behavioral-1:1 core. See the header.
 */

#import "NSTableHeaderCell.h"

static const CGFloat kIndicator = 9.0;      /* measured 9x9 */
static const CGFloat kTrailingInset = 8.0;  /* measured: x = maxX - 9 - 8 */

@implementation NSTableHeaderCell

- (instancetype)initTextCell:(NSString *)string
{
    self = [super init];
    if (self) self.stringValue = string;
    return self;
}

- (CGRect)sortIndicatorRectForBounds:(CGRect)rect
{
    CGFloat x = CGRectGetMaxX(rect) - kIndicator - kTrailingInset;
    CGFloat y = rect.origin.y + (CGFloat)floor((rect.size.height - kIndicator) / 2.0 + 0.5);
    return CGRectMake(x, y, kIndicator, kIndicator);
}

- (void)drawSortIndicatorWithFrame:(CGRect)cellFrame
                            inView:(id)controlView
                         ascending:(BOOL)ascending
                          priority:(NSInteger)priority
{
    /* TODO(stage2): draw the up/down chevron in -sortIndicatorRectForBounds:. */
}

@end
