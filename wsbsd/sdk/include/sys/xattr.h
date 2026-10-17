/* <sys/xattr.h> for the wsbsd SDK: the Darwin extended attribute calls over FreeBSD's extattr(2) (user namespace); implemented in sdk/src/xattr.c. */
#ifndef WSBSD_SYS_XATTR_H
#define WSBSD_SYS_XATTR_H
#if defined(__APPLE__)
#include_next <sys/xattr.h>
#else
#include <sys/types.h>
#include <stddef.h>
#define XATTR_NOFOLLOW 0x0001
#define XATTR_CREATE 0x0002
#define XATTR_REPLACE 0x0004
#define XATTR_NOSECURITY 0x0008
#define XATTR_SHOWCOMPRESSION 0x0020
#define XATTR_MAXNAMELEN 127
#ifdef __cplusplus
extern "C" {
#endif
ssize_t listxattr(const char *path, char *namebuf, size_t size, int options);
ssize_t flistxattr(int fd, char *namebuf, size_t size, int options);
ssize_t getxattr(const char *path, const char *name, void *value, size_t size, u_int32_t position, int options);
ssize_t fgetxattr(int fd, const char *name, void *value, size_t size, u_int32_t position, int options);
int setxattr(const char *path, const char *name, const void *value, size_t size, u_int32_t position, int options);
int fsetxattr(int fd, const char *name, const void *value, size_t size, u_int32_t position, int options);
int removexattr(const char *path, const char *name, int options);
int fremovexattr(int fd, const char *name, int options);
#ifdef __cplusplus
}
#endif
#endif
#endif
