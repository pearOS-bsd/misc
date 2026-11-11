/*
 * NSAccessibilityCustomRotorSearchParameters.m — 1:1 value object. See header.
 */

#import "NSAccessibilityCustomRotorSearchParameters.h"

@implementation NSAccessibilityCustomRotorSearchParameters {
    NSString *_filterString;
}

- (NSString *)filterString { return _filterString; }
- (void)setFilterString:(NSString *)s { _filterString = [s copy]; }

@end
