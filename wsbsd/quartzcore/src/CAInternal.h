/* Internal declarations shared by the Core Animation sources. */
#ifndef WSBSD_CAINTERNAL_H
#define WSBSD_CAINTERNAL_H
#import <QuartzCore/QuartzCore.h>
#include <math.h>

/* ---- timing: the evaluated form of a CAMediaTiming object (layer or animation) --------------------------------------------------------------------------------------- */
typedef struct CATiming {
	float speed;
	double repeat;              /* repeat count, or the repeat duration when repeatIsDuration */
	double duration;            /* one cycle */
	double begin;
	double offset;
	double endCache;
	unsigned char autoreverses, fillForwards, fillBackwards, repeatIsDuration, endValid;
} CATiming;

/* fills `t` from the object; false when the timing is the identity (no begin, infinite duration, speed 1, no offset, no repeat, no fill) */
bool CATimingFromObject(id<CAMediaTiming> obj, CATiming *t);
double CATimingEndTime(CATiming *t);
bool CATimingMapParentToActive(CATiming *t, double *time, bool *clamped);
void CATimingMapActiveToLocal(const CATiming *t, double *time, int *iteration);
bool CATimingMapTime(CATiming *t, double *time);
void CATimingInverseMapTime(const CATiming *t, double *time, double parentTime);

/* the timing function: a cubic Bezier solved in double precision, the result rounded to float like QuartzCore does */
float CAMediaTimingFunctionSolve(float c[4], float x);

/* ---- values -------------------------------------------------------------------------------------------------------------------------------------------------------- */
id CAValueInterpolate(id from, id to, float fraction);               /* -CA_interpolateValue:byFraction: */
id CAValueAdd(id base, id other, int multiplier);                     /* -CA_addValue:multipliedBy: */
void CAColorGetExtSRGB(CGColorRef c, double out[4]);
CGColorRef CAColorCreateExtSRGB(const double rgba[4]);
id CAValueApplyFunction(id fn, id value, id anim, id layer);

/* ---- layers -------------------------------------------------------------------------------------------------------------------------------------------------------- */
CFTimeInterval CATransactionTime(void);                                /* the time of the current transaction (fixed until it is flushed) */
void CATransactionNoteChange(void);                                    /* a layer changed: an implicit transaction is made current and flushed by the run loop */

@interface CAAnimation ()
- (void)applyForTime:(CFTimeInterval)t presentationObject:(id)pres modelObject:(id)model;
- (float)_solveTiming:(float)x;
- (BOOL)isEnabled;
- (BOOL)_hasStarted;
- (void)setDefaultDuration:(CFTimeInterval)d;
- (CFTimeInterval)_addedAt;
- (BOOL)_hasAddedAt;
- (void)_setAddedAt:(CFTimeInterval)t;
@end

@interface CALayer ()
- (BOOL)_inContext;
- (void)_setContext:(BOOL)inContext;
- (BOOL)_isPresentation;
@end
#endif
