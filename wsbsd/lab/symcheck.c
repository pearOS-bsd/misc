#include <dlfcn.h>
#include <stdio.h>
int main(void){
 dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW);
 const char *n[]={"SLSWindowIsOrderedIn","SLSGetWindowCount","SLSGetOnScreenWindowCount","SLSGetOnScreenWindowList","SLSGetWindowList","SLSSetWindowSubLevel","SLSGetWindowSubLevel","SLSFindWindowAndOwner","SLSSetWindowShape","SLSGetWindowShapeBounds","SLSSetWindowProperty","SLSGetWindowProperty","SLSRemoveWindowProperty","SLSSetWindowOpacity","SLSSetWindowTags","SLSGetWindowTags","SLSClearWindowTags","SLSOrderWindowList","SLSMoveWindowList","SLSSetWindowListAlpha","SLSDisableUpdate","SLSEnableUpdate","SLSFlushWindowContentRegion","SLSSetWindowBackgroundBlurRadius","SLSHideCursor","SLSShowCursor","SLSObscureCursor","SLSRevealCursor","SLSGetCursorScale","SLSSetConnectionProperty","SLSCopyConnectionProperty","SLSGetWindowEventMask","SLSSetWindowEventMask","SLSSetWindowResolution","SLSGetWindowResolution","SLSCopyWindowProperty","SLSSetWindowOpaqueShape","SLSNewWindowWithOpaqueShape","SLSAddActivationRegion","SLSWindowSetShadowProperties","SLSGetWindowOwner","SLSCopyManagedDisplays","SLSCopyWindowsWithOptions","SLSTransferWindowOwnership",0};
 for(int i=0;n[i];i++) printf("%s %s\n", dlsym(RTLD_DEFAULT,n[i])?"yes":"no ", n[i]);
}
