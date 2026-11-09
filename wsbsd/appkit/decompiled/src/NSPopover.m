/*
 * NSPopover.m — 1:1 (core). Evidence ../evidence/popover:
 * behavior 0x1851745c4, animates 0x18517591c (_flags @0xa70 bit 0), isShown
 * 0x184f9b2a0 (_flags bit 4), contentSize 0x185175d14 ([self+0xa78]),
 * contentViewController 0x1850f3c24. show:/close are stage2.
 */
#import "NSPopover.h"

enum : uint32_t { NSPopoverFlagAnimates = 0x1, NSPopoverFlagShown = 0x10 };

@implementation NSPopover {
    NSPopoverBehavior _behavior;
    uint32_t _flags;            /* 0xa70 */
    CGSize _contentSize;        /* 0xa78 */
    id _contentViewController;
}

- (instancetype)init
{
    self = [super init];
    if (self) { _flags |= NSPopoverFlagAnimates; }   /* animates defaults YES */
    return self;
}

- (NSPopoverBehavior)behavior { return _behavior; }
- (void)setBehavior:(NSPopoverBehavior)behavior { _behavior = behavior; }

- (BOOL)animates { return (_flags & NSPopoverFlagAnimates) != 0; }
- (void)setAnimates:(BOOL)animates
{
    if (animates) _flags |= NSPopoverFlagAnimates;
    else          _flags &= ~NSPopoverFlagAnimates;
}

- (BOOL)isShown { return (_flags & NSPopoverFlagShown) != 0; }   /* read-only; set by show:/close (stage2) */

- (CGSize)contentSize { return _contentSize; }
- (void)setContentSize:(CGSize)contentSize { _contentSize = contentSize; }

- (id)contentViewController { return _contentViewController; }
- (void)setContentViewController:(id)contentViewController { _contentViewController = contentViewController; }

@end
