/* <mach/mach.h> for the wsbsd SDK: the names Mach-using sources mention. There is no Mach IPC: every call reports failure, so code that needs it (a privileged
 * helper reached through launchd, say) finds it unavailable and carries on without. */
#ifndef WSBSD_MACH_MACH_H
#define WSBSD_MACH_MACH_H
#if defined(__APPLE__)
#include_next <mach/mach.h>
#else
#include <stdint.h>
#include <mach/port.h>
#include <mach/message.h>
#include <mach/mach_time.h>
#define KERN_FAILURE 5
#define KERN_INVALID_ARGUMENT 4
#define MACH_PORT_RIGHT_SEND 0
#define MACH_PORT_RIGHT_RECEIVE 1
#define MACH_MSG_TYPE_MOVE_RECEIVE 16
#define MACH_MSG_TYPE_MOVE_SEND 17
#define MACH_MSG_TYPE_COPY_SEND 19
#define MACH_MSG_TYPE_MAKE_SEND 20
typedef uint64_t mach_vm_address_t;
typedef uint64_t vm_address_t;
typedef uint64_t mach_vm_size_t;
typedef unsigned int mach_msg_type_number_t;
typedef unsigned int mach_msg_type_name_t;
typedef mach_port_t task_t;
typedef mach_port_t ipc_space_t;
static inline mach_port_t mach_task_self(void) { return 1; }
static inline kern_return_t mach_port_allocate(ipc_space_t t, mach_port_right_t r, mach_port_t *p) { (void)t; (void)r; if (p) *p = MACH_PORT_NULL; return KERN_FAILURE; }
static inline kern_return_t mach_port_insert_right(ipc_space_t t, mach_port_t n, mach_port_t p, mach_msg_type_name_t w) { (void)t; (void)n; (void)p; (void)w; return KERN_FAILURE; }
static inline kern_return_t mach_port_deallocate(ipc_space_t t, mach_port_t n) { (void)t; (void)n; return KERN_FAILURE; }
static inline kern_return_t mach_port_mod_refs(ipc_space_t t, mach_port_t n, mach_port_right_t r, int d) { (void)t; (void)n; (void)r; (void)d; return KERN_FAILURE; }
static inline kern_return_t vm_deallocate(task_t t, uint64_t a, uint64_t s) { (void)t; (void)a; (void)s; return KERN_FAILURE; }
static inline const char *mach_error_string(kern_return_t e) { (void)e; return "Mach IPC is not available on this system"; }
#endif
#endif
