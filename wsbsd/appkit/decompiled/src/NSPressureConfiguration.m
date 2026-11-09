/*
 * NSPressureConfiguration.m — 1:1 (core). See the header for the evidence.
 *
 * Stores the pressure behaviour. -set applies it to the current event's
 * trackpad (via the Multitouch configuration, _mtConfiguration) — that push is
 * stage2; here it is a no-op.
 */
#import "NSPressureConfiguration.h"

@implementation NSPressureConfiguration {
    NSPressureBehavior _pressureBehavior;
}

- (instancetype)initWithPressureBehavior:(NSPressureBehavior)pressureBehavior
{
    self = [super init];
    if (self) { _pressureBehavior = pressureBehavior; }
    return self;
}

- (instancetype)init { return [self initWithPressureBehavior:NSPressureBehaviorPrimaryDefault]; }

- (NSPressureBehavior)pressureBehavior { return _pressureBehavior; }
- (void)set { /* stage2: push to the current event's trackpad configuration */ }

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ behavior=%ld", [super description], (long)_pressureBehavior];
}

@end
