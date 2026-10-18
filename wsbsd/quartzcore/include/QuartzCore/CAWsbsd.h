/* <QuartzCore/CAWsbsd.h>: additions of this implementation (not in Apple's QuartzCore). */
#ifndef WSBSD_CAWSBSD_H
#define WSBSD_CAWSBSD_H
#import <QuartzCore/QuartzCore.h>
CA_EXTERN_C_BEGIN
/* the value of a from/to animation t seconds after it began (nil when it is not active at that time), without a layer */
CA_EXTERN id CABasicAnimationValueAtTime(CABasicAnimation *a, CFTimeInterval t);
/* the interpolation functions of Core Animation for values (numbers, points, sizes, rects, transforms, colours) */
CA_EXTERN id CAValueInterpolate(id from, id to, float fraction);
CA_EXTERN id CAValueAdd(id base, id other, int multiplier);
/* the presentation tree of a layer drawn into a CoreGraphics context (user space: the coordinates of the superlayer when applyTransform is YES, else the layer's own); time 0 = now */
CA_EXTERN void CARenderPresentation(CALayer *root, CGContextRef ctx, CFTimeInterval time, BOOL applyTransform);
/* YES while the layer or a sublayer has an animation that has not finished */
CA_EXTERN BOOL CALayerTreeHasActiveAnimations(CALayer *root);
/* called (on the thread that changed it) whenever a layer property, the sublayers or the animations of a layer change; used to redraw what shows the layer */
CA_EXTERN void CALayerSetChangeObserver(void (^observer)(CALayer *changed));
CA_EXTERN_C_END
#endif
