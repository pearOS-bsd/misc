/* Darwin's extended attribute calls over FreeBSD's extattr(2), in the user namespace. */
#include <stdint.h>
#include <sys/types.h>
#include <sys/extattr.h>
#include <sys/xattr.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>

static ssize_t list_common(ssize_t (*get)(void *, char *, size_t), void *h, char *namebuf, size_t size)
{
	ssize_t n = get(h, NULL, 0); if (n <= 0) return n;
	char *raw = malloc((size_t)n); if (!raw) return -1;
	n = get(h, raw, (size_t)n); if (n < 0) { free(raw); return -1; }
	size_t out = 0; ssize_t i = 0;
	while (i < n) {                                                           /* length byte, then the name without a terminator */
		size_t l = (unsigned char)raw[i]; if (i + 1 + (ssize_t)l > n) break;
		if (namebuf) { if (out + l + 1 > size) { free(raw); errno = ERANGE; return -1; } memcpy(namebuf + out, raw + i + 1, l); namebuf[out + l] = 0; }
		out += l + 1; i += 1 + (ssize_t)l;
	}
	free(raw); return (ssize_t)out;
}
static ssize_t lf(void *h, char *b, size_t n) { return extattr_list_file((const char *)h, EXTATTR_NAMESPACE_USER, b, n); }
static ssize_t ll(void *h, char *b, size_t n) { return extattr_list_link((const char *)h, EXTATTR_NAMESPACE_USER, b, n); }
static ssize_t lfd(void *h, char *b, size_t n) { return extattr_list_fd((int)(intptr_t)h, EXTATTR_NAMESPACE_USER, b, n); }

ssize_t listxattr(const char *path, char *namebuf, size_t size, int options) { return list_common((options & XATTR_NOFOLLOW) ? ll : lf, (void *)path, namebuf, size); }
ssize_t flistxattr(int fd, char *namebuf, size_t size, int options) { (void)options; return list_common(lfd, (void *)(intptr_t)fd, namebuf, size); }
ssize_t getxattr(const char *path, const char *name, void *value, size_t size, u_int32_t position, int options)
{ (void)position; return (options & XATTR_NOFOLLOW) ? extattr_get_link(path, EXTATTR_NAMESPACE_USER, name, value, size) : extattr_get_file(path, EXTATTR_NAMESPACE_USER, name, value, size); }
ssize_t fgetxattr(int fd, const char *name, void *value, size_t size, u_int32_t position, int options)
{ (void)position; (void)options; return extattr_get_fd(fd, EXTATTR_NAMESPACE_USER, name, value, size); }
int setxattr(const char *path, const char *name, const void *value, size_t size, u_int32_t position, int options)
{ (void)position; ssize_t r = (options & XATTR_NOFOLLOW) ? extattr_set_link(path, EXTATTR_NAMESPACE_USER, name, value, size) : extattr_set_file(path, EXTATTR_NAMESPACE_USER, name, value, size); return r < 0 ? -1 : 0; }
int fsetxattr(int fd, const char *name, const void *value, size_t size, u_int32_t position, int options)
{ (void)position; (void)options; return extattr_set_fd(fd, EXTATTR_NAMESPACE_USER, name, value, size) < 0 ? -1 : 0; }
int removexattr(const char *path, const char *name, int options)
{ return ((options & XATTR_NOFOLLOW) ? extattr_delete_link(path, EXTATTR_NAMESPACE_USER, name) : extattr_delete_file(path, EXTATTR_NAMESPACE_USER, name)) < 0 ? -1 : 0; }
int fremovexattr(int fd, const char *name, int options) { (void)options; return extattr_delete_fd(fd, EXTATTR_NAMESPACE_USER, name) < 0 ? -1 : 0; }
