#!/usr/bin/env python3
"""open-patch.py: makes Mac programs run on the AppKit of the "open" layer.
    open-patch.py IN OUT              a Mach-O file (thin or universal: the x86_64 slice is taken): the load commands of AppKit/Cocoa point to /open/AppKit and /open/Cocoa, the
                                      libraries that would pull the real AppKit into the process (the Swift overlays of CoreImage, Metal ... ) to the stand-ins /open/stub-NAME
    open-patch.py --bundle APP DEST   a whole .app: every Mach-O file of Contents/ is patched into DEST/<same path>, everything else is a link to the original (the bundle path stays the same shape)
The new paths have to fit in the old load commands (they are shorter than /System/Library/Frameworks/AppKit.framework/Versions/C/AppKit)."""
import os, struct, sys
DROP = (b'libswiftCoreImage.dylib', b'libswiftMetal.dylib', b'libswiftQuartzCore.dylib', b'libswiftSpatial.dylib', b'/RecapPerformanceTesting')
APPKIT = (b'/AppKit.framework/Versions/A/AppKit', b'/AppKit.framework/Versions/C/AppKit', b'/AppKit.framework/AppKit', b'/Cocoa.framework/Versions/A/Cocoa')

def thin(d):
    """the x86_64 slice of a universal binary (fat magic is big endian), or the file itself when it is thin x86_64; None when it is no Mach-O we can run"""
    m, = struct.unpack_from('>I', d, 0)
    if m in (0xcafebabe, 0xcafebabf):
        n, = struct.unpack_from('>I', d, 4)
        for i in range(n):
            if m == 0xcafebabe:
                cpu, sub, off, size, al = struct.unpack_from('>IIIII', d, 8 + 20 * i)
            else:
                cpu, sub, off, size, al = struct.unpack_from('>IIQQI', d, 8 + 32 * i)
            if cpu == 0x01000007:
                return bytearray(d[off:off + size])
        return None
    if struct.unpack_from('<I', d, 0)[0] == 0xfeedfacf and struct.unpack_from('<I', d, 4)[0] == 0x01000007:
        return bytearray(d)
    return None

def patch(d, log=False):
    """rewrites the load commands in place; returns how many were changed"""
    ncmds, = struct.unpack_from('<I', d, 16)
    off, n = 32, 0
    for _ in range(ncmds):
        cmd, size = struct.unpack_from('<II', d, off)
        if cmd in (0xc, 0x80000018, 0x1f, 0x23):
            no, = struct.unpack_from('<I', d, off + 8)
            name = bytes(d[off + no: off + size]).split(b'\0')[0]
            new = None
            if any(name.endswith(x) for x in DROP): new = b'/open/stub-' + name.split(b'/')[-1].replace(b'.dylib', b'')
            elif name.endswith(APPKIT): new = b'/open/Cocoa' if name.endswith(b'/Cocoa') else b'/open/AppKit'
            if new:
                assert len(new) + 1 <= size - no, 'path too long for %r' % name
                d[off + no: off + size] = new + b'\0' * (size - no - len(new)); n += 1
                if log: print('  %s -> %s' % (name.decode(), new.decode()))
        off += size
    return n

def patch_file(src, dst, log=False):
    d = thin(open(src, 'rb').read())
    if d is None: return False
    n = patch(d, log)
    if n == 0: return False
    tmp = dst + '.tmp'; open(tmp, 'wb').write(d); os.chmod(tmp, 0o755); os.replace(tmp, dst); return True

def bundle(src, dest, log=False):
    src = os.path.abspath(src); patched = 0
    for root, dirs, files in os.walk(src):
        rel = os.path.relpath(root, src); out = os.path.join(dest, rel) if rel != '.' else dest
        os.makedirs(out, exist_ok=True)
        for f in files:
            s = os.path.join(root, f); o = os.path.join(out, f)
            if os.path.islink(s):
                if not os.path.lexists(o): os.symlink(os.readlink(s), o)
                continue
            if os.path.lexists(o): os.remove(o)
            ok = False
            if os.path.getsize(s) > 4096:
                with open(s, 'rb') as fh: head = fh.read(4)
                if head in (b'\xca\xfe\xba\xbe', b'\xcf\xfa\xed\xfe', b'\xca\xfe\xba\xbf'): ok = patch_file(s, o, log)
            if not ok: os.symlink(s, o)
            else: patched += 1
    return patched

if __name__ == '__main__':
    if sys.argv[1] == '--bundle': print('patched %d files' % bundle(sys.argv[2], sys.argv[3], True))
    else:
        if not patch_file(sys.argv[1], sys.argv[2], True): sys.exit('nothing to patch (no AppKit load command, or not x86_64)')
