/* the same program as test/test_shim.c, against the real SkyLight: its output is docs/golden/shim_basic.txt */
#include <dlfcn.h>
#include <stdint.h>
#include "../test/shim_api.inc"

int main(void)
{
	dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW);
	dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_NOW);
	api_t a;
	a.main_conn = dlsym(RTLD_DEFAULT, "SLSMainConnectionID"); a.new_rect = dlsym(RTLD_DEFAULT, "CGSNewRegionWithRect"); a.new_win = dlsym(RTLD_DEFAULT, "SLSNewWindow");
	a.rel_win = dlsym(RTLD_DEFAULT, "SLSReleaseWindow"); a.order = dlsym(RTLD_DEFAULT, "SLSOrderWindow"); a.move = dlsym(RTLD_DEFAULT, "SLSMoveWindow");
	a.set_level = dlsym(RTLD_DEFAULT, "SLSSetWindowLevel"); a.get_level = dlsym(RTLD_DEFAULT, "SLSGetWindowLevel"); a.set_alpha = dlsym(RTLD_DEFAULT, "SLSSetWindowAlpha");
	a.get_alpha = dlsym(RTLD_DEFAULT, "SLSGetWindowAlpha"); a.get_bounds = dlsym(RTLD_DEFAULT, "SLSGetWindowBounds"); a.get_owner = dlsym(RTLD_DEFAULT, "SLSGetWindowOwner");
	return run_api(&a);
}
