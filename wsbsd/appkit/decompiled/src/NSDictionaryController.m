/*
 * NSDictionaryController.m — behavioral-1:1 core.
 * See NSDictionaryController.h (behavior measured on this Mac; CoreData+KVO stage2).
 */

#import "NSDictionaryController.h"

@interface NSDictionaryControllerKeyValuePair ()
@property (readwrite, getter=isExplicitlyIncluded) BOOL explicitlyIncluded;
@end

@implementation NSDictionaryControllerKeyValuePair
- (NSString *)description { return [NSString stringWithFormat:@"<%@ key=%@ value=%@>", [self class], _key, _value]; }
/* AppKit compares pairs by key (so a pair tracks its dictionary entry). */
- (BOOL)isEqual:(id)other
{
    if (self == other) return YES;
    if (![other isKindOfClass:[NSDictionaryControllerKeyValuePair class]]) return NO;
    NSString *ok = ((NSDictionaryControllerKeyValuePair *)other).key;
    return (_key == ok) || [_key isEqual:ok];
}
- (NSUInteger)hash { return _key.hash; }
@end


@implementation NSDictionaryController {
    NSString *_initialKey;
    id _initialValue;
    NSArray<NSString *> *_includedKeys;
    NSArray<NSString *> *_excludedKeys;
    NSDictionary<NSString *, NSString *> *_localizedKeyDictionary;
    NSString *_localizedKeyTable;
}

- (instancetype)initWithContent:(id)content
{
    self = [super initWithContent:nil];
    if (self) {
        _initialKey = @"key";
        _includedKeys = @[];
        _excludedKeys = @[];
        if (content) [self setContent:content];
    }
    return self;
}

- (instancetype)init { return [self initWithContent:nil]; }
- (instancetype)initWithCoder:(NSCoder *)coder { return [self initWithContent:nil]; }

/* --- content <-> key-value-pair arrangement --- */

- (NSString *)_localizedForKey:(NSString *)key { return _localizedKeyDictionary[key] ?: key; }

- (void)setContent:(id)content
{
    NSDictionary *dict = [content isKindOfClass:[NSDictionary class]] ? content : nil;
    NSMutableArray<NSDictionaryControllerKeyValuePair *> *pairs = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];

    for (NSString *key in dict) {
        if ([_excludedKeys containsObject:key]) continue;
        NSDictionaryControllerKeyValuePair *p = [[NSDictionaryControllerKeyValuePair alloc] init];
        p.key = key;
        p.value = dict[key];
        p.localizedKey = [self _localizedForKey:key];
        [pairs addObject:p];
        [seen addObject:key];
    }
    /* includedKeys always appear, even with no dictionary entry */
    for (NSString *key in _includedKeys) {
        if ([seen containsObject:key] || [_excludedKeys containsObject:key]) continue;
        NSDictionaryControllerKeyValuePair *p = [[NSDictionaryControllerKeyValuePair alloc] init];
        p.key = key;
        p.value = nil;
        p.localizedKey = [self _localizedForKey:key];
        p.explicitlyIncluded = YES;
        [pairs addObject:p];
    }
    [super setContent:pairs];
}

- (id)content
{
    /* rebuild the dictionary from the current key-value pairs */
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    for (NSDictionaryControllerKeyValuePair *p in [self arrangedObjects]) {
        if (p.key && p.value) dict[p.key] = p.value;
    }
    return dict;
}

- (NSDictionaryControllerKeyValuePair *)newObject
{
    /* measured: a fresh pair is empty; initialKey/initialValue are applied by
     * the binding machinery on insert (stage2). */
    return [[NSDictionaryControllerKeyValuePair alloc] init];
}

/* --- configuration --- */

- (NSString *)initialKey { return _initialKey; }
- (void)setInitialKey:(NSString *)k { _initialKey = [k copy]; }
- (id)initialValue { return _initialValue; }
- (void)setInitialValue:(id)v { _initialValue = v; }

- (NSArray<NSString *> *)includedKeys { return _includedKeys; }
- (void)setIncludedKeys:(NSArray<NSString *> *)k { _includedKeys = [k copy] ?: @[]; }
- (NSArray<NSString *> *)excludedKeys { return _excludedKeys; }
- (void)setExcludedKeys:(NSArray<NSString *> *)k { _excludedKeys = [k copy] ?: @[]; }

- (NSDictionary<NSString *, NSString *> *)localizedKeyDictionary { return _localizedKeyDictionary; }
- (void)setLocalizedKeyDictionary:(NSDictionary<NSString *, NSString *> *)d { _localizedKeyDictionary = [d copy]; }
- (NSString *)localizedKeyTable { return _localizedKeyTable; }
- (void)setLocalizedKeyTable:(NSString *)t { _localizedKeyTable = [t copy]; }

@end
