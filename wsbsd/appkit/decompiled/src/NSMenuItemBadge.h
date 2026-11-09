/*
 * NSMenuItemBadge.h — 1:1 reimplementation (core). NSObject <NSCopying>.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSMenuItemBadge : NSObject <NSCopying> {
 *       B _usesPreferredLocalization;  q _itemCount;  q _type;
 *       @"NSString" _customStringValue;  @"NSString" _stringValue;
 *   }
 *   +alertsWithCount: +newItemsWithCount: +updatesWithCount: -initWithCount:
 *   -initWithString: -itemCount -type -stringValue -isEmpty
 *
 * A trailing badge on a menu item (a count or a custom string). The core stores
 * the count, the semantic type and an optional custom string; stringValue is
 * the custom string or the count rendered as a number. The localized
 * type-specific phrasing ("5 updates") is stage2.
 */
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NSMenuItemBadgeType) {
    NSMenuItemBadgeTypeNone = 0,
    NSMenuItemBadgeTypeUpdates = 1,
    NSMenuItemBadgeTypeNewItems = 2,
    NSMenuItemBadgeTypeAlerts = 3,
};

@interface NSMenuItemBadge : NSObject <NSCopying>

+ (instancetype)updatesWithCount:(NSInteger)itemCount;
+ (instancetype)newItemsWithCount:(NSInteger)itemCount;
+ (instancetype)alertsWithCount:(NSInteger)itemCount;
- (instancetype)initWithCount:(NSInteger)itemCount;
- (instancetype)initWithString:(NSString *)string;

@property (readonly) NSInteger itemCount;
@property (readonly) NSMenuItemBadgeType type;
@property (readonly, copy) NSString *stringValue;
@property (readonly, getter=isEmpty) BOOL empty;

@end

NS_ASSUME_NONNULL_END
