/* <mach/message.h> for the wsbsd SDK: only what headers name; there is no Mach IPC behind it. */
#ifndef WSBSD_MACH_MESSAGE_H
#define WSBSD_MACH_MESSAGE_H
#if defined(__APPLE__)
#include_next <mach/message.h>
#else
#include <stdint.h>
#include <mach/port.h>
typedef unsigned int mach_msg_bits_t;
typedef unsigned int mach_msg_size_t;
typedef int mach_msg_id_t;
typedef unsigned int mach_msg_timeout_t;
typedef int mach_msg_return_t;
#define MACH_MSG_TIMEOUT_NONE 0
#endif
#endif
