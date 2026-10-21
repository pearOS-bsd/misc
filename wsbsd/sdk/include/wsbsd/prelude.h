/* Force-included in every translation unit the build driver compiles: what Apple's SDK headers pull in transitively and sources rely on without asking. */
#ifndef WSBSD_PRELUDE_H
#define WSBSD_PRELUDE_H
#include <stdint.h>
#if defined(__cplusplus) && !defined(__OBJC__) && !defined(nil)
#define nil nullptr   /* Apple's headers reach objc.h's nil from C++ */
#endif
#include <stddef.h>
#include <stdbool.h>
#if __has_include(<CoreFoundation/CFCGTypes.h>)
#include <CoreFoundation/CFCGTypes.h>     /* struct CGRect first: Opal otherwise names the rectangle _NSRect in C++ files (the symbols of CGRect parameters then differ from the Objective-C++ ones) */
#endif
#include <fcntl.h>
#include <unistd.h>
#ifndef __APPLE__
#include <sys/wait.h>                 /* WNOHANG and friends: Apple's headers reach them through <sys/types.h> users */
#include <sys/resource.h>             /* RLIMIT_NOFILE, getrlimit: Apple's <sys/wait.h> includes it */
/* fcntl(F_GETPATH): the path of an open descriptor, answered through FreeBSD's F_KINFO (sdk/src/FileManager.c); every other command goes to the system call */
#define F_GETPATH 50
#ifdef __cplusplus
extern "C"
#endif
int wsbsd_fcntl(int fd, int cmd, ...);
#define fcntl wsbsd_fcntl
/* the Darwin system calls and constants that sources use without a second thought (sdk/src/CoreServicesMisc.c): exchangedata, confstr's user directories, and flags FreeBSD has no use for */
#include <spawn.h>
#include <sys/mount.h>
#ifndef POSIX_SPAWN_CLOEXEC_DEFAULT
#define POSIX_SPAWN_CLOEXEC_DEFAULT 0   /* descriptors without O_CLOEXEC are inherited here */
#endif
#ifndef MNT_DONTBROWSE
#define MNT_DONTBROWSE 0
#endif
#define _CS_DARWIN_USER_DIR 65536
#define _CS_DARWIN_USER_TEMP_DIR 65537
#define _CS_DARWIN_USER_CACHE_DIR 65538
#ifdef __cplusplus
extern "C" {
#endif
size_t wsbsd_confstr(int name, char *buf, size_t len);
int exchangedata(const char *path1, const char *path2, unsigned int options);
#ifndef O_EVTONLY
#define O_EVTONLY O_RDONLY            /* a descriptor opened only to watch the file (kqueue vnode events work on a read-only one) */
#endif
char *basename_r(const char *path, char *bname);          /* Darwin's reentrant basename / dirname: the result goes to the caller's buffer (PATH_MAX) */
char *dirname_r(const char *path, char *dname);
struct timespec;
int gethostuuid(unsigned char uuid[16], const struct timespec *wait);               /* the machine's hardware UUID: kern.hostuuid */
#ifdef __cplusplus
}
#endif
#define confstr wsbsd_confstr
/* <libutil.h> of FreeBSD declares a type called `properties`, which collides with instance variables of that name */
#define properties wsbsd_libutil_properties
#include <libutil.h>
#undef properties
#ifndef WEAK_IMPORT_ATTRIBUTE
#define WEAK_IMPORT_ATTRIBUTE __attribute__((weak))        /* Apple's weak_import: an ELF weak reference */
#endif
#ifdef __cplusplus
/* libdispatch types the main queue and the global queues as unrelated classes in C++; Apple's headers make them subclasses of dispatch_queue_t, so `cond ? main : global` compiles there */
#include <dispatch/dispatch.h>
static inline dispatch_queue_t wsbsd_main_queue(void) { return (dispatch_queue_t)dispatch_get_main_queue(); }
static inline dispatch_queue_t wsbsd_global_queue(long p, unsigned long f) { return (dispatch_queue_t)dispatch_get_global_queue(p, f); }
#undef dispatch_get_main_queue
#define dispatch_get_main_queue() wsbsd_main_queue()
#define dispatch_get_global_queue(p, f) wsbsd_global_queue(p, f)
#endif
/* nullability keywords of Apple's SDK spelt with underscores */
#ifndef __nullable
#define __nullable _Nullable
#define __nonnull _Nonnull
#define __null_unspecified _Null_unspecified
#endif
#endif
#ifndef __APPLE__
typedef uint64_t uint64; typedef uint32_t uint32; typedef uint16_t uint16; typedef uint8_t uint8;      /* MacTypes.h names */
#endif
#if defined(__has_include)
#if __has_include(<CoreServices/FSEvents.h>) && !defined(__APPLE__)
#include <CoreServices/FSEvents.h>   /* Apple's Foundation reaches FSEvents; sources name it without asking */
#endif
#endif
#if defined(__aarch64__) && !defined(__arm64__)
#define __arm64__ 1          /* Apple's name for the same CPU: sources test it */
#endif
#ifndef F_NOCACHE
#define F_NOCACHE 48                    /* Darwin: bypass the buffer cache; fcntl reports EINVAL here, callers ignore it */
#endif
#ifndef DKIOCGETBLOCKCOUNT
#define DKIOCGETBLOCKCOUNT 0x40086419UL   /* Darwin's request number: not a disk ioctl here, it fails and callers take their error path */
#endif
#if defined(__FreeBSD__)
/* the two disk ioctls by number: <sys/disk.h> pulls in <sys/conf.h>, which declares `struct file` and breaks C++ code that has a namespace of that name */
#include <sys/ioccom.h>
#ifndef DIOCGSECTORSIZE
#define DIOCGSECTORSIZE _IOR('d', 128, unsigned int)
#define DIOCGMEDIASIZE _IOR('d', 129, off_t)
#endif
#ifndef DKIOCGETBLOCKSIZE
#define DKIOCGETBLOCKSIZE DIOCGSECTORSIZE
#endif
/* Foundation annotation macros of newer SDKs; they only steer analysis, Swift and optimisation */
#ifndef NS_RETURNS_INNER_POINTER
#define NS_RETURNS_INNER_POINTER __attribute__((objc_returns_inner_pointer))
#endif
#ifndef NS_SWIFT_UI_ACTOR
#define NS_SWIFT_UI_ACTOR
#endif
#ifndef NS_SWIFT_NAME
#define NS_SWIFT_NAME(...)
#endif
#ifndef NS_SWIFT_UNAVAILABLE
#define NS_SWIFT_UNAVAILABLE(...)
#endif
#ifndef NS_REFINED_FOR_SWIFT
#define NS_REFINED_FOR_SWIFT
#endif
#ifndef NS_SWIFT_SENDABLE
#define NS_SWIFT_SENDABLE
#endif
#ifndef NS_SWIFT_NONISOLATED
#define NS_SWIFT_NONISOLATED
#endif
#ifndef NS_NOESCAPE
#define NS_NOESCAPE __attribute__((noescape))
#endif
#ifndef NS_REQUIRES_SUPER
#define NS_REQUIRES_SUPER __attribute__((objc_requires_super))
#endif
#ifndef NS_DESIGNATED_INITIALIZER
#define NS_DESIGNATED_INITIALIZER __attribute__((objc_designated_initializer))
#endif
#endif
#endif
#ifndef ULONG_LONG_MAX
#include <limits.h>
#ifndef ULONG_LONG_MAX
#define ULONG_LONG_MAX ULLONG_MAX
#endif
#endif

#include <sys/stat.h>
#ifndef SF_DATALESS
#define SF_DATALESS 0x40000000        /* macOS: file content not downloaded (iCloud etc.); never set here */
#endif
