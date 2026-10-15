/* third shim program against the recorded real output (docs/golden/shim_api3.txt) */
#include "SkyLight.h"
#include <stdint.h>
#include "shim_api3.inc"

int main(void)
{
	api3_t a = { SLSMainConnectionID, (int (*)(const R3_ *, void **))CGSNewRegionWithRect, (int (*)(int, int, float, float, void *, uint32_t *))SLSNewWindow, SLSReleaseWindow, SLSOrderWindow,
	             SLSHideCursor, SLSShowCursor, SLSObscureCursor, SLSRevealCursor, SLSGetCursorScale, SLSGetOnScreenWindowList, SLSSetWindowTags, SLSGetWindowTags, SLSClearWindowTags };
	return run_api3(&a);
}
