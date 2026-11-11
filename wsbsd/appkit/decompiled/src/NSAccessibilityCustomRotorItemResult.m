/*
 * NSAccessibilityCustomRotorItemResult.m — 1:1 value object. See header.
 */

#import "NSAccessibilityCustomRotorItemResult.h"

@implementation NSAccessibilityCustomRotorItemResult {
    __weak id<NSAccessibilityElement> _targetElement;
    id<NSSecureCoding> _itemLoadingToken;
    NSRange _targetRange;
    NSString *_customLabel;
}

- (instancetype)initWithTargetElement:(id<NSAccessibilityElement>)targetElement
{
    self = [super init];
    if (self) {
        _targetElement = targetElement;
        _targetRange = NSMakeRange(NSNotFound, 0);   /* measured */
    }
    return self;
}

- (instancetype)initWithItemLoadingToken:(id<NSSecureCoding>)itemLoadingToken customLabel:(NSString *)customLabel
{
    self = [super init];
    if (self) {
        _itemLoadingToken = itemLoadingToken;
        _customLabel = [customLabel copy];
        _targetRange = NSMakeRange(NSNotFound, 0);
    }
    return self;
}

- (id<NSAccessibilityElement>)targetElement { return _targetElement; }
- (id<NSSecureCoding>)itemLoadingToken { return _itemLoadingToken; }
- (NSRange)targetRange { return _targetRange; }
- (void)setTargetRange:(NSRange)r { _targetRange = r; }
- (NSString *)customLabel { return _customLabel; }
- (void)setCustomLabel:(NSString *)s { _customLabel = [s copy]; }

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: label=%@ range={%lu,%lu}>", [self class],
            _customLabel, (unsigned long)_targetRange.location, (unsigned long)_targetRange.length];
}

@end
