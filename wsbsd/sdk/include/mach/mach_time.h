/* <mach/mach_time.h> for the wsbsd SDK: mach_absolute_time over the monotonic clock, in nanoseconds (so the timebase is 1/1). */
#ifndef WSBSD_MACH_TIME_H
#define WSBSD_MACH_TIME_H
#include <stdint.h>
#include <time.h>
#include <mach/clock_types.h>
#ifdef CLOCK_BOOTTIME
#define WSBSD_CONTINUOUS_CLOCK CLOCK_BOOTTIME
#else
#define WSBSD_CONTINUOUS_CLOCK CLOCK_MONOTONIC
#endif
typedef struct mach_timebase_info { uint32_t numer; uint32_t denom; } mach_timebase_info_data_t, *mach_timebase_info_t;
static inline uint64_t mach_absolute_time(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return (uint64_t)t.tv_sec * 1000000000ull + (uint64_t)t.tv_nsec; }
static inline uint64_t mach_continuous_time(void) { struct timespec t; clock_gettime(WSBSD_CONTINUOUS_CLOCK, &t); return (uint64_t)t.tv_sec * 1000000000ull + (uint64_t)t.tv_nsec; }
static inline int mach_timebase_info(mach_timebase_info_t i) { i->numer = 1; i->denom = 1; return 0; }
#endif
