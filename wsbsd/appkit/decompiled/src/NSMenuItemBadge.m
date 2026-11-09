/*
 * NSMenuItemBadge.m — 1:1 (core). See NSMenuItemBadge.h for the evidence.
 *
 * Stores the count, the semantic type and an optional custom string.
 * stringValue returns the custom string when set, otherwise the count as a
 * decimal number. isEmpty is true when there is no custom string and the count
 * is zero. The localized type phrasing and the badge drawing are stage2.
 */
#import "NSMenuItemBadge.h"

@implementation NSMenuItemBadge {
    NSInteger _itemCount;
    NSMenuItemBadgeType _type;
    NSString *_customStringValue;
}

- (instancetype)initWithCount:(NSInteger)itemCount
{
    self = [super init];
    if (self) { _itemCount = itemCount; _type = NSMenuItemBadgeTypeNone; }
    return self;
}
- (instancetype)initWithString:(NSString *)string
{
    self = [super init];
    if (self) { _customStringValue = [string copy]; _type = NSMenuItemBadgeTypeNone; }
    return self;
}

+ (instancetype)updatesWithCount:(NSInteger)c
{ NSMenuItemBadge *b = [[self alloc] initWithCount:c]; b->_type = NSMenuItemBadgeTypeUpdates; return b; }
+ (instancetype)newItemsWithCount:(NSInteger)c
{ NSMenuItemBadge *b = [[self alloc] initWithCount:c]; b->_type = NSMenuItemBadgeTypeNewItems; return b; }
+ (instancetype)alertsWithCount:(NSInteger)c
{ NSMenuItemBadge *b = [[self alloc] initWithCount:c]; b->_type = NSMenuItemBadgeTypeAlerts; return b; }

- (NSInteger)itemCount { return _itemCount; }
- (NSMenuItemBadgeType)type { return _type; }
- (NSString *)stringValue
{
    if (_customStringValue) return _customStringValue;
    return [NSString stringWithFormat:@"%ld", (long)_itemCount];  /* stage2: localized phrasing */
}
- (BOOL)isEmpty { return _customStringValue.length == 0 && _itemCount == 0; }

- (id)copyWithZone:(NSZone *)zone
{
    NSMenuItemBadge *b = [[NSMenuItemBadge alloc] initWithCount:_itemCount];
    b->_type = _type; b->_customStringValue = [_customStringValue copy];
    return b;
}

@end
