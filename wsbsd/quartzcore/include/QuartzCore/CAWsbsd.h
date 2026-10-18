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
CA_EXTERN_C_END
#endif
