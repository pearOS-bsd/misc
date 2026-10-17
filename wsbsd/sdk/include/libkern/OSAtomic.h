/* <libkern/OSAtomic.h> for the wsbsd SDK, over the compiler's atomic builtins (Darwin's own are deprecated for the same replacements). */
#ifndef WSBSD_OSATOMIC_H
#define WSBSD_OSATOMIC_H
#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
static inline int32_t OSAtomicAdd32(int32_t n, volatile int32_t *p) { return __atomic_add_fetch(p, n, __ATOMIC_SEQ_CST); }
static inline int32_t OSAtomicAdd32Barrier(int32_t n, volatile int32_t *p) { return __atomic_add_fetch(p, n, __ATOMIC_SEQ_CST); }
static inline int32_t OSAtomicIncrement32(volatile int32_t *p) { return __atomic_add_fetch(p, 1, __ATOMIC_SEQ_CST); }
static inline int32_t OSAtomicIncrement32Barrier(volatile int32_t *p) { return __atomic_add_fetch(p, 1, __ATOMIC_SEQ_CST); }
static inline int32_t OSAtomicDecrement32(volatile int32_t *p) { return __atomic_sub_fetch(p, 1, __ATOMIC_SEQ_CST); }
static inline int32_t OSAtomicDecrement32Barrier(volatile int32_t *p) { return __atomic_sub_fetch(p, 1, __ATOMIC_SEQ_CST); }
static inline int64_t OSAtomicAdd64(int64_t n, volatile int64_t *p) { return __atomic_add_fetch(p, n, __ATOMIC_SEQ_CST); }
static inline int64_t OSAtomicAdd64Barrier(int64_t n, volatile int64_t *p) { return __atomic_add_fetch(p, n, __ATOMIC_SEQ_CST); }
static inline int64_t OSAtomicIncrement64Barrier(volatile int64_t *p) { return __atomic_add_fetch(p, 1, __ATOMIC_SEQ_CST); }
static inline int64_t OSAtomicDecrement64Barrier(volatile int64_t *p) { return __atomic_sub_fetch(p, 1, __ATOMIC_SEQ_CST); }
static inline int64_t OSAtomicIncrement64(volatile int64_t *p) { return __atomic_add_fetch(p, 1, __ATOMIC_SEQ_CST); }
static inline int64_t OSAtomicDecrement64(volatile int64_t *p) { return __atomic_sub_fetch(p, 1, __ATOMIC_SEQ_CST); }
static inline bool OSAtomicCompareAndSwap32(int32_t o, int32_t n, volatile int32_t *p) { return __atomic_compare_exchange_n(p, &o, n, false, __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST); }
static inline bool OSAtomicCompareAndSwap32Barrier(int32_t o, int32_t n, volatile int32_t *p) { return OSAtomicCompareAndSwap32(o, n, p); }
static inline bool OSAtomicCompareAndSwap64(int64_t o, int64_t n, volatile int64_t *p) { return __atomic_compare_exchange_n(p, &o, n, false, __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST); }
static inline bool OSAtomicCompareAndSwap64Barrier(int64_t o, int64_t n, volatile int64_t *p) { return OSAtomicCompareAndSwap64(o, n, p); }
static inline bool OSAtomicCompareAndSwapInt(int o, int n, volatile int *p) { return __atomic_compare_exchange_n(p, &o, n, false, __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST); }
static inline bool OSAtomicCompareAndSwapLong(long o, long n, volatile long *p) { return __atomic_compare_exchange_n(p, &o, n, false, __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST); }
static inline bool OSAtomicCompareAndSwapPtr(void *o, void *n, void *volatile *p) { return __atomic_compare_exchange_n(p, &o, n, false, __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST); }
static inline bool OSAtomicCompareAndSwapPtrBarrier(void *o, void *n, void *volatile *p) { return OSAtomicCompareAndSwapPtr(o, n, p); }
static inline int32_t OSAtomicOr32(uint32_t m, volatile uint32_t *p) { return (int32_t)__atomic_or_fetch(p, m, __ATOMIC_SEQ_CST); }
static inline int32_t OSAtomicAnd32(uint32_t m, volatile uint32_t *p) { return (int32_t)__atomic_and_fetch(p, m, __ATOMIC_SEQ_CST); }
static inline int32_t OSAtomicXor32(uint32_t m, volatile uint32_t *p) { return (int32_t)__atomic_xor_fetch(p, m, __ATOMIC_SEQ_CST); }
static inline bool OSAtomicTestAndSet(uint32_t bit, volatile void *addr) { volatile uint8_t *b = (volatile uint8_t *)addr + (bit >> 3); uint8_t m = (uint8_t)(0x80 >> (bit & 7)); return (__atomic_fetch_or(b, m, __ATOMIC_SEQ_CST) & m) != 0; }
static inline void OSMemoryBarrier(void) { __atomic_thread_fence(__ATOMIC_SEQ_CST); }
typedef int32_t OSSpinLock;
#define OS_SPINLOCK_INIT 0
static inline void OSSpinLockLock(volatile OSSpinLock *l) { while (__atomic_exchange_n(l, 1, __ATOMIC_ACQUIRE)) {} }
static inline bool OSSpinLockTry(volatile OSSpinLock *l) { return !__atomic_exchange_n(l, 1, __ATOMIC_ACQUIRE); }
static inline void OSSpinLockUnlock(volatile OSSpinLock *l) { __atomic_store_n(l, 0, __ATOMIC_RELEASE); }
/* OSQueue: a LIFO list of elements linked through a pointer at `offset` (the head holds a spin lock; the Darwin one is lock-free) */
typedef struct { void *opaque1; long opaque2; } OSQueueHead;
#define OS_ATOMIC_QUEUE_INIT { NULL, 0 }
static inline void OSAtomicEnqueue(OSQueueHead *h, void *elem, size_t off) { while (__atomic_exchange_n(&h->opaque2, 1, __ATOMIC_ACQUIRE)) {} *(void **)((char *)elem + off) = h->opaque1; h->opaque1 = elem; __atomic_store_n(&h->opaque2, 0, __ATOMIC_RELEASE); }
static inline void *OSAtomicDequeue(OSQueueHead *h, size_t off) { while (__atomic_exchange_n(&h->opaque2, 1, __ATOMIC_ACQUIRE)) {} void *e = h->opaque1; if (e) h->opaque1 = *(void **)((char *)e + off); __atomic_store_n(&h->opaque2, 0, __ATOMIC_RELEASE); return e; }
#endif
