#include <dlfcn.h>
#include <stdint.h>
#include "../test/shim_api2.inc"
int main(void)
{
	dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW);
	dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_NOW);
	api2_t a;
	a.main_conn = dlsym(RTLD_DEFAULT, "SLSMainConnectionID"); a.new_rect = dlsym(RTLD_DEFAULT, "CGSNewRegionWithRect"); a.new_win = dlsym(RTLD_DEFAULT, "SLSNewWindow");
	a.rel_win = dlsym(RTLD_DEFAULT, "SLSReleaseWindow"); a.order = dlsym(RTLD_DEFAULT, "SLSOrderWindow"); a.is_ordered_in = dlsym(RTLD_DEFAULT, "SLSWindowIsOrderedIn");
	a.win_count = dlsym(RTLD_DEFAULT, "SLSGetWindowCount"); a.onscreen_count = dlsym(RTLD_DEFAULT, "SLSGetOnScreenWindowCount");
	a.set_sub = dlsym(RTLD_DEFAULT, "SLSSetWindowSubLevel"); a.get_sub = dlsym(RTLD_DEFAULT, "SLSGetWindowSubLevel");
	a.set_mask = dlsym(RTLD_DEFAULT, "SLSSetWindowEventMask"); a.get_mask = dlsym(RTLD_DEFAULT, "SLSGetWindowEventMask"); a.set_blur = dlsym(RTLD_DEFAULT, "SLSSetWindowBackgroundBlurRadius");
	return run_api2(&a);
}
