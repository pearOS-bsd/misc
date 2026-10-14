/* Mach message layouts (64-bit), as used by the SkyLight MIG subsystem. Written from docs/SPEC-SLS-WIRE.md. */
#ifndef MACH_COMPAT_H
#define MACH_COMPAT_H
#include <stddef.h>
#include <stdint.h>

typedef uint32_t mach_port_name_t;

typedef struct {
	uint32_t msgh_bits, msgh_size, msgh_remote_port, msgh_local_port, msgh_voucher_port;
	int32_t msgh_id;
} mach_msg_header_t;

typedef struct { uint8_t mig_vers, if_vers, reserved1, mig_encoding, int_rep, char_rep, float_rep, reserved2; } NDR_record_t;

typedef struct { uint32_t msgh_descriptor_count; } mach_msg_body_t;

typedef struct { mach_port_name_t name; uint32_t pad1; uint16_t pad2; uint8_t disposition, type; } mach_msg_port_descriptor_t;
typedef struct { uint64_t address; uint8_t deallocate, copy, pad1, type; uint32_t size; } mach_msg_ool_descriptor_t;

#define MACH_MSGH_BITS_COMPLEX 0x80000000u
#define MACH_MSG_TYPE_MOVE_SEND 17
#define MACH_MSG_TYPE_MOVE_SEND_ONCE 18
#define MACH_MSG_TYPE_COPY_SEND 19
#define MACH_MSG_TYPE_MAKE_SEND_ONCE 21
#define MACH_MSG_PORT_DESCRIPTOR 0
#define MACH_MSG_OOL_DESCRIPTOR 1
#define MACH_MSG_VIRTUAL_COPY 1
#define MACH_MSGH_BITS(remote, local) ((uint32_t)(remote) | ((uint32_t)(local) << 8))

/* standard NDR record, little endian (observed on macOS 27.0) */
static const NDR_record_t WS_NDR = { 0, 0, 0, 0, 1, 0, 0, 0 };

#define MIG_TYPE_ERROR      (-300)
#define MIG_BAD_ID          (-303)
#define MIG_BAD_ARGUMENTS   (-304)
#define MACH_ERROR_REPLY_ID 71
#define CGS_ERROR_FAILURE   1000
#define CGS_ERROR_ILLEGAL_ARGUMENT 1001

_Static_assert(sizeof(mach_msg_header_t) == 24, "header");
_Static_assert(sizeof(NDR_record_t) == 8, "ndr");
_Static_assert(sizeof(mach_msg_port_descriptor_t) == 12, "port descriptor");
_Static_assert(sizeof(mach_msg_ool_descriptor_t) == 16, "ool descriptor");
#endif
