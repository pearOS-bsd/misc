/*
 * NSScrubberItemView.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSScrubberArrangedView, NSScrubberItemView and NSScrubberSelectionView, the
 * view hierarchy an NSScrubber arranges.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSScrubberItemView_interface.txt.
 *
 * NSScrubberArrangedView (: NSView) holds the selected/highlighted flags and
 * applyLayoutAttributes:; NSScrubberItemView adds the selection background/overlay
 * views and left/right mask layers plus prepareForReuse; NSScrubberSelectionView
 * is a marker subclass the selection styles vend. The alpha application, CALayer
 * masking, draw and accessibility surface are TODO(stage2).
 */

#import "NSView.h"
#import "NSScrubberLayoutAttributes.h"

NS_ASSUME_NONNULL_BEGIN

@class NSScrubberSelectionView, CALayer;

@interface NSScrubberArrangedView : NSView
@property (getter=isSelected) BOOL selected;        /* default NO */
@property (getter=isHighlighted) BOOL highlighted;  /* default NO */
- (void)applyLayoutAttributes:(NSScrubberLayoutAttributes *)layoutAttributes;
@end

@interface NSScrubberItemView : NSScrubberArrangedView
@property (nullable, strong) NSScrubberSelectionView *selectionBackgroundView;
@property (nullable, strong) NSScrubberSelectionView *selectionOverlayView;
@property (nullable, strong) id leftMaskLayer;      /* CALayer, stage2 */
@property (nullable, strong) id rightMaskLayer;     /* CALayer, stage2 */
- (void)prepareForReuse;
@end

@interface NSScrubberSelectionView : NSScrubberArrangedView
@end

NS_ASSUME_NONNULL_END
