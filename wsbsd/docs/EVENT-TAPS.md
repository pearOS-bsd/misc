# Event tap delivery (client side, from the SkyLight decompile)

The registry (`src/sls_tap.c`) is real; the events are not handed to the tapping process yet. What the client library expects (`eventTapMessageHandler`, `processEventTapData`, `__XPostEventTapData`, `__XPostEventTapDataOOL`):

- The tap's port is the descriptor given to PlaceTap (32028 / 32029). The message the server sends to it uses the CGYEventTap subsystem: id 1 = PostEventTapData, id 2 = PostEventTapDataOOL (reply ids +100, the client answers with the return code at 0x20).
- PostEventTapData (id 1): simple message, size `pad4(n) + 0x30` with `n <= 0x4000`; `u32@0x20` event type (0 = a data stream follows, else a bare event of that type), `u32@0x24` sequence, `u32@0x28` tap proxy id (the id PlaceTap returned), `u32@0x2c` n, data from 0x30.
- PostEventTapDataOOL (id 2): complex, one OOL descriptor (address@0x1c), size 0x44; type@0x34, sequence@0x38, proxy id@0x3c, n@0x28 repeated @0x40.
- The data stream: records of `u32 token (0)`, `u32 length`, `length` bytes of a serialized CGEvent (what `SLEventCreateFromDataAndSource` reads); it ends when fewer than 8 bytes remain. The tap callback may replace, keep or drop each event; the client posts the survivors back with PostFilteredEventTapData (32035 family, `src/wsd.c` `do_post_tap_data`) and acknowledges with EventTapSendDataProcessedAck.
- Taps whose event mask lacks the event's type are not called; a callback returning a corrupt event disables the tap (`disableEventTap`).

Missing for delivery: the serialized CGEvent format. `_SLEventCreateFromDataAndSource` hands the bytes to `_SLEventRecordCreateWithBytesModern`, which decodes an `SLS::TokenizedCoding` stream (a version header, then versions 1 to 3 of `VersionedDecoder`, each filling the 0xf8-byte `SLSEventRecord`; a record with type >= 0x20 is rejected as "unknown event type"); the per-version field tables are templated C++ and still to be decompiled, and how a server-to-client Mach message is carried on wsd's socket for a port received in a descriptor.
