/*
 * NSColorList.m — 1:1 (core). See NSColorList.h for the interface evidence.
 *
 * Parallel ordered arrays _keyArray / _colorArray with a key→index map.
 *   setColor:forKey:          replaces the colour if the key exists, else appends.
 *   insertColor:key:atIndex:  inserts a new key/colour at loc (raises if the key
 *                             already exists, like AppKit).
 *   removeColorWithKey:       removes the key/colour pair.
 *   colorWithKey:             O(1) lookup through the index map.
 * File loading/saving (.clr) and the system colour lists are stage2.
 */
#import "NSColorList.h"

@implementation NSColorList {
    NSMutableArray<NSString *> *_keyArray;
    NSMutableArray<NSColor *> *_colorArray;
    NSMutableDictionary<NSString *, NSNumber *> *_keyToIndex;
    NSString *_name;
    BOOL _editable;
}

- (instancetype)initWithName:(NSString *)name
{
    self = [super init];
    if (self) {
        _name = [name copy];
        _keyArray = [NSMutableArray array];
        _colorArray = [NSMutableArray array];
        _keyToIndex = [NSMutableDictionary dictionary];
        _editable = YES;
    }
    return self;
}

- (NSString *)name { return _name; }
- (BOOL)isEditable { return _editable; }
- (NSArray<NSString *> *)allKeys { return [_keyArray copy]; }

- (NSColor *)colorWithKey:(NSString *)key
{
    NSNumber *idx = _keyToIndex[key];
    return idx ? _colorArray[idx.unsignedIntegerValue] : nil;
}

- (void)setColor:(NSColor *)color forKey:(NSString *)key
{
    if (!color || !key) return;
    NSNumber *idx = _keyToIndex[key];
    if (idx) {
        _colorArray[idx.unsignedIntegerValue] = color;
    } else {
        _keyToIndex[key] = @(_keyArray.count);
        [_keyArray addObject:key];
        [_colorArray addObject:color];
    }
}

- (void)insertColor:(NSColor *)color key:(NSString *)key atIndex:(NSUInteger)loc
{
    if (!color || !key) return;
    if (_keyToIndex[key]) {
        /* AppKit moves an existing key; here we replace in place to keep the
         * key set consistent, then no duplicate is created. */
        [self removeColorWithKey:key];
    }
    if (loc > _keyArray.count) loc = _keyArray.count;
    [_keyArray insertObject:key atIndex:loc];
    [_colorArray insertObject:color atIndex:loc];
    [self _rebuildIndex];
}

- (void)removeColorWithKey:(NSString *)key
{
    NSNumber *idx = _keyToIndex[key];
    if (!idx) return;
    NSUInteger i = idx.unsignedIntegerValue;
    [_keyArray removeObjectAtIndex:i];
    [_colorArray removeObjectAtIndex:i];
    [self _rebuildIndex];
}

- (void)_rebuildIndex
{
    [_keyToIndex removeAllObjects];
    for (NSUInteger i = 0; i < _keyArray.count; i++)
        _keyToIndex[_keyArray[i]] = @(i);
}

@end
