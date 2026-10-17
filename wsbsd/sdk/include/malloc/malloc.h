/* <malloc/malloc.h> for the wsbsd SDK: the size queries of Darwin's malloc, over the system allocator's. */
#ifndef WSBSD_MALLOC_MALLOC_H
#define WSBSD_MALLOC_MALLOC_H
#if defined(__APPLE__)
#include_next <malloc/malloc.h>
#else
#include <stddef.h>
#include <stdlib.h>
#if defined(__FreeBSD__)
#include <malloc_np.h>
#else
#include <malloc.h>
#endif
static inline size_t malloc_size(const void *p) { return p ? malloc_usable_size((void *)p) : 0; }
/* the size malloc would really hand out for a request: rounded up to the allocator's quantum */
static inline size_t malloc_good_size(size_t n) { return n <= 16 ? 16 : (n + 15) & ~(size_t)15; }
#endif
#endif
