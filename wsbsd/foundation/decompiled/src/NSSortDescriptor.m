/*
 * NSSortDescriptor.m — behavioral-1:1 core. See the header.
 */

#import "NSSortDescriptor.h"
#import <Foundation/NSKeyValueCoding.h>   /* -valueForKey: */
#import <objc/message.h>

@implementation NSSortDescriptor {
    NSString *_key;
    BOOL _ascending;
    SEL _selector;
}

+ (instancetype)sortDescriptorWithKey:(NSString *)key ascending:(BOOL)ascending
{ return [[self alloc] initWithKey:key ascending:ascending]; }
+ (instancetype)sortDescriptorWithKey:(NSString *)key ascending:(BOOL)ascending selector:(SEL)selector
{ return [[self alloc] initWithKey:key ascending:ascending selector:selector]; }

- (instancetype)initWithKey:(NSString *)key ascending:(BOOL)ascending
{ return [self initWithKey:key ascending:ascending selector:@selector(compare:)]; }

- (instancetype)initWithKey:(NSString *)key ascending:(BOOL)ascending selector:(SEL)selector
{
    self = [super init];
    if (self) {
        _key = [key copy];
        _ascending = ascending;
        _selector = selector ?: @selector(compare:);   /* measured default */
    }
    return self;
}

- (NSString *)key { return _key; }
- (BOOL)ascending { return _ascending; }
- (SEL)selector { return _selector; }

- (id)reversedSortDescriptor
{
    return [[[self class] alloc] initWithKey:_key ascending:!_ascending selector:_selector];
}

- (NSComparisonResult)compareObject:(id)object1 toObject:(id)object2
{
    id v1 = _key ? [object1 valueForKey:_key] : object1;
    id v2 = _key ? [object2 valueForKey:_key] : object2;
    NSComparisonResult r = ((NSComparisonResult(*)(id, SEL, id))objc_msgSend)(v1, _selector, v2);
    return _ascending ? r : (NSComparisonResult)(-r);
}

- (id)copyWithZone:(NSZone *)zone { return self; }   /* immutable */

#pragma mark - NSSecureCoding
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)coder {}   /* stage2 */
- (instancetype)initWithCoder:(NSCoder *)coder { return [self initWithKey:nil ascending:YES]; }

@end
