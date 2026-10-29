#!/usr/bin/env python3
"""patch_vt_logo.py KERNEL [OUT]: replaces the FreeBSD logo that the kernel's vt(4) draws while the boot is muted (vtterm_splash) with the pear of pearOS.

The logo lives in the kernel's initialised data: vt_logo_image (a 1 bit per pixel bitmap, rows padded to whole bytes, most significant bit first, a set bit = foreground), and the unsigned ints
vt_logo_width, vt_logo_height, vt_logo_depth (1). The pear (src/splash_pear.inc, an alpha picture of 70 x 109) is cut to 1 bit and written over the image; the width and height are changed to
the pear's, so that vtterm_splash centres the pear on the screen, where the window server's boot screen puts it too. Nothing is touched unless every symbol is found, the depth is 1 and the pear
fits in the room of the old image; otherwise the kernel is left as it was (exit 2). The ELF file is read directly (no nm / readelf needed)."""
import struct, sys, re, os

def elf_symbols(f):
    h = f[:64]
    if h[:4] != b'\x7fELF' or h[4] != 2 or h[5] != 1: raise SystemExit('not a little-endian ELF64')
    shoff, = struct.unpack_from('<Q', h, 0x28); shentsize, shnum, shstrndx = struct.unpack_from('<HHH', h, 0x3A)
    phoff, = struct.unpack_from('<Q', h, 0x20); phentsize, phnum = struct.unpack_from('<HH', h, 0x36)
    secs = []
    for i in range(shnum):
        o = shoff + i * shentsize
        name, typ, flags, addr, off, size, link, info, align, entsize = struct.unpack_from('<IIQQQQIIQQ', f, o)
        secs.append((typ, addr, off, size, link, entsize))
    syms = {}
    for typ, addr, off, size, link, entsize in secs:
        if typ != 2: continue                      # SHT_SYMTAB
        stroff = secs[link][2]
        for k in range(size // 24):
            n, info, other, shndx, value, ssize = struct.unpack_from('<IBBHQQ', f, off + k * 24)
            e = f.index(b'\0', stroff + n); nm = f[stroff + n:e].decode('latin1')
            if nm in ('vt_logo_image', 'vt_logo_width', 'vt_logo_height', 'vt_logo_depth'): syms[nm] = (value, ssize)
    loads = []
    for i in range(phnum):
        o = phoff + i * phentsize
        typ, flags, off, vaddr, paddr, filesz, memsz, align = struct.unpack_from('<IIQQQQQQ', f, o)
        if typ == 1: loads.append((vaddr, off, filesz))
    return syms, loads

def file_offset(loads, addr):
    for vaddr, off, filesz in loads:
        if vaddr <= addr < vaddr + filesz: return off + addr - vaddr
    return None

def pear_bits(inc):
    t = open(inc).read()
    w, h = map(int, re.search(r'pear_w = (\d+), pear_h = (\d+)', t).groups())
    a = [int(x) for x in re.findall(r'\d+', t[t.index('pear_a[]'):].split('{', 1)[1].split('}', 1)[0])]
    if len(a) != w * h: raise SystemExit('pear alpha size')
    stride = (w + 7) // 8; out = bytearray(stride * h)
    for y in range(h):
        for x in range(w):
            if a[y * w + x] >= 110: out[y * stride + x // 8] |= 0x80 >> (x % 8)
    return w, h, bytes(out)

def main():
    kern = sys.argv[1]; dst = sys.argv[2] if len(sys.argv) > 2 else kern
    inc = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'src', 'splash_pear.inc')
    f = bytearray(open(kern, 'rb').read()); syms, loads = elf_symbols(bytes(f))
    if len(syms) != 4: print('patch_vt_logo: the logo symbols are not all there (%s): the kernel is left as it is' % sorted(syms)); return 2
    off = {k: file_offset(loads, v[0]) for k, v in syms.items()}
    if None in off.values(): print('patch_vt_logo: a symbol is outside the loaded segments'); return 2
    w0, h0, d0 = (struct.unpack_from('<I', f, off[k])[0] for k in ('vt_logo_width', 'vt_logo_height', 'vt_logo_depth'))
    room = syms['vt_logo_image'][1]; print('patch_vt_logo: old logo %d x %d, depth %d, %d bytes' % (w0, h0, d0, room))
    if d0 != 1 or (w0 + 7) // 8 * h0 > room or w0 * h0 == 0 or w0 > 4096 or h0 > 4096: print('patch_vt_logo: unexpected logo format: the kernel is left as it is'); return 2
    w, h, bits = pear_bits(inc)
    if len(bits) > room: print('patch_vt_logo: the pear does not fit (%d > %d bytes)' % (len(bits), room)); return 2
    o = off['vt_logo_image']; f[o:o + room] = bits + b'\0' * (room - len(bits))
    struct.pack_into('<I', f, off['vt_logo_width'], w); struct.pack_into('<I', f, off['vt_logo_height'], h)
    open(dst, 'wb').write(f); print('patch_vt_logo: the pear (%d x %d) is the boot logo now' % (w, h)); return 0

sys.exit(main())
