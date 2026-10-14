/* lab probe: resolves private SkyLight symbols of THIS machine's dyld cache through lldb (the runner's build differs from the local one). */
#include <stdio.h>
#include <stdlib.h>
#include <dlfcn.h>
#include <unistd.h>
int main(int argc, char **argv)
{
	void *h = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW);
	printf("SLSMainConnectionID runtime %p\n", h ? dlsym(h, "SLSMainConnectionID") : NULL);
	char cmd[512];
	snprintf(cmd, sizeof cmd, "sudo lldb -b -p %d -o 'image lookup -r -n RegisterCursorWithData' -o 'image lookup -n SLSMainConnectionID' -o 'image lookup -r -n GetRegisteredCursorData' -o 'detach' 2>&1 | grep -E 'Address|Summary|Symbol' | head -40", getpid());
	return system(cmd);
}
