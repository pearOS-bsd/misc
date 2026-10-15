/* wsbsd's shim against the recorded output of the real SkyLight (docs/golden/shim_basic.txt): the same program, the same lines. */
#include "SkyLight.h"
#include <stdint.h>
#include "shim_api.inc"

int main(void)
{
	api_t a = { SLSMainConnectionID, (int (*)(const R_ *, void **))CGSNewRegionWithRect, (int (*)(int, int, float, float, void *, uint32_t *))SLSNewWindow, SLSReleaseWindow, SLSOrderWindow,
	            (int (*)(int, uint32_t, const P_ *))SLSMoveWindow, SLSSetWindowLevel, SLSGetWindowLevel, SLSSetWindowAlpha, SLSGetWindowAlpha,
	            (int (*)(int, uint32_t, R_ *))SLSGetWindowBounds, SLSGetWindowOwner };
	return run_api(&a);
}
