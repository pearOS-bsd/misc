/*
 * NSPasteboardItem.m — 1:1 (core). See NSPasteboardItem.h for the evidence.
 *
 * The item keeps its types in declaration order with a type→data store (the
 * real item holds this in its _auxObject). Strings are UTF-8; property lists
 * round-trip through NSPropertyListSerialization (binary). availableTypeFromArray:
 * returns the first requested type that is present. Lazy data promises are stage2.
 */
#import "NSPasteboardItem.h"

@implementation NSPasteboardItem {
    NSMutableArray<NSPasteboardType> *_types;
    NSMutableDictionary<NSPasteboardType, NSData *> *_store;
}

- (instancetype)init
{
    self = [super init];
    if (self) { _types = [NSMutableArray array]; _store = [NSMutableDictionary dictionary]; }
    return self;
}

- (NSArray<NSPasteboardType> *)types { return [_types copy]; }

- (NSPasteboardType)availableTypeFromArray:(NSArray<NSPasteboardType> *)types
{
    for (NSPasteboardType t in types)
        if ([_types containsObject:t]) return t;
    return nil;
}

- (BOOL)setData:(NSData *)data forType:(NSPasteboardType)type
{
    if (!type || !data) return NO;
    if (![_types containsObject:type]) [_types addObject:type];
    _store[type] = data;
    return YES;
}

- (NSData *)dataForType:(NSPasteboardType)type { return _store[type]; }

- (BOOL)setString:(NSString *)string forType:(NSPasteboardType)type
{
    return [self setData:[string dataUsingEncoding:NSUTF8StringEncoding] forType:type];
}

- (NSString *)stringForType:(NSPasteboardType)type
{
    NSData *d = _store[type];
    return d ? [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] : nil;
}

- (BOOL)setPropertyList:(id)propertyList forType:(NSPasteboardType)type
{
    NSData *d = [NSPropertyListSerialization dataWithPropertyList:propertyList
                                                           format:NSPropertyListBinaryFormat_v1_0
                                                          options:0 error:NULL];
    return d ? [self setData:d forType:type] : NO;
}

- (id)propertyListForType:(NSPasteboardType)type
{
    NSData *d = _store[type];
    if (!d) return nil;
    return [NSPropertyListSerialization propertyListWithData:d options:0 format:NULL error:NULL];
}

@end
