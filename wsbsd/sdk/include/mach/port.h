/* <mach/port.h> for the wsbsd SDK: the port types headers mention (CoreFoundation's run loop names a mach port); there is no Mach IPC behind them. */
#ifndef WSBSD_MACH_PORT_H
#define WSBSD_MACH_PORT_H
#if defined(__APPLE__)
#include_next <mach/port.h>
#else
#include <stdint.h>
#ifndef __APPLE__
typedef int mach_port_t;                         /* the same as CoreBase's (ports are pollable descriptors there) */
#endif
typedef mach_port_t *mach_port_array_t;
typedef unsigned int mach_port_name_t;
typedef unsigned int mach_port_right_t;
typedef int kern_return_t;
#define MACH_PORT_NULL 0
#define MACH_PORT_DEAD ((mach_port_t)~0)
#define KERN_SUCCESS 0
#endif
#endif
