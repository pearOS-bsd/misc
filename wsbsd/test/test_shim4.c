#include "SkyLight.h"
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include "shim_api4.inc"

int main(void)
{
	api4_t a = { SLSMainConnectionID, (int (*)(const R4_ *, void **))CGSNewRegionWithRect, (int (*)(int, int, float, float, void *, uint32_t *))SLSNewWindow, SLSReleaseWindow, SLSOrderWindow,
	             (int (*)(int, uint32_t, R4_ *))SLSGetWindowBounds, (int (*)(int, uint32_t, float, float, void *))SLSSetWindowShape, SLSGetWindowResolution, SLSSetWindowResolution,
	             SLSSetWindowListAlpha };
	int rc = run_api4(&a);
	{ /* capture of a window through the shim extension */
		SLRect r = { 0, 0, 30, 20 }; CGSRegionRef reg = 0; uint32_t wid = 0;
		CGSNewRegionWithRect(&r, &reg); SLSNewWindow(SLSMainConnectionID(), 2, 40, 50, reg, &wid);
		int w = 0, h = 0; uint8_t *px = 0;
		if (WSCaptureWindowPixels(SLSMainConnectionID(), wid, &w, &h, &px) != 0 || w != 30 || h != 20 || !px) { printf("FAIL: WSCaptureWindowPixels %d x %d\n", w, h); rc = 1; }
		free(px); SLSReleaseWindow(SLSMainConnectionID(), wid);
	}
	return rc;
}
