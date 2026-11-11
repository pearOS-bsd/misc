/*
 * NSScrubberItemView.m — behavioral-1:1 core for the three scrubber views.
 * See NSScrubberItemView.h.
 */

#import "NSScrubberItemView.h"

@implementation NSScrubberArrangedView {
    BOOL _selected;
    BOOL _highlighted;
}

- (BOOL)isSelected { return _selected; }
- (void)setSelected:(BOOL)v { _selected = v; /* stage2: invalidate display */ }
- (BOOL)isHighlighted { return _highlighted; }
- (void)setHighlighted:(BOOL)v { _highlighted = v; /* stage2: invalidate display */ }

- (void)applyLayoutAttributes:(NSScrubberLayoutAttributes *)layoutAttributes
{
    if (layoutAttributes) self.frame = layoutAttributes.frame;
    /* TODO(stage2): apply layoutAttributes.alpha to the view's alphaValue. */
}

@end


@implementation NSScrubberItemView {
    NSScrubberSelectionView *_background;
    NSScrubberSelectionView *_foreground;
    id _maskOne;
    id _maskTwo;
}

- (NSScrubberSelectionView *)selectionBackgroundView { return _background; }
- (void)setSelectionBackgroundView:(NSScrubberSelectionView *)v { _background = v; }
- (NSScrubberSelectionView *)selectionOverlayView { return _foreground; }
- (void)setSelectionOverlayView:(NSScrubberSelectionView *)v { _foreground = v; }
- (id)leftMaskLayer { return _maskOne; }
- (void)setLeftMaskLayer:(id)l { _maskOne = l; }
- (id)rightMaskLayer { return _maskTwo; }
- (void)setRightMaskLayer:(id)l { _maskTwo = l; }

- (void)prepareForReuse
{
    self.selected = NO;
    self.highlighted = NO;
    /* TODO(stage2): reset mask layers / selection views to the reuse baseline. */
}

@end


@implementation NSScrubberSelectionView
@end
