/*
 * NSPageLayout.m — behavioral-1:1 core. See the header.
 */

#import "NSPageLayout.h"

@implementation NSPageLayout {
    NSMutableArray *_accessoryControllers;
}

+ (instancetype)pageLayout { return [[self alloc] init]; }

- (instancetype)init
{
    self = [super init];
    if (self) _accessoryControllers = [NSMutableArray array];
    return self;
}

- (void)addAccessoryController:(id)accessoryController
{
    if (accessoryController && ![_accessoryControllers containsObject:accessoryController])
        [_accessoryControllers addObject:accessoryController];
}
- (void)removeAccessoryController:(id)accessoryController { [_accessoryControllers removeObject:accessoryController]; }
- (NSArray *)accessoryControllers { return [_accessoryControllers copy]; }

- (NSPrintInfo *)printInfo { return nil; }   /* set during a run = stage2 */

@end
