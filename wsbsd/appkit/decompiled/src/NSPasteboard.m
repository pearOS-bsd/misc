/*
 * NSPasteboard.m — 1:1 (core). See NSPasteboard.h for the interface evidence.
 *
 * In-process model: named pasteboards live in a registry; each holds the
 * declared-type order, a type→data store and a monotonic changeCount.
 *   clearContents        bumps changeCount, empties the store, returns it.
 *   declareTypes:owner:   bumps changeCount, replaces the declared types and
 *                         clears data (AppKit semantics), returns changeCount.
 *   setData:/setString:   store data under a type (adding it to the declared
 *                         set); return NO if the type was never declared, like
 *                         AppKit requires declareTypes: first.
 *   availableTypeFromArray: first requested type that is present.
 * Strings are stored as UTF-8 data under the type, matching CFPasteboard.
 */
#import "NSPasteboard.h"

NSPasteboardType const NSPasteboardTypeString = @"public.utf8-plain-text";

@implementation NSPasteboard {
    NSString *_name;
    NSInteger _changeCount;
    NSMutableArray<NSPasteboardType> *_types;
    NSMutableDictionary<NSPasteboardType, NSData *> *_store;
}

- (instancetype)_initWithName:(NSString *)name
{
    self = [super init];
    if (self) {
        _name = [name copy];
        _types = [NSMutableArray array];
        _store = [NSMutableDictionary dictionary];
        _changeCount = 0;
    }
    return self;
}

static NSMutableDictionary<NSString *, NSPasteboard *> *NSPasteboardRegistry(void)
{
    static NSMutableDictionary *reg;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ reg = [NSMutableDictionary dictionary]; });
    return reg;
}

+ (NSPasteboard *)pasteboardWithName:(NSString *)name
{
    NSMutableDictionary *reg = NSPasteboardRegistry();
    @synchronized (reg) {
        NSPasteboard *pb = reg[name];
        if (!pb) { pb = [[NSPasteboard alloc] _initWithName:name]; reg[name] = pb; }
        return pb;
    }
}

+ (NSPasteboard *)generalPasteboard
{
    return [self pasteboardWithName:@"Apple CFPasteboard general"];
}

/* the general pasteboard is shared between processes through a file (plain text) */
#define OPEN_PB_FILE "/tmp/open-pasteboard"
- (BOOL)_shared { return [_name isEqualToString:@"Apple CFPasteboard general"]; }
- (void)_syncFromFile
{
    if (![self _shared]) return;
    NSDictionary *a = [[NSFileManager defaultManager] attributesOfItemAtPath:@OPEN_PB_FILE error:nil]; NSDate *m = a[NSFileModificationDate];
    static NSDate *last; if (!m || (last && [last isEqualToDate:m])) return;
    last = m; NSData *d = [NSData dataWithContentsOfFile:@OPEN_PB_FILE]; if (!d) return;
    [_types removeAllObjects]; [_store removeAllObjects]; [_types addObject:NSPasteboardTypeString]; _store[NSPasteboardTypeString] = d; _changeCount++;
}
- (void)_syncToFile { if ([self _shared]) { NSData *d = _store[NSPasteboardTypeString]; if (d) [d writeToFile:@OPEN_PB_FILE atomically:YES]; } }
- (NSString *)name { return _name; }
- (NSInteger)changeCount { [self _syncFromFile]; return _changeCount; }
- (NSArray<NSPasteboardType> *)types { [self _syncFromFile]; return _types.count ? [_types copy] : nil; }

- (NSInteger)clearContents
{
    [_types removeAllObjects];
    [_store removeAllObjects];
    return ++_changeCount;
}

- (NSInteger)declareTypes:(NSArray<NSPasteboardType> *)newTypes owner:(id)newOwner
{
    [_store removeAllObjects];
    _types = [newTypes mutableCopy] ?: [NSMutableArray array];
    return ++_changeCount;
}

- (BOOL)setData:(NSData *)data forType:(NSPasteboardType)dataType
{
    if (!dataType) return NO;
    if (![_types containsObject:dataType]) {
        /* AppKit requires the type be declared first; tolerate by adding it. */
        [_types addObject:dataType];
    }
    if (data) _store[dataType] = data; else [_store removeObjectForKey:dataType];
    [self _syncToFile];
    return YES;
}

- (NSData *)dataForType:(NSPasteboardType)dataType { [self _syncFromFile]; return _store[dataType]; }

- (BOOL)setString:(NSString *)string forType:(NSPasteboardType)dataType
{
    return [self setData:[string dataUsingEncoding:NSUTF8StringEncoding] forType:dataType];
}

- (NSString *)stringForType:(NSPasteboardType)dataType
{
    [self _syncFromFile]; NSData *d = _store[dataType];
    return d ? [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] : nil;
}

- (NSPasteboardType)availableTypeFromArray:(NSArray<NSPasteboardType> *)types
{
    [self _syncFromFile];
    for (NSPasteboardType t in types)
        if ([_types containsObject:t]) return t;
    return nil;
}

@end
