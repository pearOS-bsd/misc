/*
 * NSStackView.m — 1:1 (core). Evidence ../evidence/stack:
 * orientation 0x184f81468 ([self+0x1fc]), setOrientation: 0x18507bdc4 (early-out
 * if equal), spacing 0x184fa0b28 ([self+0x218], double), addArrangedSubview:
 * 0x184fcbf28 (append at count). Auto-layout constraints are stage2.
 */
#import "NSStackView.h"

@implementation NSStackView {
    NSUserInterfaceLayoutOrientation _orientation;   /* 0x1fc */
    CGFloat _spacing;                                /* 0x218 */
    NSMutableArray<NSView *> *_arranged;
}

- (instancetype)initWithFrame:(CGRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        _arranged = [NSMutableArray array];
        _orientation = NSUserInterfaceLayoutOrientationHorizontal;
        _spacing = 8.0;   /* conventional default */
    }
    return self;
}

- (NSUserInterfaceLayoutOrientation)orientation { return _orientation; }
- (void)setOrientation:(NSUserInterfaceLayoutOrientation)orientation
{
    if (_orientation == orientation) return;   /* early-out as the binary does */
    _orientation = orientation;
    /* TODO(stage2): rebuild layout constraints for the new axis. */
}

- (CGFloat)spacing { return _spacing; }
- (void)setSpacing:(CGFloat)spacing { _spacing = spacing; }

- (NSArray<NSView *> *)arrangedSubviews { return [_arranged copy]; }

- (void)addArrangedSubview:(NSView *)view
{
    if (!view || [_arranged indexOfObjectIdenticalTo:view] != NSNotFound) return;
    [_arranged addObject:view];
    [self addSubview:view];
    /* TODO(stage2): pin the view into the stack's constraint chain. */
}

- (void)removeArrangedSubview:(NSView *)view
{
    NSUInteger idx = [_arranged indexOfObjectIdenticalTo:view];
    if (idx == NSNotFound) return;
    [_arranged removeObjectAtIndex:idx];   /* stays a subview, as in AppKit */
}

@end
