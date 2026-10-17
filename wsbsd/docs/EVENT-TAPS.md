# Event tap delivery (client side, from the SkyLight decompile)

The registry (`src/sls_tap.c`) is real; the events are not handed to the tapping process yet. What the client library expects (`eventTapMessageHandler`, `processEventTapData`, `__XPostEventTapData`, `__XPostEventTapDataOOL`):

- The tap's port is the descriptor given to PlaceTap (32028 / 32029). The message the server sends to it uses the CGYEventTap subsystem: id 1 = PostEventTapData, id 2 = PostEventTapDataOOL (reply ids +100, the client answers with the return code at 0x20).
- PostEventTapData (id 1): simple message, size `pad4(n) + 0x30` with `n <= 0x4000`; `u32@0x20` event type (0 = a data stream follows, else a bare event of that type), `u32@0x24` sequence, `u32@0x28` tap proxy id (the id PlaceTap returned), `u32@0x2c` n, data from 0x30.
- PostEventTapDataOOL (id 2): complex, one OOL descriptor (address@0x1c), size 0x44; type@0x34, sequence@0x38, proxy id@0x3c, n@0x28 repeated @0x40.
- The data stream: records of `u32 token (0)`, `u32 length`, `length` bytes of a serialized CGEvent (what `SLEventCreateFromDataAndSource` reads); it ends when fewer than 8 bytes remain. The tap callback may replace, keep or drop each event; the client posts the survivors back with PostFilteredEventTapData (32035 family, `src/wsd.c` `do_post_tap_data`) and acknowledges with EventTapSendDataProcessedAck.
- Taps whose event mask lacks the event's type are not called; a callback returning a corrupt event disables the tap (`disableEventTap`).

Missing for delivery: the serialized CGEvent format. `_SLEventCreateFromDataAndSource` hands the bytes to `_SLEventRecordCreateWithBytesModern`, which decodes an `SLS::TokenizedCoding` stream (a version header, then versions 1 to 3 of `VersionedDecoder`, each filling the 0xf8-byte `SLSEventRecord`; a record with type >= 0x20 is rejected as "unknown event type"); the per-version field tables are templated C++ and still to be decompiled, and how a server-to-client Mach message is carried on wsd's socket for a port received in a descriptor.

## The token stream (`_SLEventRecordCreateWithBytesModern`, version 1 lambda at 0x18715dd28)
After the version header the decoder reads 32-bit tokens: the low 12 bits are the field id (< 0xb5, 181 fields; an id at or above that, or a zero entry, uses a generic descriptor), bits 12 to 14 are a size / type class (1..4, mapped through a 4-entry table at 0x187602e60 and compared with the descriptor's own token), and the descriptor table `SLEventGetFieldDecodeDescriptor<Token<1>, VersionedDecoder<1>>::descriptors` (16 bytes per field: expected token, ..., decode function) says where the value goes in the 0xf8-byte `SLSEventRecord`. A malformed token logs "CGEvent internal inconsistency: malformed token". Versions 2 and 3 have their own tables (lambdas at 0x1871607ac and 0x187162274). An encoder for the mouse and key events wsd produces needs those tables (read the descriptor arrays and the per-field decode functions); nothing of this is implemented yet.

### Field encoding (version 1, decompiled generic decoder at 0x18715ee50 and the descriptor table at 0x1e871e440)
- The table has 181 entries of 16 bytes: `u32 expected token`, `u32 0`, `u64 decode function` (PAC-signed; the low 32 bits are the offset from 0x180000000). Only eleven entries are filled; every other field id uses the generic decoder (`genericDescriptor`, 0x1e871ef90).
  Specialised fields (token, decoder): 0x24027 -> 0x18715e290, 0x1002a -> 0x18715e4f0, 0x2c038 -> 0x18715e64c, 0x2c039 -> 0x18715e8b4, 0x4052 -> 0x18715eb1c, 0x4054 -> 0x18715eb28, 0x106d -> 0x18715eb44, 0x40ac -> 0x18715ebf8, 0x10ae -> 0x18715ec70, 0x10b3 -> 0x18715ed2c, 0xc0b4 -> 0x18715ede0 (not decompiled yet).
- Generic field: a 32-bit token `0x0001_xxxx` (high half 1), low 12 bits = the CGEvent field id, bit 15 clear = integer, with the size class in bits 12 to 14: 0 = 8 bytes, 1 = 1 byte, 2 = 2 bytes, 4 = 4 bytes, the value following the token big-endian (zero extended) and stored with `SLEventRecordSetIntegerValue(record, field, value)`; bit 15 set with class 4 = a big-endian IEEE float read as 4 bytes and stored as a double with `SLEventRecordSetDoubleValue`. Field 0xa9 (the event timestamp) goes through `convert_time` when the reader is not the server.
- Version 2 and 3 decoders exist (version header read by `SLS::TokenizedCoding::Decoder::CreateFromProvider`, not decompiled); the header layout and the eleven specialised decoders are what remains before an encoder can be written.

### The eleven specialised fields and the record layout (decompiled)
Offsets are into the 0xf8-byte `SLSEventRecord`; all values in the stream are big-endian.
| token | decoder | stream payload | stored at |
|---|---|---|---|
| 0x24027 | #3 | two u32 | u32 at +0x74 and u32 at +0x78 |
| 0x1002a | #4 | u64 | +0x58 |
| 0x2c038 | #1 | two floats | doubles at +0x10 and +0x18 (the location) |
| 0x2c039 | #2 | two floats | doubles at +0x20 and +0x28 |
| 0x4052 | #5 | n x 4 bytes, n = token >> 16, the UTF-16 unit is the last two bytes of each 4-byte cell | `SLSEventRecordSetUnicodeString` |
| 0x4054 | #6 | min(n, 15) x u32, n = token >> 16 | +0x8c (array) |
| 0x106d | #7 | n raw bytes, n = token >> 16 | via `decode_bytes` (not decompiled) |
| 0x40ac | #8 | u32 array | `SLSEventRecordSetAuditToken` |
| 0x10ae, 0x10b3 | #9, #10 | n raw bytes | via `decode_bytes` |
| 0xc0b4 | #11 | a transform (`decode_transform`) | `SLSEventRecordSetLocalToDesktopTransform` |

`SLEventRecordSetIntegerValue` (0x1871537b0) maps the integer fields: the record's event type is field 0x37 (u32 at +8; the CGEventType numbers: 1..7 mouse, 10 / 11 / 12 key down / up / flags changed, 22 scroll), field 0x65 is the flags word (+0x54), 0x32 u32 at +4, 0x35 / 0x36 u16 at +0 / +2, 0x3a u64 at +0x30, 0x3b u32 at +0x38, 0x33 / 0x34 u32 at +0x3c / +0x40, 0x29 u32 at +0x48, 0x2b / 0x2c u32 at +0x4c / +0x50, 0x2d u32 at +0x60, 0x57 u64 at +0x68, 0x55 u32 at +0x7c, 0xa9 (the timestamp) lives in an extension record. Fields below 0x20 depend on the event type: for the keyboard events (10 to 12) field 9 is the key code (u16 at +0x90) and field 8 the auto-repeat flag; for the mouse events field 0 is the event number, 1 the click state, 2 the pressure, 3 the button.
The stream starts with a native u32 version (1, 2 or 3, read by `Decoder::CreateFromProvider`, 0x1871557a4); how the tokens themselves are framed (byte order of the 32-bit token and the end of the stream) is in `Decoder::decode_with_manager`, not decompiled yet.

## Status (2026-10-17)
- The event record stream is the one `src/evrec.c` already builds (version word 2, tokens `0x00014000|id` for 32-bit integers, `0x00010000|id` for 64-bit ones, `0x0002c000|id` for float pairs): it is what the real server records, and the decompile above confirms the framing (a token is a big-endian u32, the payload length is the class size times `token >> 16`, the stream ends when fewer than 4 bytes remain).
- Delivery for listen-only taps (option bit 0) is implemented: every mouse and key event queued for a window is serialized with `ws_evrec_make_*`, filtered by the tap's type mask and pushed to the tapping connection's event channel as a notification of type `WSD_NOTE_TAP_DATA` (0x54415044) whose payload is PostEventTapData's body: u32 0, sequence, tap id, length, then the data stream (token 0, event length, record). Test: `test/test_props.c` (the event taps block).
- Active taps (option bit 0 clear) are served for key down / up events (`sls_tap_filter_key`, `sls_tap_post_result`, `sls_tap_poll` in `src/sls_tap.c`, the key filter hook `ws_server_set_key_filter`): the event is held in a queue, the head is offered to the first matching tap, whose client answers with PostFilteredEventTapData style 0 (tap id, the sequence it was given, the surviving events; no events = dropped); survivors continue through the taps placed after it and then reach the windows. A tap that does not answer within the tap timeout is disabled and the original event goes on. Not held yet: modifier-flag changes, mouse and scroll events. The changed event's flags are not taken over (the current modifier state is used). EventTapSendDataProcessedAck (32033) is decompiled and answers 0x3ef for an unknown tap id. A client that is a real Apple binary needs the Mach shim to turn the notification into the id 1 message of the CGYEventTap subsystem.
