/* /usr/lib/dyld on this system: a small ELF program with the job of the Mac's dyld for a program started through it. The Mac's dyld is a Mach-O image loader and cannot run on FreeBSD; the FreeBSD runtime
 * linker (ld-elf.so.1) loads the ELF programs. This one makes the lookup the way dyld does it: DYLD_FRAMEWORK_PATH, DYLD_LIBRARY_PATH and DYLD_FALLBACK_* are honoured and the standard places
 * (/System/Library/Frameworks/*, /System/Library/PrivateFrameworks/*, /usr/lib, /Library/Frameworks/*) are searched, by turning them into LD_LIBRARY_PATH for the program: dyld [-arch x] program [args].  */
#include <dirent.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static void add_frameworks(char *out, size_t n, const char *dir)
{
	DIR *d = opendir(dir); struct dirent *e;
	if (!d) return;
	while ((e = readdir(d))) {
		size_t l = strlen(e->d_name);
		if (l < 11 || strcmp(e->d_name + l - 10, ".framework")) continue;
		char vd[1024]; snprintf(vd, sizeof vd, "%s/%s/Versions", dir, e->d_name);
		DIR *v = opendir(vd); struct dirent *x;
		if (!v) continue;
		while ((x = readdir(v))) if (x->d_name[0] >= 'A' && x->d_name[0] <= 'Z' && strlen(vd) + strlen(x->d_name) + 2 < 900) {
			size_t u = strlen(out); snprintf(out + u, n - u, "%s%s/%s", u ? ":" : "", vd, x->d_name);
		}
		closedir(v);
	}
	closedir(d);
}

int main(int argc, char **argv)
{
	int i = 1;
	while (i < argc && argv[i][0] == '-') { if (!strcmp(argv[i], "-arch") && i + 1 < argc) i++; i++; }
	if (i >= argc) { fprintf(stderr, "usage: dyld [-arch arch] program [arguments]\n"); return 64; }
	static char path[1 << 20]; path[0] = 0;
	const char *fp = getenv("DYLD_FRAMEWORK_PATH"), *lp = getenv("DYLD_LIBRARY_PATH");
	if (lp) snprintf(path, sizeof path, "%s", lp);
	if (fp) { char *c = strdup(fp), *t = strtok(c, ":"); while (t) { add_frameworks(path, sizeof path, t); t = strtok(NULL, ":"); } }
	add_frameworks(path, sizeof path, "/System/Library/Frameworks");
	add_frameworks(path, sizeof path, "/System/Library/PrivateFrameworks");
	add_frameworks(path, sizeof path, "/Library/Frameworks");
	size_t u = strlen(path); snprintf(path + u, sizeof path - u, "%s/usr/lib:/usr/local/lib", u ? ":" : "");
	const char *old = getenv("LD_LIBRARY_PATH");
	if (old && *old) { u = strlen(path); snprintf(path + u, sizeof path - u, ":%s", old); }
	setenv("LD_LIBRARY_PATH", path, 1);
	execvp(argv[i], argv + i);
	perror(argv[i]);
	return 127;
}
