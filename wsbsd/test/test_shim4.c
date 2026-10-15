#include "SkyLight.h"
#include <stdint.h>
#include "shim_api4.inc"

int main(void)
{
	api4_t a = { SLSMainConnectionID, (int (*)(const R4_ *, void **))CGSNewRegionWithRect, (int (*)(int, int, float, float, void *, uint32_t *))SLSNewWindow, SLSReleaseWindow, SLSOrderWindow,
	             (int (*)(int, uint32_t, R4_ *))SLSGetWindowBounds, (int (*)(int, uint32_t, float, float, void *))SLSSetWindowShape, SLSGetWindowResolution, SLSSetWindowResolution,
	             SLSSetWindowListAlpha };
	return run_api4(&a);
}
