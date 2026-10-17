/* /usr/bin/xattr: list, read, write and delete extended attributes, the way the Mac's tool prints them.
 *   xattr [-rslvx] file ...            names of the attributes (-l: with values, -v: file name before each line, -x: values as hex, -r: below directories, -s: do not follow links)
 *   xattr -p [-lrsvx] name file ...    print one attribute          xattr -w [-rsx] name value file ...   set          xattr -d [-rsv] name file ...   delete        xattr -c [-rsv] file ...   clear all */
#include <dirent.h>
#include <errno.h>
#include <fts.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/xattr.h>
#include <unistd.h>

static int opt_l, opt_r, opt_s, opt_v, opt_x, status;
static const char *prog = "xattr";

static void show_value(const char *v, ssize_t n)
{
	if (opt_x) { for (ssize_t i = 0; i < n; i++) printf("%02X%s", (unsigned char)v[i], (i + 1) % 16 == 0 ? "\n" : " "); if (n % 16) putchar('\n'); }
	else { fwrite(v, 1, (size_t)n, stdout); if (n == 0 || v[n - 1] != '\n') putchar('\n'); }
}
static void list_one(const char *path, int many)
{
	int fl = opt_s ? XATTR_NOFOLLOW : 0;
	ssize_t n = listxattr(path, NULL, 0, fl);
	if (n < 0) { fprintf(stderr, "%s: [Errno %d] %s: '%s'\n", prog, errno, strerror(errno), path); status = 1; return; }
	if (n == 0) return;
	char *names = malloc((size_t)n); n = listxattr(path, names, (size_t)n, fl);
	for (char *p = names; p < names + n; p += strlen(p) + 1) {
		if (many || opt_v) printf("%s: ", path);
		if (!opt_l) { printf("%s\n", p); continue; }
		ssize_t vn = getxattr(path, p, NULL, 0, 0, fl); char *v = vn > 0 ? malloc((size_t)vn) : NULL;
		if (vn > 0) vn = getxattr(path, p, v, (size_t)vn, 0, fl);
		printf("%s: ", p); if (vn >= 0) show_value(v ? v : "", vn > 0 ? vn : 0); else putchar('\n'); free(v);
	}
	free(names);
}
static void each(char **files, void (*fn)(const char *, int), int many)
{
	for (; *files; files++) {
		if (!opt_r) { fn(*files, many); continue; }
		char *argv[2] = { *files, NULL }; FTS *t = fts_open(argv, FTS_PHYSICAL | FTS_NOCHDIR, NULL); FTSENT *e;
		while (t && (e = fts_read(t))) if (e->fts_info != FTS_DP) fn(e->fts_path, 1);
		if (t) fts_close(t);
	}
}
static const char *g_name, *g_value;
static void print_one(const char *path, int many)
{
	int fl = opt_s ? XATTR_NOFOLLOW : 0; ssize_t n = getxattr(path, g_name, NULL, 0, 0, fl);
	if (n < 0) { fprintf(stderr, "%s: %s: No such xattr: %s\n", prog, path, g_name); status = 1; return; }
	char *v = malloc((size_t)n + 1); n = getxattr(path, g_name, v, (size_t)n, 0, fl);
	if (many || opt_v) printf("%s: ", path);
	show_value(v, n); free(v);
}
static void write_one(const char *path, int many)
{
	(void)many; int fl = opt_s ? XATTR_NOFOLLOW : 0;
	if (setxattr(path, g_name, g_value, strlen(g_value), 0, fl)) { fprintf(stderr, "%s: [Errno %d] %s: '%s'\n", prog, errno, strerror(errno), path); status = 1; }
}
static void delete_one(const char *path, int many)
{
	(void)many; int fl = opt_s ? XATTR_NOFOLLOW : 0;
	if (removexattr(path, g_name, fl)) { fprintf(stderr, "%s: No such xattr: %s\n", prog, g_name); status = 1; }
}
static void clear_one(const char *path, int many)
{
	(void)many; int fl = opt_s ? XATTR_NOFOLLOW : 0; ssize_t n = listxattr(path, NULL, 0, fl);
	if (n <= 0) return;
	char *names = malloc((size_t)n); n = listxattr(path, names, (size_t)n, fl);
	for (char *p = names; p < names + n; p += strlen(p) + 1) removexattr(path, p, fl);
	free(names);
}
int main(int argc, char **argv)
{
	int mode = 'L', c;
	while ((c = getopt(argc, argv, "pwdclrsvx")) != -1) switch (c) {
		case 'p': case 'w': case 'd': case 'c': mode = c; break;
		case 'l': opt_l = 1; break; case 'r': opt_r = 1; break; case 's': opt_s = 1; break; case 'v': opt_v = 1; break; case 'x': opt_x = 1; break;
		default: fprintf(stderr, "usage: xattr [-rslvx] file ...\n       xattr -p [-rslvx] attr_name file ...\n       xattr -w [-rsx] attr_name attr_value file ...\n       xattr -d [-rsv] attr_name file ...\n       xattr -c [-rsv] file ...\n"); return 2;
	}
	argc -= optind; argv += optind;
	if (mode == 'L') { if (argc < 1) { fprintf(stderr, "usage: xattr [-rslvx] file ...\n"); return 2; } each(argv, list_one, argc > 1); }
	else if (mode == 'p' || mode == 'd') { if (argc < 2) return 2; g_name = argv[0]; each(argv + 1, mode == 'p' ? print_one : delete_one, argc > 2); }
	else if (mode == 'w') { if (argc < 3) return 2; g_name = argv[0]; g_value = argv[1]; each(argv + 2, write_one, 0); }
	else { if (argc < 1) return 2; each(argv, clear_one, 0); }
	return status;
}
