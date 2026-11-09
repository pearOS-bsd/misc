/*
 * NSStatusItem.m — 1:1 (core). Evidence ../evidence/status:
 * length 0x185768d44 ([self+0x10], double), menu 0x18510c6ac / setMenu:
 * 0x1857698dc, isVisible 0x18510c60c (derived from flags @0xe8). We model
 * visibility as a bool (exact flag gating is stage2).
 */
#import "NSStatusItem.h"

@implementation NSStatusItem {
    CGFloat _length;   /* 0x10 */
    NSMenu *_menu;
    BOOL _visible;
}

- (instancetype)init
{
    self = [super init];
    if (self) { _length = NSVariableStatusItemLength; _visible = YES; }
    return self;
}

- (CGFloat)length { return _length; }
- (void)setLength:(CGFloat)length { _length = length; }

- (NSMenu *)menu { return _menu; }
- (void)setMenu:(NSMenu *)menu { _menu = menu; }

- (BOOL)isVisible { return _visible; }
- (void)setVisible:(BOOL)visible { _visible = visible; }

@end
