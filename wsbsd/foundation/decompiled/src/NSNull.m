/*
 * NSNull.m — behavioral-1:1 core. See the header.
 */

#import "NSNull.h"
#import <Foundation/NSString.h>   /* for the @"<null>" description literal */
#import <dispatch/dispatch.h>

@implementation NSNull

+ (NSNull *)null
{
    static NSNull *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[self alloc] init]; });
    return shared;
}

/* immutable singleton: a copy is the same object (measured). */
- (id)copyWithZone:(NSZone *)zone { return self; }

- (NSString *)description { return @"<null>"; }   /* measured */

#pragma mark - NSSecureCoding
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)coder {}
- (instancetype)initWithCoder:(NSCoder *)coder { return [NSNull null]; }

@end
