# SkyLight WindowServer wire protocol: functional specification

Source of the facts below: macOS 27.0 (26A5416b) SkyLight, decompiled with REA/Ghidra (`__X*` server routines and the
`_SLSNewWindow*` client path), plus black-box probes of the running system (`SLSNewWindow`, `CGSNewRegionWithRect`, region
serialisation). This document states facts and layouts only. The implementation (`include/mach_compat.h`, `sls_wire.h`,
`src/region.c`, `src/ipc.c`, `src/wsd.c`) is our own code written from this text.
Tag on each fact: **[D]** read from decompiled code, **[P]** observed by probing the live system, **[I]** inferred.

## 1. Transport on macOS and how we map it
Requests are Mach messages sent to the WindowServer's service port; the reply comes back on a per-thread reply port. [D]
We do not have Mach ports on FreeBSD. wsbsd keeps the message bytes identical and replaces only the transport:
* one `AF_UNIX` `SOCK_SEQPACKET` datagram per message (FreeBSD). macOS test builds use `SOCK_STREAM` with a 4-byte length prefix;
* the datagram is `[Mach message, msgh_size bytes][out-of-line payloads, in descriptor order]`;
* a port descriptor's `name` is a 1-based index into the file descriptors passed with `SCM_RIGHTS` (0 = none);
* `msgh_local_port` of a delivered request is the server-assigned connection id (on macOS it is the connection's port). [D: `_CGXConnectionForPort(param_1[3])`]

## 2. Message header and descriptors (Mach, 64-bit)
`mach_msg_header_t` 24 bytes: `bits, size, remote_port, local_port, voucher_port, id`. Complex messages add
`u32 descriptor_count` at 0x18 and descriptors from 0x1c. Port descriptor 12 bytes (`name, pad, pad2:16, disposition:8, type:8`),
OOL descriptor 16 bytes (`address:64, deallocate:8, copy:8, pad:8, type:8, size:32`). [D]
Observed request bits for CreateWindow: `0x80001513` = complex | COPY_SEND (0x13) | MAKE_SEND_ONCE (0x15) << 8. [D]
NDR record on this system: `00 00 00 00 01 00 00 00`. [P]
Reply id = request id + 100. Error reply id = 71 with a return code. [D]
Server validity rule used by every routine: a request that is complex when it should not be, or has the wrong `msgh_size`,
gets return code `0xfffffed0` (MIG_BAD_ARGUMENTS); a complex request whose descriptor type or size is wrong gets `0xfffffed4`
(MIG_TYPE_ERROR). [D]

## 3. Subsystems
SkyLight serves **five** MIG subsystems, each a table of 40-byte routine descriptors preceded by a header
`{server, start id, end id, max message size}`: 29000..29041 (max 0x44), 30000..30646 (0x12060, 647 slots, 67 unused),
32000..32073 (0x1034), 33000..33028 (0x38), 34000..34009 (0x48). Entry `i` is id `start + i`; each entry records the argument
count and the maximum reply size. 728 routines are named. Table: `docs/skylight-msgid-table.txt`, header: `include/sls_msgids.h`. [D]
Connection routines (NewConnectionPort, GetEventShmem, Show/HideCursor, ...) are in the 32000 subsystem, display routines in 34000.

## 4. Routines implemented by wsbsd
Simple message layout: header (24), NDR (8) at 0x18, arguments from 0x20. Simple reply: header, NDR, `i32 retcode` at 0x20, 36 bytes.

| id | routine | request | notes |
|---|---|---|---|
| 30005 | TerminateWindow | 36 B: `u32 wid`@0x20 | releases the window if the connection holds rights; return 0 either way [D] |
| 30006 | MoveWindow | 44 B: `wid`@0x20, `i32 x`@0x24, `i32 y`@0x28 | moves the window **origin to (x,y)**; no rights: return 1000 [D][P] |
| 30010 | OrderWindow | 44 B: `wid`, `i32 op`@0x24, `u32 relative`@0x28 | op 1 above, -1 below, 0 out; no rights: 1000 [D] |
| 30012 | SetWindowLevel | 40 B: `wid`, `i32 level`@0x24 | no rights: ignored, return 0 [D][P] |
| 30041 | SetWindowListAlpha | 44 B: `wid`, `u32 a`@0x24, `u32 b`@0x28 | `a` is the alpha as float bits [I]; `b` unknown (fade parameter?) [I] |
| 30008 | MoveWindowList | variable: `i32 dx`@0x20, `i32 dy`@0x24, `u32 n`@0x28 (n <= 0x400), n window ids from 0x2c; size must be 0x2c + 4n | **relative** move by (dx,dy); each window needs rights (types 1 or 4) else skipped; n = 0: 1000; bad size: -304 [D] |
| 30011 | OrderWindowList | variable: `u32 n`, n ids, `u32 m`, m ops, `u32 k`, k relatives (counts <= 0x400, size = 0x2c + 4(n+m+k)) | validated as a chain; bad: -304. Per-index pairing of ids, ops and relatives is inferred [I] |
| 30013 | GetWindowLevel | 36 B: wid | reply 40 B: retcode, `i32 level`@0x24; unknown window: 1000 with a 36 B reply [D] |
| 30014 | FindWindow | 56 B: `u32 wid`@0x20 (purpose unknown), `u32`@0x24, `i32 x`@0x28, `i32 y`@0x2c, 8 more bytes | reply 52 B: retcode, 8 zero bytes@0x24, `u32 window id`@0x2c, `u32 owner connection id`@0x30 [D]; the first field is ignored by wsbsd [I] |
| 30042 | GetWindowAlpha | 36 B: wid | reply 40 B, `float alpha`@0x24; an unknown window still returns 0 with value 0 [D][P] |
| 30059 | GetWindowShapeBounds | 36 B: wid | reply 52 B: four `i32` @0x24..0x30 = window-relative x, y, width, height of the shape [D] |
| 30060 | GetWindowFrameBounds | 36 B: wid | reply 68 B: four unaligned `double` @0x24 = x, y, w, h (null rect: x=y=+inf, w=h=0); unknown: 1000 [D] |
| 30063 | GetWindowCount | 36 B: connection id@0x20 | reply 40 B: number of windows held by that connection [D][I] |
| 30068 | GetOnScreenWindowCount | 36 B: connection id@0x20 | reply 40 B: windows of that connection that are ordered in [D][I] |
| 30070 | GetWindowOwner | 36 B: wid | reply 48 B: owner connection id@0x24, rights@0x28 (wsbsd: 5 for the owner, else 0 [I]), 0@0x2c; no window or connection: 1000 [D] |
| 30434 | SetWindowSubLevel | 40 B: wid, `i32`@0x24 cast to a 16-bit short | needs rights, else ignored; return 0 [D] |
| 30435 | GetWindowSubLevel | 36 B: wid | reply 40 B: the short sign-extended; unknown: 1000 [D] |
| 32000 | NewConnectionPort | complex, variable: count=2, port descriptors A@0x1c and B@0x28 (both MOVE_SEND), NDR@0x34, `u32`@0x3c, `u32 name_len`@0x40 (<= 0x400), name padded to 4 from 0x44, four `u32`; size = pad4(name_len) + 0x54 | reply 0x40: count=2, port MAKE_SEND@0x1c, port MOVE_SEND@0x28, NDR@0x34, `u32`@0x3c (connection id). Wrong disposition: -300; bad sizes or count: -304 [D]. The four trailing `u32` and `@0x3c` are not understood. wsbsd: the first port is this socket, the second is a socketpair end used as the **event channel**; a second handshake on a connection fails (1000) [I] |
| 32001 | ConnectionGetPIDAndVersion | 36 B: connection id@0x20 | reply 0x2c: 8 bytes@0x24 copied from connection state, unknown connection: 1002 [D]; wsbsd returns the peer pid in the low word [I] |
| 30051 | SetWindowEventMask | 40 B: wid, `i32 mask` | needs rights, stored at window+0x7bc; return 0 [D]; the bit meanings are unknown, wsbsd stores the value only |
| 30124 | WarpCursorPosition | 44 B: `i32 x`@0x20, `i32 y`@0x24, `float interval`@0x28 | warps first, then validates 0 <= interval <= 10 (else 1007); not allowed: 1003 [D] |
| 30135 | GetCursorScale | 24 B (header only) | reply 0x28: `float`@0x24 [D]; wsbsd returns 1.0 |
| 30121 | PostEventRecord | variable: `i32 a`@0x20, `float interval`@0x24, `u32 use_current_flags`@0x28, `u32`@0x2c, `u32`@0x30, `u32 record_len`@0x34 (<= 0x4000), event record from 0x38; size = pad4(record_len) + 0x38 | bad sizes: -304; empty record: 1001; undecodable record: 1000; sender may not synthesise: 1002 [D]. The field meanings of the five small fields come from how `decodeEventRecordForPost` uses them (flags merge, suppression interval) and are weakly inferred [I] |
| 30090 | AddSurface | 36 B: wid | needs write access (else 1000); reply 40 B: surface id@0x24 from a global counter [D] |
| 30091 | RemoveSurface | 40 B: wid, sid | needs write access (else 1000); unknown surface ignored; return 0 [D] |
| 30093 | BindSurface | 52 B: wid@0x20, sid@0x24, `i32 kind`@0x28, `u32 a`@0x2c, `u32 b`@0x30 | unknown surface: 1001; no write access: 1000. kind 0 unbind; 1 bind to another window's backing (b = source window, needs backing type 2, else 1004); 2 bind to a display accelerator (b = display unit < 0x20 or id); 3: 1001; 4 bind a Core Animation layer context (b = context id); other kinds: no-op success [D]. wsbsd: kind 4 with b = a registered buffer id; kinds 1 and 2 return 1000 |
| 30097 | FlushSurface | complex 72 B: count=1, OOL region@0x1c, NDR@0x2c, wid@0x34, sid@0x38, `flags`@0x3c, `tag`@0x40, `region_size`@0x44 (== descriptor size) | the dirty region (empty = whole surface); window unknown: 1000, surface unknown: 1001, undecodable region: 1000; wrong shape: -304 / -300 [D]. This is the commit: it marks the surface dirty and schedules a display update. Field names for flags and tag are inferred [I] |
| 30109 | GetSurfaceBinding | 40 B: wid, sid | reply 48 B: kind@0x24, a@0x28, b@0x2c as bound; unknown: 1000 [D] |
| 30263 | CreateWindow | 76 B complex, see below | |

CreateWindow request (76 B): header(24), `u32 descriptor_count=1`@0x18, OOL descriptor@0x1c (type 1, copy 1, size = region bytes),
NDR@0x2c, `i32 window_type`@0x34, `u32 region_size`@0x38 (must equal the descriptor size), `u32 flags`@0x3c, `u64 tags`@0x40,
`u32 ca_context_id`@0x48. [D]
`window_type` accepted by the server: 2, 3, 5; others: return 1001 (illegal argument). The live system rejected 0 and 1 with 1000 and
accepted 2. [D][P]
Reply on success (68 B, complex): header, `descriptor_count=1`, port descriptor@0x1c (disposition 0x11 = MOVE_SEND) carrying the
window's shared-memory reference, NDR@0x28, **`u32 window_id`@0x30**, then `u32`@0x34, 0x38, 0x3c (shared window state), 0x40
(colour profile id). [D] On failure: simple reply (36 B) with the return code. [D]
The window shape is the region bytes; the window origin is the region's origin (`SLSNewWindow(cid, type, x, y, region, &wid)` with a
region at (0,0) 300x150 and x=100, y=200 produced bounds (100,200,300,150), level 0, alpha 1). [P]

Rights: `_connection_holds_rights_on_window(conn, type, wid, ...)` with types 1 and 4 guards MoveWindow/OrderWindow/SetWindowListAlpha. [D]
wsbsd models this as: the connection that created the window holds all rights, no other connection holds any. [I]

## 5. Region serialisation (CGS region, used as the OOL payload) [P]
Little-endian `i32` words, a y-banded rectangle list:
```
0x80000000, 2                      header (magic, version?)
y_top                              first band top; 0x7fffffff if the region is empty (then nothing follows)
repeat: n, (n-2) x values, y_next  one band: n = 2 + 2*runs, x values are start,end pairs (end exclusive), y_next is the band bottom
last band: n = 2, y_next = 0x7fffffff
```
Fractional rectangles round outward; adjacent bands with identical runs are merged; negative values are two's complement.
Golden vectors from the live system are in `test/test_region.c`. The meaning of the header word `2` is not known.

## 7. Event records ("modern" format) [P]
The bytes `CGEventCreateData` produces, which `_SLEventRecordCreateWithBytesModern` decodes (the server path of PostEventRecord). Big-endian.
```
u32 2                          leading word
repeat until the end:
  u32 tag                      bits 31..16: 1 = integer, 2 = float; bits 15..14: width class; bits 13..0: field id
  value                        class 1 (0x4000): one 32-bit word; class 3 (0xc000): a pair of floats if float, one 32-bit word if integer;
                               class 0: one 64-bit integer
```
Field ids follow `CGEventField` for the event-specific part (1 click state, 2 pressure, 3 button number, 9 keycode ...).
Header fields seen on every event: 0x35, 0x36, **0x37 event type (CGEventType)**, **0x38 location (two floats)**, 0x39 second location,
**0x3a timestamp (64-bit)**, **0x3b flags**, 0x33, 0x34, 0xa9 second timestamp, 0x6a, 0x6b; mouse events add 0x07, 0x00..0x06, 0x59..0x5c,
0x6c (1 for down events), 0x3c..0x3f; key events add 0x09, 0x08, 0x0a (keyboard type 0x5c), 0x4c..0x52 (0x4d, 0x4e, 0x52 carry the character), 0x7f, 0x80.
Scroll events carry further fields (0x0b, 0x0c, 0x0d, 0x58, 0x89, 0x5d..0x64, 0xad, 0xaf..0xb2). The builders in `src/evrec.c` reproduce the
live system's bytes for mouse moved/down and key down/up exactly (`test/test_evrec.c`); fields whose meaning is unknown are written as the observed constants.

## 8. Surface exchange: what the SkyLight messages carry and what they do not
The attach/bind/flush messages above carry **identifiers only** (surface id, bind kind, a context, display or window id): no buffer handle
travels in them. On macOS the pixels reach the compositor through other channels (a Core Animation remote context for kind 4, the
accelerator for kind 2). The IOSurface API a client uses to describe a buffer (public, probed): width, height, pixel format, bytes per
element; the result has a **row stride aligned to 128 bytes** (100 px BGRA -> 512, 640 -> 2560, 1 -> 128) and an **allocation rounded up
to 16 KiB** (32768 for 100x50), a global surface id, and can be exported as a transferable right (a Mach port) and looked up again [P].
wsbsd's FreeBSD counterpart (`include/ws_buffer.h`, wsbsd-private message 39020 `WSX_BUFFER_IMPORT`, 39021 release):
the client allocates (GBM `gbm_bo_create` + `gbm_bo_get_fd` -> dma-buf when built with WS_GBM and a render node exists, otherwise anonymous
shared memory), sends the descriptor with SCM_RIGHTS together with width, height, DRM fourcc (AR24 = IOSurface BGRA), stride, offset and
modifier, receives a buffer id, adds a surface (30090), binds it (30093 kind 4, b = buffer id) and commits frames with FlushSurface.
The server keeps the buffer CPU-mapped when it is linear and composes it in place of the window's backing store after the first commit;
for a dma-buf it can also create an `EGLImageKHR` with `EGL_LINUX_DMA_BUF_EXT` for the GL compositor (not run).

## 6. Not covered (so not claimed)
Everything else in the subsystem (about 640 routines), the Core Animation remote-context path (`ca_context_id`, which is how macOS
windows normally receive pixels), the shared-window-state memory layout, shadow property plists, the event shared memory, and the
bootstrap/connection handshake. wsbsd's pixel backing store, flush, screenshot, input injection, event polling and the pushed-event datagrams
(`WSX_EVENT_PUSH` = 39100, sent on the handshake's event channel) use private message ids from 39000 (not SkyLight ids) and a plain BGRA shared-memory buffer instead of the CA path.

## Key focus and cursor visibility (decompiled `__X` routines + `CGXStealKeyFocusReturningID` / `CGXReleaseKeyFocusWithID`)

| id | routine | request | reply |
|---|---|---|---|
| 30136 | ModifyKeyFocus | 0x28: release byte@0x20 (1 = release theft-id 0), options@0x24; connection = `msgh_local_port` | simple |
| 30137 | StealKeyFocusReturningID | 0x24: options@0x20 | 0x28 with the theft id@0x24 on success, 0x24 simple on error |
| 30138 | ReleaseKeyFocusWithID | 0x24: theft id@0x20 (0 = the connection's own plain focus) | simple |
| 30139 | GetKeyFocusProcess | header only | 0x30: PSN hi@0x24, PSN lo@0x28, byte@0x2c = nobody stole it; -600 if none |
| 30140 | GetTypingFocusProcess | header only | 0x28: pid@0x24; -600 if none |
| 32016/32017/32018/32019 | Hide / Show / Obscure / RevealCursor | 0x24: connection id@0x20 (Show: 0x28, force byte@0x24) | simple; Hide 1000 and Obscure 1001 for an unknown connection, Show/Reveal always 0 |

Theft ids come from one counter shared by all connections: 0x65, 0x66, ... wrapping from 0x7fffffff to 0x65. Steal returns 1010 when the caller already
holds key focus and asks for it (options bit 9) or when it already has it by default; -600 when the connection is unknown. Hide counts are per connection,
force-show clears the connection's count, obscure lasts until the mouse moves. Unknown (not modelled): the "lost key focus" notifications sent to the previous
holder, the process-front permission check, PSNs (the connection id stands in for the low word).

## Registered cursors (30128..30133, decompiled `__X*RegisteredCursor*`, client stubs `SLSRegisterCursorWithData2` / `SLSGetRegisteredCursorData2`)

Exact layouts are in `include/sls_wire.h`. Summary: name requests carry `{offset, length <= 0x80, bytes}` from 0x20; `RegisterCursorWithData` is a complex message whose
OOL descriptor holds BGRA premultiplied pixels (`cols * rows * frames`, frames stacked), followed by the name and eleven u32 fields (global, set-now, cols, rows,
width/height in points, hotspot in pixels, pixel count, frames, frame duration). Errors: -304 bad size, -300 bad descriptor type or pixel-count mismatch, 1001 invalid
dimensions (points > 0x400, zero, more pixels than supplied), 1007 unknown name (Set/GetSize/GetData), 1000 for removing `com.apple.coregraphics.*` names.
Set shows the first frame scaled to its size in points; animation is not played. Not yet verified live: the order of the hotspot/size pairs in the GetData reply (taken
from the client stub's output parameters), and the meaning of the cursor seed returned by Register (the cursor serial stands in).
