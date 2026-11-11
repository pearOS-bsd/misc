/*
 * NSAccessibilityCustomChooserSearchPredicate.m — 1:1 value objects. See header.
 */

#import "NSAccessibilityCustomChooserSearchPredicate.h"

@implementation NSAccessibilityCustomChooserSearchPredicate {
    NSString *_filterText;
}
- (NSString *)filterText { return _filterText; }
- (void)setFilterText:(NSString *)s { _filterText = [s copy]; }
@end

@implementation NSAccessibilityCustomChooserItemResult {
    __weak id _targetElement;
    NSValue *_targetRange;
    NSString *_descriptionOverride;
}

- (instancetype)initWithTargetElement:(id)targetElement targetRange:(NSValue *)targetRange
{
    self = [super init];
    if (self) {
        _targetElement = targetElement;
        _targetRange = targetRange;
    }
    return self;
}

- (id)targetElement { return _targetElement; }
- (void)setTargetElement:(id)e { _targetElement = e; }
- (NSValue *)targetRange { return _targetRange; }
- (void)setTargetRange:(NSValue *)r { _targetRange = r; }
- (NSString *)descriptionOverride { return _descriptionOverride; }
- (void)setDescriptionOverride:(NSString *)s { _descriptionOverride = [s copy]; }
@end
