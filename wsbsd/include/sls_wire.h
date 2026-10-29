/* Request and reply layouts of the SkyLight routines wsbsd implements. Offsets and sizes are the ones recovered from the
 * server routines (see docs/SPEC-SLS-WIRE.md) and are enforced with static asserts. */
#ifndef SLS_WIRE_H
#define SLS_WIRE_H
#include "mach_compat.h"
#include "sls_msgids.h"

/* the SkyLight subsystem limits */
#define SLS_MSGID_BASE 30000
#define SLS_MSGID_END  30647
#define SLS_MAX_MESSAGE 0x12060

/* ---- simple messages: header, NDR, arguments ---- */
typedef struct { mach_msg_header_t h; NDR_record_t ndr; uint32_t wid; } sls_terminate_req;                       /* 36 */
typedef struct { mach_msg_header_t h; NDR_record_t ndr; uint32_t wid; int32_t x, y; } sls_move_req;                /* 44 */
typedef struct { mach_msg_header_t h; NDR_record_t ndr; uint32_t wid; int32_t op; uint32_t relative; } sls_order_req; /* 44 */
typedef struct { mach_msg_header_t h; NDR_record_t ndr; uint32_t wid; int32_t level; } sls_level_req;              /* 40 */
typedef struct { mach_msg_header_t h; NDR_record_t ndr; uint32_t wid; uint32_t alpha_bits, b; } sls_alpha_req;      /* 44 */
typedef struct { mach_msg_header_t h; NDR_record_t ndr; int32_t retcode; } sls_simple_reply;                       /* 36 */

/* read-only window queries; all take a window id (or a connection id for GetWindowCount) */
typedef sls_terminate_req sls_wid_req;                                                                             /* 36 */
typedef struct { mach_msg_header_t h; NDR_record_t ndr; int32_t retcode; int32_t value; } sls_value_reply;        /* 40: GetWindowLevel/Alpha/Count */
typedef struct { mach_msg_header_t h; NDR_record_t ndr; int32_t retcode; double x, y, w, ht; } __attribute__((packed)) sls_bounds_reply; /* 68: GetWindowFrameBounds */
typedef struct { mach_msg_header_t h; NDR_record_t ndr; int32_t retcode; int32_t owner, rights, extra; } sls_owner_reply; /* 48: GetWindowOwner */
typedef struct { mach_msg_header_t h; NDR_record_t ndr; uint32_t wid, unk24; int32_t x, y; uint32_t unk30, unk34; } sls_find_req; /* 56 */
typedef struct { mach_msg_header_t h; NDR_record_t ndr; int32_t retcode; uint64_t zero; uint32_t wid, owner; } __attribute__((packed)) sls_find_reply; /* 52 */

/* key focus and cursor visibility (decompiled __X routines):
 * ModifyKeyFocus 30136 (0x28): release flag@0x20, options@0x24 -- the connection is msgh_local_port; StealKeyFocusReturningID 30137 (0x24): options@0x20,
 * reply 0x28 with the theft id@0x24 on success; ReleaseKeyFocusWithID 30138 (0x24): theft id@0x20; GetKeyFocusProcess 30139 (header only), reply 0x30:
 * PSN hi@0x24, PSN lo@0x28, "nobody stole it" byte@0x2c; GetTypingFocusProcess 30140, reply 0x28: pid@0x24.
 * Hide/Reveal/ObscureCursor 32016/32019/32018 (0x24): connection id@0x20; ShowCursor 32017 (0x28): connection id@0x20, force byte@0x24 */
typedef struct { mach_msg_header_t h; NDR_record_t ndr; int32_t a, b; } sls_two_req;                                    /* 0x28 */
typedef struct { mach_msg_header_t h; NDR_record_t ndr; int32_t retcode; uint32_t psn_hi, psn_lo; uint8_t is_default, pad[3]; } sls_keyproc_reply; /* 0x30 */
typedef struct { mach_msg_header_t h; NDR_record_t ndr; int32_t retcode; int32_t x, y, w, ht; } sls_shape_bounds_reply;  /* 52: GetWindowShapeBounds */
typedef sls_level_req sls_sublevel_req;                                                                           /* 40: SetWindowSubLevel (value cast to short) */
/* variable length: MoveWindowList = header, NDR, i32 dx, i32 dy, u32 n, n window ids (size 0x2c + 4n, n <= 0x400);
 * OrderWindowList = header, NDR, u32 n, n ids, u32 m, m ops, u32 k, k relatives (each count <= 0x400) */
#define SLS_LIST_MAX 0x400

/* ---- connection handshake: NewConnectionPort (id 32000), complex, variable length ----
 * request: header, count=2, port descriptor A@0x1c, port descriptor B@0x28 (both MOVE_SEND), NDR@0x34, u32@0x3c,
 *          u32 name_len@0x40 (<= 0x400), name bytes padded to 4 from 0x44, then four u32 (size = pad4(name_len) + 0x54).
 * reply (0x40): header, count=2, port descriptor@0x1c (MAKE_SEND), port descriptor@0x28 (MOVE_SEND), NDR@0x34, u32 connection id@0x3c. */
typedef struct {
	mach_msg_header_t h; mach_msg_body_t body;
	mach_msg_port_descriptor_t port_a, port_b;
	NDR_record_t ndr; uint32_t unk3c, name_len;
} __attribute__((packed)) sls_new_connection_head;                                                                /* 0x44 */
typedef struct {
	mach_msg_header_t h; mach_msg_body_t body;
	mach_msg_port_descriptor_t port1, port2;
	NDR_record_t ndr; uint32_t connection_id;
} __attribute__((packed)) sls_new_connection_rep;                                                                 /* 0x40 */
typedef struct { mach_msg_header_t h; NDR_record_t ndr; int32_t retcode; uint64_t value; } __attribute__((packed)) sls_pid_version_rep; /* 0x2c */
typedef struct { mach_msg_header_t h; NDR_record_t ndr; int32_t x, y; uint32_t interval_bits; } sls_warp_req;       /* 0x2c: WarpCursorPosition */
typedef sls_level_req sls_eventmask_req;                                                                           /* 0x28: SetWindowEventMask(wid, mask) */
typedef mach_msg_header_t sls_header_only_req;                                                                     /* 0x18: GetCursorScale, GetEventShmem */

/* PostEventRecord (30121): header, NDR, i32 a@0x20, u32 interval float bits@0x24, u32 use_current_flags@0x28, u32@0x2c, u32@0x30,
 * u32 record_len@0x34 (<= 0x4000), record bytes from 0x38; size = pad4(record_len) + 0x38. */
typedef struct { mach_msg_header_t h; NDR_record_t ndr; int32_t a; uint32_t interval_bits, use_flags, u2c, u30, record_len; } sls_post_event_head; /* 0x38 */

/* ---- surfaces (ids 30090..30109): a surface is a slot on a window that a backing is bound to ---- */
typedef sls_level_req sls_surface_req;                                                                             /* 40: RemoveSurface(wid, sid), GetSurfaceBinding */
typedef struct { mach_msg_header_t h; NDR_record_t ndr; uint32_t wid, sid; int32_t kind; uint32_t a, b; } sls_bind_req; /* 52: BindSurface */
typedef struct { mach_msg_header_t h; NDR_record_t ndr; int32_t retcode; int32_t kind; uint32_t a, b; } sls_binding_reply; /* 48: GetSurfaceBinding */
/* FlushSurface (30097), complex: header, count=1, OOL region descriptor@0x1c (dirty region, may be empty), NDR@0x2c, wid@0x34, sid@0x38,
 * flags@0x3c, tag@0x40, region_size@0x44 (must equal the descriptor size); size 0x48. */
typedef struct {
	mach_msg_header_t h; mach_msg_body_t body; mach_msg_ool_descriptor_t region; NDR_record_t ndr;
	uint32_t wid, sid, flags, tag, region_size;
} __attribute__((packed)) sls_flush_surface_req;                                                                  /* 72 */
/* BindSurface kinds: 0 unbind, 1 another window's backing, 2 a display accelerator (OpenGL), 3 invalid, 4 a Core Animation layer context.
 * wsbsd binds kind 4 with b = a registered buffer id. */
enum { SLS_BIND_NONE = 0, SLS_BIND_WINDOW = 1, SLS_BIND_ACCEL = 2, SLS_BIND_INVALID = 3, SLS_BIND_CONTEXT = 4 };

/* ---- CreateWindow (id 30263), complex ---- */
typedef struct {
	mach_msg_header_t h;
	mach_msg_body_t body;
	mach_msg_ool_descriptor_t region;          /* serialised region bytes */
	NDR_record_t ndr;
	int32_t window_type;
	uint32_t region_size;
	uint32_t flags;
	uint64_t tags;
	uint32_t ca_context_id;
} __attribute__((packed)) sls_create_window_req;                                                                  /* 76 */

typedef struct {
	mach_msg_header_t h;
	mach_msg_body_t body;
	mach_msg_port_descriptor_t shmem;          /* window shared-memory reference (here: the pixel buffer fd) */
	NDR_record_t ndr;
	uint32_t window_id;
	uint32_t out34, out38, out3c, out40;
} __attribute__((packed)) sls_create_window_rep;                                                                  /* 68 */

#define OFF(t, f) offsetof(t, f)
_Static_assert(sizeof(sls_bind_req) == 0x34 && OFF(sls_bind_req, sid) == 0x24 && OFF(sls_bind_req, kind) == 0x28 && OFF(sls_bind_req, b) == 0x30, "BindSurface request");
_Static_assert(sizeof(sls_binding_reply) == 0x30 && OFF(sls_binding_reply, kind) == 0x24 && OFF(sls_binding_reply, b) == 0x2c, "GetSurfaceBinding reply");
_Static_assert(sizeof(sls_flush_surface_req) == 0x48 && OFF(sls_flush_surface_req, region) == 0x1c && OFF(sls_flush_surface_req, ndr) == 0x2c &&
               OFF(sls_flush_surface_req, wid) == 0x34 && OFF(sls_flush_surface_req, region_size) == 0x44, "FlushSurface request");
_Static_assert(sizeof(sls_post_event_head) == 0x38 && OFF(sls_post_event_head, record_len) == 0x34, "PostEventRecord head");
_Static_assert(sizeof(sls_new_connection_head) == 0x44 && OFF(sls_new_connection_head, ndr) == 0x34 && OFF(sls_new_connection_head, name_len) == 0x40, "NewConnectionPort request head");
_Static_assert(sizeof(sls_new_connection_rep) == 0x40 && OFF(sls_new_connection_rep, port2) == 0x28 && OFF(sls_new_connection_rep, connection_id) == 0x3c, "NewConnectionPort reply");
_Static_assert(sizeof(sls_pid_version_rep) == 0x2c && OFF(sls_pid_version_rep, value) == 0x24, "ConnectionGetPIDAndVersion reply");
_Static_assert(sizeof(sls_warp_req) == 0x2c, "WarpCursorPosition request");
_Static_assert(sizeof(sls_shape_bounds_reply) == 0x34 && OFF(sls_shape_bounds_reply, x) == 0x24 && OFF(sls_shape_bounds_reply, ht) == 0x30, "GetWindowShapeBounds reply");
_Static_assert(sizeof(sls_value_reply) == 0x28 && OFF(sls_value_reply, value) == 0x24, "value reply");
_Static_assert(sizeof(sls_bounds_reply) == 0x44 && OFF(sls_bounds_reply, x) == 0x24 && OFF(sls_bounds_reply, ht) == 0x3c, "GetWindowFrameBounds reply");
_Static_assert(sizeof(sls_owner_reply) == 0x30 && OFF(sls_owner_reply, owner) == 0x24 && OFF(sls_owner_reply, extra) == 0x2c, "GetWindowOwner reply");
_Static_assert(sizeof(sls_find_req) == 0x38 && OFF(sls_find_req, x) == 0x28 && OFF(sls_find_req, y) == 0x2c, "FindWindow request");
_Static_assert(sizeof(sls_find_reply) == 0x34 && OFF(sls_find_reply, wid) == 0x2c && OFF(sls_find_reply, owner) == 0x30, "FindWindow reply");
_Static_assert(sizeof(sls_terminate_req) == 0x24, "TerminateWindow request");
_Static_assert(sizeof(sls_move_req) == 0x2c && OFF(sls_move_req, x) == 0x24 && OFF(sls_move_req, y) == 0x28, "MoveWindow request");
_Static_assert(sizeof(sls_order_req) == 0x2c && OFF(sls_order_req, op) == 0x24 && OFF(sls_order_req, relative) == 0x28, "OrderWindow request");
_Static_assert(sizeof(sls_level_req) == 0x28 && OFF(sls_level_req, level) == 0x24, "SetWindowLevel request");
_Static_assert(sizeof(sls_alpha_req) == 0x2c, "SetWindowListAlpha request");
_Static_assert(sizeof(sls_simple_reply) == 0x24 && OFF(sls_simple_reply, retcode) == 0x20, "simple reply");
_Static_assert(sizeof(sls_create_window_req) == 0x4c, "CreateWindow request size");
_Static_assert(OFF(sls_create_window_req, region) == 0x1c && OFF(sls_create_window_req, ndr) == 0x2c, "CreateWindow descriptor/NDR");
_Static_assert(OFF(sls_create_window_req, window_type) == 0x34 && OFF(sls_create_window_req, region_size) == 0x38, "CreateWindow type/size");
_Static_assert(OFF(sls_create_window_req, flags) == 0x3c && OFF(sls_create_window_req, tags) == 0x40, "CreateWindow flags/tags");
_Static_assert(OFF(sls_create_window_req, ca_context_id) == 0x48, "CreateWindow context");
_Static_assert(sizeof(sls_create_window_rep) == 0x44, "CreateWindow reply size");
_Static_assert(OFF(sls_create_window_rep, shmem) == 0x1c && OFF(sls_create_window_rep, ndr) == 0x28 && OFF(sls_create_window_rep, window_id) == 0x30, "CreateWindow reply");

/* ---- private wsbsd extension ids (NOT SkyLight ids): flush, screenshot, input injection, events, shadow, quit ---- */
enum {
	WSX_FLUSH = 39001, WSX_SCREENSHOT, WSX_INJECT_MOUSE, WSX_INJECT_KEY, WSX_NEXT_EVENT, WSX_GET_CURSOR,
	WSX_FIND_WINDOW, WSX_SET_SHADOW, WSX_QUIT, WSX_GET_CONNECTION_ID, WSX_GET_SCREEN, WSX_CAPTURE, WSX_SET_CURSOR, WSX_GET_FPS, WSX_SET_GLASS, WSX_SET_KEY, WSX_SET_SPACE, WSX_SET_ACTIVE_SPACE, WSX_GET_ACTIVE_SPACE, WSX_SET_SHUTDOWN_SPLASH, WSX_BUFFER_IMPORT = 39030, WSX_BUFFER_RELEASE, WSX_EVENT_PUSH = 39100, WSX_NOTIFY_PUSH
};
/* private requests share one layout: header, NDR, 8 ints, 128 bytes of text */
typedef struct { mach_msg_header_t h; NDR_record_t ndr; int32_t a[8]; char s[128]; } wsx_req;
typedef struct { mach_msg_header_t h; NDR_record_t ndr; int32_t retcode; int32_t a[8]; } wsx_rep;

/* pushed on the event channel returned by NewConnectionPort (wsbsd private; macOS uses the event shared memory instead) */
/* a notification (PostNotificationToConnection / PostBroadcastNotification) pushed to a connection's event channel: type, then len bytes of data (at most 256) */
typedef struct { mach_msg_header_t h; NDR_record_t ndr; uint32_t type; uint32_t len; uint8_t data[768]; } wsx_notify_msg;
typedef struct { mach_msg_header_t h; NDR_record_t ndr; int32_t type; uint32_t wid; int32_t x, y, buttons, key; uint32_t flags; int32_t dx, dy, continuous; } wsx_event_msg;

/* wsbsd private: register a shared buffer. Complex message: header, count = nplanes, one port descriptor per plane (name = 1-based index into
 * the SCM_RIGHTS descriptors, MOVE_SEND), then NDR and the description. Reply: a value reply carrying the buffer id. */
typedef struct {
	mach_msg_header_t h; mach_msg_body_t body;
	mach_msg_port_descriptor_t plane[4];
	NDR_record_t ndr;
	int32_t kind;                    /* 0 shm, 1 dma-buf */
	int32_t width, height; uint32_t fourcc; int32_t nplanes;
	uint32_t stride[4], offset[4];
	uint64_t modifier;
} __attribute__((packed)) wsx_buffer_import_req;
typedef sls_surface_req wsx_buffer_release_req;               /* wid unused (0), sid field carries the buffer id */
#endif

/* ---- registered cursors (30128..30133), from __XRegisterCursorWithData & co. ----
 * name requests (Set 30128, Is 30129, GetSize 30131, GetData 30132): header, NDR, name offset@0x20, name length@0x24 (<= 0x80), name@0x28;
 * size = pad4(length) + 0x28. Remove 30133: the same plus a "global" byte after the padded name, size = pad4(length) + 0x2c.
 * RegisterCursorWithData 30130 (complex): count=1@0x18, OOL descriptor@0x1c (BGRA premultiplied pixels, type byte@0x27 = 1, size@0x28), NDR@0x2c,
 * name offset@0x34, name length@0x38 (<= 0x80), name@0x3c, then at P = pad4(length): global@P+0x3c (byte), set_now@P+0x40 (byte), cols, rows,
 * width_pts, height_pts, hot_x_px, hot_y_px, npixels (= OOL size / 4), frames, frame_duration (u32 each from P+0x44); size = P + 0x68 in [0x68, 0xe8].
 * Reply: 0x28 with the cursor seed@0x24. GetRegisteredCursorData reply: complex, 0x58: OOL@0x1c (size@0x28), NDR@0x2c, width_px@0x34, height_px@0x38,
 * width_pts@0x3c, height_pts@0x40, hot_x@0x44, hot_y@0x48 (points), bytes@0x4c, frames@0x50, duration@0x54 (a float; order verified live). */
#define SLS_CURSOR_NAME_MAX 0x80
