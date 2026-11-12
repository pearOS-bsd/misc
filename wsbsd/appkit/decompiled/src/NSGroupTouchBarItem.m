/*
 * NSGroupTouchBarItem.m — behavioral-1:1 core. See NSGroupTouchBarItem.h.
 */

#import "NSGroupTouchBarItem.h"
#import "NSTouchBar.h"

@implementation NSGroupTouchBarItem {
    NSTouchBar *_groupTouchBar;
    NSString *_customizationLabel;
    NSUserInterfaceLayoutDirection _groupUserInterfaceLayoutDirection;
    BOOL _prefersEqualWidths;
    CGFloat _preferredItemWidth;
    BOOL _groupHasAlertStyle;
    NSArray *_prioritizedCompressionOptions;
}

- (instancetype)initWithIdentifier:(NSString *)identifier
{
    self = [super initWithIdentifier:identifier];
    if (self) {
        _groupTouchBar = [[NSTouchBar alloc] init];   /* measured: auto-created */
        _customizationLabel = @"";
        _groupUserInterfaceLayoutDirection = NSUserInterfaceLayoutDirectionLeftToRight;
        _prefersEqualWidths = NO;
        _preferredItemWidth = -1;
        _prioritizedCompressionOptions = @[];
    }
    return self;
}

+ (instancetype)groupItemWithIdentifier:(NSString *)identifier items:(NSArray<NSTouchBarItem *> *)items allowedCompressionOptions:(NSUserInterfaceCompressionOptions *)allowed
{
    NSGroupTouchBarItem *g = [[self alloc] initWithIdentifier:identifier];
    /* Expose the contained items by identifier on the nested touch bar.
     * TODO(stage2): make the group's touch bar vend the item objects. */
    NSMutableArray *ids = [NSMutableArray array];
    for (NSTouchBarItem *it in items) if (it.identifier) [ids addObject:it.identifier];
    g.groupTouchBar.defaultItemIdentifiers = ids;
    if (allowed) g.prioritizedCompressionOptions = @[allowed];
    return g;
}

+ (instancetype)groupItemWithIdentifier:(NSString *)identifier items:(NSArray<NSTouchBarItem *> *)items
{ return [self groupItemWithIdentifier:identifier items:items allowedCompressionOptions:nil]; }

+ (instancetype)alertStyleGroupItemWithIdentifier:(NSString *)identifier
{
    NSGroupTouchBarItem *g = [[self alloc] initWithIdentifier:identifier];
    g->_groupHasAlertStyle = YES;
    return g;
}

- (NSTouchBar *)groupTouchBar { return _groupTouchBar; }
- (void)setGroupTouchBar:(NSTouchBar *)b { _groupTouchBar = b; }
- (NSString *)customizationLabel { return _customizationLabel; }
- (void)setCustomizationLabel:(NSString *)s { _customizationLabel = [s copy] ?: @""; }
- (NSUserInterfaceLayoutDirection)groupUserInterfaceLayoutDirection { return _groupUserInterfaceLayoutDirection; }
- (void)setGroupUserInterfaceLayoutDirection:(NSUserInterfaceLayoutDirection)d { _groupUserInterfaceLayoutDirection = d; }
- (BOOL)prefersEqualWidths { return _prefersEqualWidths; }
- (void)setPrefersEqualWidths:(BOOL)v { _prefersEqualWidths = v; }
- (CGFloat)preferredItemWidth { return _preferredItemWidth; }
- (void)setPreferredItemWidth:(CGFloat)w { _preferredItemWidth = w; }
- (BOOL)groupHasAlertStyle { return _groupHasAlertStyle; }
- (void)setGroupHasAlertStyle:(BOOL)v { _groupHasAlertStyle = v; }
- (NSArray *)prioritizedCompressionOptions { return _prioritizedCompressionOptions; }
- (void)setPrioritizedCompressionOptions:(NSArray *)a { _prioritizedCompressionOptions = [a copy] ?: @[]; }

@end
