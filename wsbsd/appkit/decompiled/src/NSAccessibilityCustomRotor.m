/*
 * NSAccessibilityCustomRotor.m — 1:1 value/config object. See header.
 */

#import "NSAccessibilityCustomRotor.h"

@implementation NSAccessibilityCustomRotor {
    NSAccessibilityCustomRotorType _type;
    NSString *_label;
    __weak id<NSAccessibilityCustomRotorItemSearchDelegate> _itemSearchDelegate;
    __weak id<NSAccessibilityElementLoading> _itemLoadingDelegate;
}

- (instancetype)initWithLabel:(NSString *)label itemSearchDelegate:(id<NSAccessibilityCustomRotorItemSearchDelegate>)d
{
    self = [super init];
    if (self) {
        _type = NSAccessibilityCustomRotorTypeCustom;
        _label = [label copy] ?: @"";
        _itemSearchDelegate = d;
    }
    return self;
}

- (instancetype)initWithRotorType:(NSAccessibilityCustomRotorType)rotorType itemSearchDelegate:(id<NSAccessibilityCustomRotorItemSearchDelegate>)d
{
    self = [super init];
    if (self) {
        _type = rotorType;
        _label = @"";
        _itemSearchDelegate = d;
    }
    return self;
}

- (instancetype)init { return [self initWithLabel:@"" itemSearchDelegate:nil]; }

- (NSAccessibilityCustomRotorType)type { return _type; }
- (void)setType:(NSAccessibilityCustomRotorType)t { _type = t; }
- (NSString *)label { return _label; }
- (void)setLabel:(NSString *)l { _label = [l copy] ?: @""; }
- (id<NSAccessibilityCustomRotorItemSearchDelegate>)itemSearchDelegate { return _itemSearchDelegate; }
- (void)setItemSearchDelegate:(id<NSAccessibilityCustomRotorItemSearchDelegate>)d { _itemSearchDelegate = d; }
- (id<NSAccessibilityElementLoading>)itemLoadingDelegate { return _itemLoadingDelegate; }
- (void)setItemLoadingDelegate:(id<NSAccessibilityElementLoading>)d { _itemLoadingDelegate = d; }

- (NSString *)description { return [NSString stringWithFormat:@"<%@: type=%ld label=%@>", [self class], (long)_type, _label]; }

@end
