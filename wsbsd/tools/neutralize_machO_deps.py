#!/usr/bin/env python3
"""neutralize_machO_deps.py IN OUT: copy of a Mach-O (thin arm64e image extracted from the dyld shared cache) whose load-dylib commands are renamed to an unknown command, so that Ghidra / REA do not try to
resolve every dependency from the cache (it runs out of memory otherwise)."""
import struct, sys
data = bytearray(open(sys.argv[1], "rb").read())
magic, cputype, cpusub, ftype, ncmds, sizeofcmds, flags, _ = struct.unpack_from("<IiiIIIII", data, 0)
assert magic == 0xfeedfacf, hex(magic)
off = 32; n = 0
for _ in range(ncmds):
    cmd, size = struct.unpack_from("<II", data, off)
    if cmd in (0xC, 0x80000018, 0x8000001F, 0x80000023):
        struct.pack_into("<I", data, off, 0x7ffffff0); n += 1
    off += size
open(sys.argv[2], "wb").write(data); print("neutralized", n, "dylib commands")
