/*
 * NSTouchBar.m — 1:1 (core). See NSTouchBar.h for the interface evidence.
 *
 * itemForIdentifier: returns the cached item for the identifier, or asks the
 * delegate -touchBar:makeItemForIdentifier: to build one and caches the result
 * (nil is cached as a miss so the delegate is asked only once). itemIdentifiers
 * is the default identifier list (the customization palette that reorders them
 * is stage2). The DFR presentation and template items are stage2.
 */
#import "NSTouchBar.h"

@implementation NSTouchBar {
    __weak id<NSTouchBarDelegate> _delegate;
    NSArray<NSTouchBarItemIdentifier> *_defaultItemIdentifiers;
    NSTouchBarItemIdentifier _principalItemIdentifier;
    NSString *_customizationIdentifier;
    NSMutableDictionary<NSTouchBarItemIdentifier, id> *_itemCache;
    NSMutableSet<NSTouchBarItemIdentifier> *_asked;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _defaultItemIdentifiers = @[];
        _itemCache = [NSMutableDictionary dictionary];
        _asked = [NSMutableSet set];
    }
    return self;
}

- (id<NSTouchBarDelegate>)delegate { return _delegate; }
- (void)setDelegate:(id<NSTouchBarDelegate>)d { _delegate = d; }
- (NSArray<NSTouchBarItemIdentifier> *)defaultItemIdentifiers { return _defaultItemIdentifiers; }
- (void)setDefaultItemIdentifiers:(NSArray<NSTouchBarItemIdentifier> *)v { _defaultItemIdentifiers = [v copy] ?: @[]; }
- (NSTouchBarItemIdentifier)principalItemIdentifier { return _principalItemIdentifier; }
- (void)setPrincipalItemIdentifier:(NSTouchBarItemIdentifier)v { _principalItemIdentifier = [v copy]; }
- (NSString *)customizationIdentifier { return _customizationIdentifier; }
- (void)setCustomizationIdentifier:(NSString *)v { _customizationIdentifier = [v copy]; }

- (NSArray<NSTouchBarItemIdentifier> *)itemIdentifiers { return _defaultItemIdentifiers; }

- (NSTouchBarItem *)itemForIdentifier:(NSTouchBarItemIdentifier)identifier
{
    if (!identifier) return nil;
    id cached = _itemCache[identifier];
    if (cached) return cached;
    if ([_asked containsObject:identifier]) return nil;  /* already asked, was nil */
    [_asked addObject:identifier];
    if ([_delegate respondsToSelector:@selector(touchBar:makeItemForIdentifier:)]) {
        NSTouchBarItem *item = [_delegate touchBar:self makeItemForIdentifier:identifier];
        if (item) _itemCache[identifier] = item;
        return item;
    }
    return nil;
}

@end
