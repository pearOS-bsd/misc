/* Force-included in every translation unit the build driver compiles: what Apple's SDK headers pull in transitively and sources rely on without asking. */
#ifndef WSBSD_PRELUDE_H
#define WSBSD_PRELUDE_H
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <fcntl.h>
#include <unistd.h>
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
#endif
#endif
