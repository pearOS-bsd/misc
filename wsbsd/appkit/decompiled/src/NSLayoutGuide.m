/*
 * NSLayoutGuide.m — 1:1 (core). See NSLayoutGuide.h for the interface evidence.
 *
 * owningView (held weakly), identifier (defaults to empty) and frame are the
 * value core. In AppKit the frame is produced by the NSISEngine from the guide's
 * layout anchors; here it is the last value the engine glue installed via
 * -_setFrame: (the anchors and the solver are stage2).
 */
#import "NSLayoutGuide.h"

@implementation NSLayoutGuide {
    __weak id _owningView;
    NSString *_identifier;
    CGRect _frame;
}

- (instancetype)init
{
    self = [super init];
    if (self) { _identifier = @""; _frame = CGRectZero; }
    return self;
}

- (id)owningView { return _owningView; }
- (void)setOwningView:(id)v { _owningView = v; }
- (NSString *)identifier { return _identifier; }
- (void)setIdentifier:(NSString *)v { _identifier = [v copy] ?: @""; }
- (CGRect)frame { return _frame; }
- (void)_setFrame:(CGRect)frame { _frame = frame; }

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ id='%@' frame={%g,%g,%g,%g}",
            [super description], _identifier,
            _frame.origin.x, _frame.origin.y, _frame.size.width, _frame.size.height];
}

@end
