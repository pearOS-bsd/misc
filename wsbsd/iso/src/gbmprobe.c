/* gbmprobe: what GBM / EGL say on a render node, step by step, with the reasons (dlerror) */
#include <dlfcn.h>
#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>
#include <gbm.h>
#include <EGL/egl.h>
#include <EGL/eglext.h>
static void tryso(const char *p){ void *h=dlopen(p,RTLD_NOW); printf("dlopen %s: %s\n",p,h?"ok":dlerror()); }
int main(int argc,char**argv){
	const char *node = argc>1?argv[1]:"/dev/dri/renderD128";
	tryso("/usr/local/lib/gbm/dri_gbm.so"); tryso("/usr/local/lib/dri/iris_dri.so"); tryso("/usr/local/lib/libgallium-26.2.2.so");
	int fd=open(node,O_RDWR|O_CLOEXEC); printf("open %s: fd %d\n",node,fd); if(fd<0) return 1;
	struct gbm_device *g=gbm_create_device(fd); printf("gbm_create_device: %p\n",(void*)g);
	if(!g) return 2;
	printf("backend name %s\n", gbm_device_get_backend_name(g));
	PFNEGLGETPLATFORMDISPLAYEXTPROC gp=(void*)eglGetProcAddress("eglGetPlatformDisplayEXT");
	EGLDisplay d=gp?gp(EGL_PLATFORM_GBM_KHR,g,NULL):EGL_NO_DISPLAY; printf("eglGetPlatformDisplay: %p err 0x%x\n",d,eglGetError());
	EGLint a,b; printf("eglInitialize: %d err 0x%x\n",d?eglInitialize(d,&a,&b):0,eglGetError());
	return 0;
}
