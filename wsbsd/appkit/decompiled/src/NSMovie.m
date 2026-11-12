/*
 * NSMovie.m — behavioral-1:1 core. See the header.
 */

#import "NSMovie.h"

@implementation NSMovie {
    NSData *_data;
    NSURL *_URL;
}

- (instancetype)init { return [super init]; }   /* empty wrapper (measured) */

- (instancetype)initWithMovie:(NSMovie *)movie
{
    self = [super init];
    if (self && movie) {
        _data = [movie.data copy];
        _URL = [movie.URL copy];
    }
    return self;
}

- (NSData *)data { return _data; }
- (NSURL *)URL { return _URL; }
- (id)QTMovie { return nil; }   /* QuickTime/QTKit removed */

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_data forKey:@"NSData"];
    [coder encodeObject:_URL forKey:@"NSURL"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _data = [coder decodeObjectForKey:@"NSData"];
        _URL = [coder decodeObjectForKey:@"NSURL"];
    }
    return self;
}

@end
