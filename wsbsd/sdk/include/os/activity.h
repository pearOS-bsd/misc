#ifndef WSBSD_OS_ACTIVITY_H
#define WSBSD_OS_ACTIVITY_H
typedef void *os_activity_t;
#define OS_ACTIVITY_NONE ((os_activity_t)0)
#define OS_ACTIVITY_CURRENT ((os_activity_t)0)
#define os_activity_create(d, p, f) ((os_activity_t)0)
#define os_activity_initiate(d, f, block) do { block(); } while (0)
#define os_activity_apply(a, block) do { block(); } while (0)
#endif
