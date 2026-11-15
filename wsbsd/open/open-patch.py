#!/usr/bin/env python3
"""open-patch.py IN OUT: rewrites the AppKit load command of a thin x86_64 Mach-O so that dyld loads our AppKit (/open/AppKit) instead of the one of the cache.
The new path has to fit in the old load command (it is shorter than /System/Library/Frameworks/AppKit.framework/Versions/A/AppKit)."""
import struct, sys
d = bytearray(open(sys.argv[1], 'rb').read())
magic, = struct.unpack_from('<I', d, 0)
assert magic == 0xfeedfacf, 'thin 64-bit Mach-O little endian expected'
DROP = (b'libswiftCoreImage.dylib', b'libswiftMetal.dylib', b'libswiftQuartzCore.dylib', b'libswiftSpatial.dylib', b'/RecapPerformanceTesting')
ncmds, = struct.unpack_from('<I', d, 16)
off, n = 32, 0
for _ in range(ncmds):
    cmd, size = struct.unpack_from('<II', d, off)
    if cmd in (0xc, 0x80000018, 0x1f, 0x23):	# LOAD_DYLIB, LOAD_WEAK_DYLIB, REEXPORT, LAZY
        no, = struct.unpack_from('<I', d, off + 8)
        name = bytes(d[off + no: off + size]).split(b'\0')[0]
        if any(name.endswith(x) for x in DROP):
            pass		# the load command stays: it points to our stand-in (stub-NAME) that holds the symbols the program binds from that library
            nn = b'/open/stub-' + name.split(b'/')[-1].replace(b'.dylib', b'')
            no2, = struct.unpack_from('<I', d, off + 8); d[off + no2: off + size] = nn[:size - no2 - 1] + b'\0' * (size - no2 - len(nn[:size - no2 - 1])); print('dropped', name.decode())
        if name.endswith((b'/AppKit.framework/Versions/A/AppKit', b'/AppKit.framework/Versions/C/AppKit', b'/AppKit.framework/AppKit', b'/Cocoa.framework/Versions/A/Cocoa')):
            NEW = b'/open/Cocoa' if name.endswith(b'/Cocoa') else b'/open/AppKit'
            assert len(NEW) + 1 <= size - no
            d[off + no: off + size] = NEW + b'\0' * (size - no - len(NEW))
            n += 1; print('patched', name.decode())
    off += size
assert n, 'no AppKit load command'
open(sys.argv[2], 'wb').write(d)
