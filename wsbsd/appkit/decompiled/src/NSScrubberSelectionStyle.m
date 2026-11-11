/*
 * NSScrubberSelectionStyle.m — behavioral-1:1 core. See NSScrubberSelectionStyle.h.
 */

#import "NSScrubberSelectionStyle.h"

typedef NS_ENUM(NSInteger, NSScrubberSelectionStyleKind) {
    kStyleOutlineOverlay = 0,
    kStyleNonHighlightingOutlineOverlay = 1,
    kStyleRoundedBackground = 2,
    kStyleCustomViewClass = 3,
};

@implementation NSScrubberSelectionStyle {
    NSScrubberSelectionStyleKind _kind;
    NSColor *_tintColor;
    Class _viewClass;
}

+ (instancetype)_styleOfKind:(NSScrubberSelectionStyleKind)kind
{
    NSScrubberSelectionStyle *s = [[self alloc] init];
    s->_kind = kind;
    return s;
}

+ (NSScrubberSelectionStyle *)outlineOverlayStyle { return [self _styleOfKind:kStyleOutlineOverlay]; }
+ (NSScrubberSelectionStyle *)nonHighlightingOutlineOverlayStyle { return [self _styleOfKind:kStyleNonHighlightingOutlineOverlay]; }
+ (NSScrubberSelectionStyle *)roundedBackgroundStyle { return [self _styleOfKind:kStyleRoundedBackground]; }

+ (NSScrubberSelectionStyle *)roundedBackgroundStyleWithTintColor:(NSColor *)tintColor
{
    NSScrubberSelectionStyle *s = [self _styleOfKind:kStyleRoundedBackground];
    s->_tintColor = tintColor;
    return s;
}

+ (instancetype)selectionStyleWithViewClass:(Class)viewClass
{
    NSScrubberSelectionStyle *s = [self _styleOfKind:kStyleCustomViewClass];
    s->_viewClass = viewClass;
    return s;
}

- (instancetype)initWithCoder:(NSCoder *)coder { return [self init]; }
- (void)encodeWithCoder:(NSCoder *)coder {}

- (NSView *)makeSelectionView
{
    if (_kind == kStyleCustomViewClass && _viewClass)
        return [[_viewClass alloc] init];
    /* TODO(stage2): the built-in outline/rounded-background private selection
     * views (NSScrubberSelectionView subclasses). */
    return nil;
}

@end
