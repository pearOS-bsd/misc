/* Media timing: the mapping of a time of the parent to the time of an object (layer or animation), and the timing function. The arithmetic follows QuartzCore (decompiled: CAMediaTimingCopyRenderTiming, CA::Render::Timing::map_parent_to_active / map_active_to_local / end_time / inverse_map_time, CA::Render::TimingFunction::evaluate). */
#import "CAInternal.h"
#include <mach/mach_time.h>

bool CATimingFromObject(id<CAMediaTiming> obj, CATiming *t)
{
	if (!obj) return false;
	double begin = [obj beginTime], offset = [obj timeOffset], duration = [obj duration], repeatDuration = [obj repeatDuration];
	float speed = [obj speed], repeatCount = [obj repeatCount];
	BOOL autoreverses = [obj autoreverses];
	if (begin < 1e-6 && begin > 0) begin = 0;                                    /* a begin time that is only rounding noise */
	double repeat; BOOL isDuration = NO;
	if (repeatDuration > 0 && repeatCount > 0) {
		double total = (autoreverses ? duration + duration : duration) * (double)repeatCount;
		if (repeatDuration >= total) { repeatDuration = 0; repeat = repeatCount; }
		else { repeat = 0; isDuration = YES; repeat = repeatDuration; }
	} else if (repeatCount > 0) repeat = repeatCount;
	else if (repeatDuration > 0) { isDuration = YES; repeat = repeatDuration; }
	else repeat = 0;
	NSString *fill = [obj fillMode];
	BOOL ff = NO, fb = NO;
	if (fill) {
		if ([fill isEqualToString:@"forwards"] || [fill isEqualToString:@"frozen"]) ff = YES;
		else if ([fill isEqualToString:@"backwards"]) fb = YES;
		else if ([fill isEqualToString:@"both"] || [fill isEqualToString:@"extended"]) ff = fb = YES;
	}
	if (!autoreverses && !ff && !fb && !isDuration && begin == 0 && duration == INFINITY && offset == 0 && speed == 1.0f && repeat == 0) return false;
	t->speed = speed; t->repeat = repeat; t->duration = duration; t->begin = begin; t->offset = offset;
	t->autoreverses = autoreverses; t->fillForwards = ff; t->fillBackwards = fb; t->repeatIsDuration = isDuration; t->endValid = 0; t->endCache = 0;
	return true;
}

double CATimingEndTime(CATiming *t)
{
	if (t->endValid) return t->endCache;
	double k, end;
	if (t->speed == 0) { k = INFINITY; end = k + t->begin; }
	else {
		k = t->speed == 1.0f ? 1.0 : (double)fabsf(1.0f / t->speed);
		double span;
		if (t->repeatIsDuration) span = t->repeat;
		else { span = t->autoreverses ? t->duration + t->duration : t->duration; if (t->repeat > 0) span = span * t->repeat; }
		end = span * k + t->begin;
	}
	t->endCache = end; t->endValid = 1;
	return end;
}

bool CATimingMapParentToActive(CATiming *t, double *time, bool *clamped)
{
	double p = *time, begin = t->begin, end = CATimingEndTime(t);
	if (!t->fillBackwards && p < begin) return false;
	if (!t->fillForwards && p > end) return false;
	double c = p < begin ? begin : p;
	double hi = end + -1e-6;
	if (c > hi) c = hi;
	bool was = c != p;
	double a = (c - begin) * (double)t->speed + t->offset;
	if (!(fabs(a) <= DBL_MAX)) return false;
	*time = a;
	if (clamped) *clamped = was;
	return true;
}

void CATimingMapActiveToLocal(const CATiming *t, double *time, int *iteration)
{
	double cycle = t->duration, v = *time, n = 0;
	if (fabs(cycle) <= DBL_MAX && !(v >= 0 && v < cycle)) {
		n = floor(v / cycle);
		v = v - n * cycle;
		if (t->autoreverses && ((int)n & 1)) {
			v = cycle - v;
			double cap = cycle + -1e-6;
			v = v < cap ? v : cap;
		}
	}
	if (!(fabs(v) <= DBL_MAX)) { if (iteration) *iteration = 0; return; }
	*time = v;
	if (iteration) *iteration = (int)n;
}

bool CATimingMapTime(CATiming *t, double *time)
{
	if (!CATimingMapParentToActive(t, time, NULL)) return false;
	CATimingMapActiveToLocal(t, time, NULL);
	return true;
}

void CATimingInverseMapTime(const CATiming *t, double *time, double parentTime)
{
	double cycle = t->duration; float speed = t->speed;
	if (fabs(cycle) < INFINITY) {
		double act = (parentTime - t->begin) * (double)speed + t->offset;
		double n = floor(act / cycle), v = *time;
		double r = (((int)n) & 1) ? cycle - v : v;
		if (!t->autoreverses) r = v;
		double a = n * cycle + r;
		if (fabs(a) <= DBL_MAX) *time = a;
	}
	if (speed != 0) {
		float inv = speed == 1.0f ? 1.0f : 1.0f / speed;
		double p = (*time - t->offset) * (double)inv + t->begin;
		if (fabs(p) <= DBL_MAX) *time = p;
	}
}

/* ---- CAMediaTimingFunction ------------------------------------------------------------------------------------------------------------------------------------------ */
static double bezier_eval(const double c[4], double x, double eps)
{
	double cx = c[0] * 3, bx = (c[2] - c[0]) * 3 - cx, ax = 1 - cx - bx;
	double cy = c[1] * 3, by = (c[3] - c[1]) * 3 - cy, ay = 1 - cy - by;
	double t = x; int i;
	for (i = 0; i < 8; i++) {
		double f = ((ax * t + bx) * t + cx) * t - x;
		if (fabs(f) < eps) goto done;
		double d = (3 * ax * t + 2 * bx) * t + cx;
		if (fabs(d) < 1e-6) break;
		t -= f / d;
	}
	{ double lo = 0, hi = 1;
	  t = 0;
	  if (x < 0) goto done;
	  t = 1;
	  if (x > 1) goto done;
	  t = x;
	  for (int n = -1023; ; n++) {
		double f = ((ax * t + bx) * t + cx) * t - x;
		if (fabs(f) < eps) break;
		if (f < 0) lo = t; else hi = t;
		t = (hi - lo) * 0.5 + lo;
		if (!(lo < hi) || n == 0) break;
	  }
	}
done:
	return ((ay * t + by) * t + cy) * t;
}

float CAMediaTimingFunctionSolve(float c[4], float x)
{
	double d[4] = { c[0], c[1], c[2], c[3] };
	return (float)bezier_eval(d, (double)x, 1e-5);
}

CFTimeInterval CACurrentMediaTime(void)
{
	static mach_timebase_info_data_t tb;
	if (!tb.denom) mach_timebase_info(&tb);
	return (double)mach_absolute_time() * (double)tb.numer / (double)tb.denom * 1e-9;
}
