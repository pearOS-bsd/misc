/*
 * NSStatusBar.m — 1:1 (core). Evidence ../evidence/statusbar:
 * systemStatusBar 0x18510ae40 (cached singleton), thickness 0x18575e1ec
 * (constant 20.0), isVertical 0x18510d814 (NO), statusItemWithLength: 0x18510b054
 * (builds an NSStatusItem, priority 1000).
 */
#import "NSStatusBar.h"

static NSStatusBar *sSystemStatusBar = nil;

@implementation NSStatusBar {
    NSMutableArray<NSStatusItem *> *_items;
}

+ (NSStatusBar *)systemStatusBar
{
    if (!sSystemStatusBar) sSystemStatusBar = [[self alloc] init];
    return sSystemStatusBar;
}

- (instancetype)init
{
    self = [super init];
    if (self) _items = [NSMutableArray array];
    return self;
}

- (CGFloat)thickness { return 20.0; }   /* constant */
- (BOOL)isVertical { return NO; }

- (NSStatusItem *)statusItemWithLength:(CGFloat)length
{
    NSStatusItem *item = [[NSStatusItem alloc] init];
    item.length = length;
    [_items addObject:item];     /* the status bar retains its items */
    return item;
}

- (void)removeStatusItem:(NSStatusItem *)item
{
    NSUInteger idx = [_items indexOfObjectIdenticalTo:item];
    if (idx != NSNotFound) [_items removeObjectAtIndex:idx];
}

@end
