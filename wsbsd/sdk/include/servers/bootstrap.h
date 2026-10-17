/* <servers/bootstrap.h> for the wsbsd SDK: no launchd, no bootstrap ports. */
#ifndef WSBSD_BOOTSTRAP_H
#define WSBSD_BOOTSTRAP_H
#include <mach/mach.h>
#define BOOTSTRAP_SUCCESS 0
#define BOOTSTRAP_UNKNOWN_SERVICE 1102
static mach_port_t bootstrap_port = MACH_PORT_NULL;
static inline kern_return_t bootstrap_look_up(mach_port_t b, const char *n, mach_port_t *p) { (void)b; (void)n; if (p) *p = MACH_PORT_NULL; return BOOTSTRAP_UNKNOWN_SERVICE; }
static inline kern_return_t bootstrap_check_in(mach_port_t b, const char *n, mach_port_t *p) { (void)b; (void)n; if (p) *p = MACH_PORT_NULL; return BOOTSTRAP_UNKNOWN_SERVICE; }
#endif
