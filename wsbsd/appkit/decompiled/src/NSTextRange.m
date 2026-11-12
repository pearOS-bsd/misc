/*
 * NSTextRange.m — behavioral-1:1 core. See the header.
 */

#import "NSTextRange.h"

@implementation NSTextRange {
    id<NSTextLocation> _location;
    id<NSTextLocation> _endLocation;
}

- (instancetype)initWithLocation:(id<NSTextLocation>)location endLocation:(id<NSTextLocation>)endLocation
{
    if (location == nil) return nil;
    if (endLocation == nil) endLocation = location;   /* empty range at location */
    /* a range is [location, endLocation); endLocation must not precede location. */
    if ([location compare:endLocation] == NSOrderedDescending) return nil;
    self = [super init];
    if (self) {
        _location = location;
        _endLocation = endLocation;
    }
    return self;
}

- (instancetype)initWithLocation:(id<NSTextLocation>)location
{
    return [self initWithLocation:location endLocation:location];
}

- (id<NSTextLocation>)location { return _location; }
- (id<NSTextLocation>)endLocation { return _endLocation; }
- (BOOL)isEmpty { return [_location compare:_endLocation] == NSOrderedSame; }

- (BOOL)isEqualToTextRange:(NSTextRange *)r
{
    if (!r) return NO;
    return [_location compare:r.location] == NSOrderedSame
        && [_endLocation compare:r.endLocation] == NSOrderedSame;
}

- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[NSTextRange class]]) return NO;
    return [self isEqualToTextRange:object];
}

- (NSUInteger)hash { return [(id)_location hash] ^ [(id)_endLocation hash]; }

- (BOOL)containsLocation:(id<NSTextLocation>)location
{
    if (!location) return NO;
    /* start <= location < endLocation */
    return [_location compare:location] != NSOrderedDescending
        && [location compare:_endLocation] == NSOrderedAscending;
}

- (BOOL)containsRange:(NSTextRange *)r
{
    if (!r) return NO;
    /* self.start <= r.start && r.end <= self.end */
    return [_location compare:r.location] != NSOrderedDescending
        && [r.endLocation compare:_endLocation] != NSOrderedDescending;
}

- (BOOL)intersectsWithTextRange:(NSTextRange *)r
{
    if (!r) return NO;
    /* positive-length overlap: self.start < r.end && r.start < self.end */
    return [_location compare:r.endLocation] == NSOrderedAscending
        && [r.location compare:_endLocation] == NSOrderedAscending;
}

static id<NSTextLocation> minLoc(id<NSTextLocation> a, id<NSTextLocation> b)
{ return [a compare:b] == NSOrderedDescending ? b : a; }
static id<NSTextLocation> maxLoc(id<NSTextLocation> a, id<NSTextLocation> b)
{ return [a compare:b] == NSOrderedAscending ? b : a; }

- (NSTextRange *)textRangeByFormingUnionWithTextRange:(NSTextRange *)r
{
    if (!r) return self;
    id<NSTextLocation> start = minLoc(_location, r.location);
    id<NSTextLocation> end = maxLoc(_endLocation, r.endLocation);
    return [[NSTextRange alloc] initWithLocation:start endLocation:end];
}

- (NSTextRange *)textRangeByIntersectingWithTextRange:(NSTextRange *)r
{
    if (!r) return nil;
    id<NSTextLocation> start = maxLoc(_location, r.location);
    id<NSTextLocation> end = minLoc(_endLocation, r.endLocation);
    /* disjoint when start would be past end */
    if ([start compare:end] == NSOrderedDescending) return nil;
    return [[NSTextRange alloc] initWithLocation:start endLocation:end];
}

@end
