/*
 * NSIndexPath.m — behavioral-1:1 core. See the header.
 */

#import "NSIndexPath.h"
#import <stdlib.h>
#import <string.h>

@implementation NSIndexPath {
    NSUInteger *_indexes;
    NSUInteger _length;
}

+ (instancetype)indexPathWithIndex:(NSUInteger)index { return [[self alloc] initWithIndex:index]; }
+ (instancetype)indexPathWithIndexes:(const NSUInteger *)indexes length:(NSUInteger)length
{ return [[self alloc] initWithIndexes:indexes length:length]; }

- (instancetype)init { return [self initWithIndexes:NULL length:0]; }

- (instancetype)initWithIndex:(NSUInteger)index
{
    NSUInteger one = index;
    return [self initWithIndexes:&one length:1];
}

- (instancetype)initWithIndexes:(const NSUInteger *)indexes length:(NSUInteger)length
{
    self = [super init];
    if (self) {
        _length = length;
        if (length > 0) {
            _indexes = (NSUInteger *)malloc(length * sizeof(NSUInteger));
            if (indexes) memcpy(_indexes, indexes, length * sizeof(NSUInteger));
            else memset(_indexes, 0, length * sizeof(NSUInteger));
        }
    }
    return self;
}

- (void)dealloc { free(_indexes); }

- (NSUInteger)length { return _length; }

- (NSUInteger)indexAtPosition:(NSUInteger)position
{
    if (position >= _length) return NSNotFound;   /* measured */
    return _indexes[position];
}

- (void)getIndexes:(NSUInteger *)indexes range:(NSRange)positionRange
{
    if (!indexes || NSMaxRange(positionRange) > _length) return;
    memcpy(indexes, _indexes + positionRange.location, positionRange.length * sizeof(NSUInteger));
}

- (NSIndexPath *)indexPathByAddingIndex:(NSUInteger)index
{
    NSUInteger n = _length + 1;
    NSUInteger *buf = (NSUInteger *)malloc(n * sizeof(NSUInteger));
    if (_length) memcpy(buf, _indexes, _length * sizeof(NSUInteger));
    buf[_length] = index;
    NSIndexPath *p = [[[self class] alloc] initWithIndexes:buf length:n];
    free(buf);
    return p;
}

- (NSIndexPath *)indexPathByRemovingLastIndex
{
    if (_length == 0) return [[[self class] alloc] init];
    return [[[self class] alloc] initWithIndexes:_indexes length:_length - 1];
}

- (NSComparisonResult)compare:(NSIndexPath *)other
{
    if (!other) return NSOrderedDescending;
    NSUInteger n = MIN(_length, other->_length);
    for (NSUInteger i = 0; i < n; i++) {
        NSUInteger a = _indexes[i], b = other->_indexes[i];
        if (a < b) return NSOrderedAscending;
        if (a > b) return NSOrderedDescending;
    }
    if (_length < other->_length) return NSOrderedAscending;
    if (_length > other->_length) return NSOrderedDescending;
    return NSOrderedSame;
}

- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[NSIndexPath class]]) return NO;
    NSIndexPath *o = object;
    if (_length != o->_length) return NO;
    return _length == 0 || memcmp(_indexes, o->_indexes, _length * sizeof(NSUInteger)) == 0;
}

- (NSUInteger)hash
{
    NSUInteger h = _length;
    for (NSUInteger i = 0; i < _length; i++) h = h * 31 + _indexes[i];
    return h;
}

- (id)copyWithZone:(NSZone *)zone { return self; }   /* immutable */

#pragma mark - NSSecureCoding
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)coder {}   /* stage2: archive the index array */
- (instancetype)initWithCoder:(NSCoder *)coder { return [self init]; }

@end
