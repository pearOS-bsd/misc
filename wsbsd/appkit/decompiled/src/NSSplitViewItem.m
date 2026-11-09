/*
 * NSSplitViewItem.m — 1:1 (core). See NSSplitViewItem.h for interface evidence.
 *
 * +splitViewItemWithViewController: builds a Default-behavior item whose holding
 * priority defaults to NSLayoutPriorityDefaultLow (250) and whose thickness
 * bounds default to NSSplitViewItemUnspecifiedDimension (-1). collapsed and
 * canCollapse are _flags bits (canCollapse defaults YES). The sidebar/content-
 * list factories, animated collapse and accessories are stage2.
 */
#import "NSSplitViewItem.h"

@implementation NSSplitViewItem {
    NSViewController *_viewController;
    BOOL _collapsed;          /* _flags b0 */
    BOOL _canCollapse;        /* _flags b1 */
    CGFloat _holdingPriority;
    CGFloat _minimumThickness;
    CGFloat _maximumThickness;
    NSSplitViewItemBehavior _behavior;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _holdingPriority = 250.0;   /* NSLayoutPriorityDefaultLow */
        _minimumThickness = NSSplitViewItemUnspecifiedDimension;
        _maximumThickness = NSSplitViewItemUnspecifiedDimension;
        _canCollapse = YES;
        _behavior = NSSplitViewItemBehaviorDefault;
    }
    return self;
}

+ (instancetype)splitViewItemWithViewController:(NSViewController *)viewController
{
    NSSplitViewItem *item = [[self alloc] init];
    item->_viewController = viewController;
    return item;
}

- (NSViewController *)viewController { return _viewController; }
- (void)setViewController:(NSViewController *)v { _viewController = v; }
- (BOOL)isCollapsed { return _collapsed; }
- (void)setCollapsed:(BOOL)v { _collapsed = v; }
- (BOOL)canCollapse { return _canCollapse; }
- (void)setCanCollapse:(BOOL)v { _canCollapse = v; }
- (CGFloat)holdingPriority { return _holdingPriority; }
- (void)setHoldingPriority:(CGFloat)v { _holdingPriority = v; }
- (CGFloat)minimumThickness { return _minimumThickness; }
- (void)setMinimumThickness:(CGFloat)v { _minimumThickness = v; }
- (CGFloat)maximumThickness { return _maximumThickness; }
- (void)setMaximumThickness:(CGFloat)v { _maximumThickness = v; }
- (NSSplitViewItemBehavior)behavior { return _behavior; }

@end
