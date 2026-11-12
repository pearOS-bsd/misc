/*
 * NSATSTypesetter.m — behavioral-1:1 core. See the header.
 */

#import "NSATSTypesetter.h"

@implementation NSATSTypesetter

+ (NSATSTypesetter *)sharedTypesetter
{
    static NSATSTypesetter *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[self alloc] init]; });
    return shared;
}

@end
