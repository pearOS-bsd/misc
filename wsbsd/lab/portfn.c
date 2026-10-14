/* prints the runtime address of CGSGetConnectionPortById (resolved through lldb; the output goes through a file because attaching interrupts reads) */
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
int main(void)
{
	void *h = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW);
	unsigned long rt = (unsigned long)dlsym(h, "SLSMainConnectionID"), mf = 0, pf = 0; char cmd[400], line[400];
	snprintf(cmd, sizeof cmd, "sudo lldb -b -p %d -o 'image lookup -n SLSMainConnectionID' -o 'image lookup -r -n CGSGetConnectionPortById' -o detach > /tmp/portfn.txt 2>&1", (int)getpid());
	system(cmd);
	FILE *p = fopen("/tmp/portfn.txt", "r"); int k = 0;
	while (p && fgets(line, sizeof line, p)) { char *q = strstr(line, "Address: SkyLight[0x"); if (q) { unsigned long v = strtoull(q + 20, NULL, 16); if (k++ == 0) mf = v; else pf = v; } }
	if (!mf || !pf) { fprintf(stderr, "unresolved\n"); return 1; }
	printf("%lx\n", rt - mf + pf);
	return 0;
}
