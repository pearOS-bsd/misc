/*
 * NSTabViewItem.m — 1:1 (core). Evidence ../evidence/tab:
 * identifier 0x1850d34c8 (objc_getProperty @0x8), label 0x185077458 /
 * setLabel: 0x185090b18 (compare @0x10 then store), view 0x18507753c.
 */
#import "NSTabViewItem.h"

@implementation NSTabViewItem {
    id _identifier;      /* 0x8 */
    NSString *_label;    /* 0x10 */
    NSView *_view;
}

- (instancetype)initWithIdentifier:(id)identifier
{
    self = [super init];
    if (self) { _identifier = [identifier copyWithZone:nil]; _label = @""; }
    return self;
}

- (id)identifier { return _identifier; }
- (void)setIdentifier:(id)identifier { _identifier = [identifier copyWithZone:nil]; }

- (NSString *)label { return _label; }
- (void)setLabel:(NSString *)label
{
    if ([_label isEqualToString:label]) return;   /* compare-then-store (0x185090b18) */
    _label = [label copy] ?: @"";
}

- (NSView *)view { return _view; }
- (void)setView:(NSView *)view { _view = view; }

@end
