#!/usr/bin/env python3
"""mkusb.py: helpers for the USB image.
  mkusb.py --extract-esp ISO OUT.img      copy the El Torito EFI boot image of the ISO to a file
(The USB image itself is assembled by mkusb.sh.)"""
import sys, struct, zlib, uuid, os

def efi_image(f):
    f.seek(17 * 2048); br = f.read(2048)
    assert br[1:6] == b'CD001' and br[7:30].startswith(b'EL TORITO'), 'no boot record'
    cat = struct.unpack('<I', br[0x47:0x4b])[0]
    f.seek(cat * 2048); c = f.read(2048)
    rba = next((struct.unpack('<I', c[i+8:i+12])[0] for i in range(0, 2048, 32) if c[i] == 0x88), None)
    assert rba, 'no bootable entry'
    f.seek(rba * 2048); first = f.read(512)
    assert first[0x36:0x3e].startswith(b'FAT') or first[0x52:0x5a].startswith(b'FAT'), 'boot image is not FAT'
    bps = struct.unpack('<H', first[0x0b:0x0d])[0]
    secs = struct.unpack('<H', first[0x13:0x15])[0] or struct.unpack('<I', first[0x20:0x24])[0]
    return rba, secs * bps

if len(sys.argv) == 4 and sys.argv[1] == '--extract-esp':
    with open(sys.argv[2], 'rb') as f:
        rba, size = efi_image(f); f.seek(rba * 2048)
        open(sys.argv[3], 'wb').write(f.read(size))
    sys.exit(0)
