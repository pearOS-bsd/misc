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
#define MACH_MSGH_BITS_COMPLEX 0x80000000U
#define MACH_MSGH_BITS(remote, local) ((remote) | ((local) << 8))
#define MACH_MSG_PORT_DESCRIPTOR 0
#define MACH_SEND_MSG 1
#define MACH_RCV_MSG 2
typedef struct { mach_msg_bits_t msgh_bits; mach_msg_size_t msgh_size; mach_port_t msgh_remote_port; mach_port_t msgh_local_port; mach_port_t msgh_voucher_port; mach_msg_id_t msgh_id; } mach_msg_header_t;
typedef struct { unsigned int msgh_descriptor_count; } mach_msg_body_t;
typedef struct { mach_port_t name; unsigned int pad1; unsigned short pad2; unsigned char disposition; unsigned char type; } mach_msg_port_descriptor_t;
typedef struct { unsigned int msgh_trailer_type; unsigned int msgh_trailer_size; } mach_msg_trailer_t;
typedef int mach_msg_option_t;
static inline mach_msg_return_t mach_msg(mach_msg_header_t *m, mach_msg_option_t o, mach_msg_size_t s, mach_msg_size_t r, mach_port_t p, mach_msg_timeout_t t, mach_port_t n) { (void)m; (void)o; (void)s; (void)r; (void)p; (void)t; (void)n; return 0x10000001; }
static inline mach_msg_return_t mach_msg_send(mach_msg_header_t *m) { (void)m; return 0x10000001; }
#endif
#endif
