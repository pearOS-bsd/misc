#include <dlfcn.h>
#include <stdint.h>
#include "../test/shim_api4.inc"
int main(void)
{
	dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW);
	dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_NOW);
	api4_t a;
	a.main_conn = dlsym(RTLD_DEFAULT, "SLSMainConnectionID"); a.new_rect = dlsym(RTLD_DEFAULT, "CGSNewRegionWithRect"); a.new_win = dlsym(RTLD_DEFAULT, "SLSNewWindow");
	a.rel_win = dlsym(RTLD_DEFAULT, "SLSReleaseWindow"); a.order = dlsym(RTLD_DEFAULT, "SLSOrderWindow"); a.get_bounds = dlsym(RTLD_DEFAULT, "SLSGetWindowBounds");
	a.set_shape = dlsym(RTLD_DEFAULT, "SLSSetWindowShape"); a.get_res = dlsym(RTLD_DEFAULT, "SLSGetWindowResolution"); a.set_res = dlsym(RTLD_DEFAULT, "SLSSetWindowResolution");
	a.set_list_alpha = dlsym(RTLD_DEFAULT, "SLSSetWindowListAlpha");
	return run_api4(&a);
}
