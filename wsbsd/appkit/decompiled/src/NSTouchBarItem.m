/*
 * NSTouchBarItem.m — 1:1 (core). See NSTouchBarItem.h for the interface evidence.
 *
 * The base stores the identifier and visibility priority (default
 * NSTouchBarItemPriorityNormal). view/viewController/customizationLabel are nil
 * in the base — concrete subclasses override them. isVisible reflects whether
 * the owning touch bar is showing the item, which is stage2 (NO here).
 */
#import "NSTouchBarItem.h"

@implementation NSTouchBarItem {
    NSString *_identifier;
    NSTouchBarItemPriority _visibilityPriority;
}

- (instancetype)initWithIdentifier:(NSString *)identifier
{
    self = [super init];
    if (self) {
        _identifier = [identifier copy];
        _visibilityPriority = NSTouchBarItemPriorityNormal;
    }
    return self;
}

- (NSString *)identifier { return _identifier; }
- (NSTouchBarItemPriority)visibilityPriority { return _visibilityPriority; }
- (void)setVisibilityPriority:(NSTouchBarItemPriority)v { _visibilityPriority = v; }
- (NSView *)view { return nil; }                   /* subclass override */
- (NSViewController *)viewController { return nil; } /* subclass override */
- (NSString *)customizationLabel { return nil; }    /* subclass override */
- (BOOL)isVisible { return NO; }                    /* stage2: from the touch bar */

@end
