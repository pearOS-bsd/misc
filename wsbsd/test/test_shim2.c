/* second shim program against the recorded real output (docs/golden/shim_api2.txt) */
#include "SkyLight.h"
#include <stdint.h>
#include "shim_api2.inc"

int main(void)
{
	api2_t a = { SLSMainConnectionID, (int (*)(const R2_ *, void **))CGSNewRegionWithRect, (int (*)(int, int, float, float, void *, uint32_t *))SLSNewWindow, SLSReleaseWindow, SLSOrderWindow,
	             SLSWindowIsOrderedIn, SLSGetWindowCount, SLSGetOnScreenWindowCount, SLSSetWindowSubLevel, SLSGetWindowSubLevel, SLSSetWindowEventMask, SLSGetWindowEventMask,
	             SLSSetWindowBackgroundBlurRadius };
	return run_api2(&a);
}
