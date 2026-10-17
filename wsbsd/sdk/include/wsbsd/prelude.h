/* Force-included in every translation unit the build driver compiles: what Apple's SDK headers pull in transitively and sources rely on without asking. */
#ifndef WSBSD_PRELUDE_H
#define WSBSD_PRELUDE_H
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <fcntl.h>
#include <unistd.h>
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
#include <sys/disk.h>
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
