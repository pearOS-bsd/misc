/*
 * NSTouchBar.h — 1:1 reimplementation (core). NSObject <NSCoding>.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSTouchBar : NSObject <NSAnimatablePropertyContainer, NSCoding> {
 *       @ _configuration;  @"NSString" _principalItemIdentifier;
 *       @"NSSet" _templateItems;  @"<NSTouchBarDelegate>" _delegate;
 *       @"NSMutableDictionary" _itemCache;  …
 *   }
 *   -defaultItemIdentifiers -setDefaultItemIdentifiers: -principalItemIdentifier
 *   -setPrincipalItemIdentifier: -itemForIdentifier: -delegate -setDelegate:
 *   -customizationIdentifier -itemIdentifiers
 *
 * A set of touch-bar items keyed by identifier. itemForIdentifier: returns a
 * cached item or asks the delegate to make one and caches it. The customization
 * palette, template items and the DFR presentation are stage2.
 */
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSString * NSTouchBarItemIdentifier NS_EXTENSIBLE_STRING_ENUM;
@class NSTouchBar, NSTouchBarItem;

@protocol NSTouchBarDelegate <NSObject>
@optional
- (nullable NSTouchBarItem *)touchBar:(NSTouchBar *)touchBar
                makeItemForIdentifier:(NSTouchBarItemIdentifier)identifier;
@end

@interface NSTouchBar : NSObject

@property (nullable, weak) id<NSTouchBarDelegate> delegate;
@property (copy) NSArray<NSTouchBarItemIdentifier> *defaultItemIdentifiers;
@property (nullable, copy) NSTouchBarItemIdentifier principalItemIdentifier;
@property (nullable, copy) NSString *customizationIdentifier;
@property (readonly, copy) NSArray<NSTouchBarItemIdentifier> *itemIdentifiers;

- (nullable NSTouchBarItem *)itemForIdentifier:(NSTouchBarItemIdentifier)identifier;

@end

NS_ASSUME_NONNULL_END
