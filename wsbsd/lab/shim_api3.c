#include <dlfcn.h>
#include <stdint.h>
#include "../test/shim_api3.inc"
int main(void)
{
	dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW);
	dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_NOW);
	api3_t a;
	a.main_conn = dlsym(RTLD_DEFAULT, "SLSMainConnectionID"); a.new_rect = dlsym(RTLD_DEFAULT, "CGSNewRegionWithRect"); a.new_win = dlsym(RTLD_DEFAULT, "SLSNewWindow");
	a.rel_win = dlsym(RTLD_DEFAULT, "SLSReleaseWindow"); a.order = dlsym(RTLD_DEFAULT, "SLSOrderWindow");
	a.hide = dlsym(RTLD_DEFAULT, "SLSHideCursor"); a.show = dlsym(RTLD_DEFAULT, "SLSShowCursor"); a.obscure = dlsym(RTLD_DEFAULT, "SLSObscureCursor"); a.reveal = dlsym(RTLD_DEFAULT, "SLSRevealCursor");
	a.scale = dlsym(RTLD_DEFAULT, "SLSGetCursorScale"); a.onscreen_list = dlsym(RTLD_DEFAULT, "SLSGetOnScreenWindowList");
	a.set_tags = dlsym(RTLD_DEFAULT, "SLSSetWindowTags"); a.get_tags = dlsym(RTLD_DEFAULT, "SLSGetWindowTags"); a.clear_tags = dlsym(RTLD_DEFAULT, "SLSClearWindowTags");
	return run_api3(&a);
}
