/* DYLD_INSERT_LIBRARIES=/open/dlopen-hook.dylib: shows who dlopens a library with AppKit in its path (the real AppKit must not come in next to ours) */
#include <dlfcn.h>
#include <execinfo.h>
#include <stdio.h>
#include <string.h>
static void *my_dlopen(const char *p, int f)
{
    if (p && strstr(p, "AppKit")) { fprintf(stderr, "dlopen(%s)\n", p); void *bt[25]; int n = backtrace(bt, 25); backtrace_symbols_fd(bt, n, 2); }
    return dlopen(p, f);
}
__attribute__((used)) static struct { const void *r, *o; } interp[] __attribute__((section("__DATA,__interpose"))) = { { (const void *)my_dlopen, (const void *)dlopen } };
