#!/usr/bin/env python3
"""nibdump.py FILE.nib: dumps a compiled NIBArchive (the format of ibtool's output): objects with their class, keys and values.  Run next to the nib on the Mac VM (Apple files stay on the VMs)."""
import struct, sys
d = open(sys.argv[1], 'rb').read()
assert d[:10] == b'NIBArchive'
v1, v2, nobj, oobj, nkey, okey, nval, oval, ncls, ocls = struct.unpack_from('<10I', d, 10)
def vint(p):
    r = s = 0
    while True:
        b = d[p]; p += 1
        r |= (b & 0x7f) << s; s += 7
        if b & 0x80: return r, p
objs = []; p = oobj
for _ in range(nobj):
    c, p = vint(p); vi, p = vint(p); vc, p = vint(p); objs.append((c, vi, vc))
keys = []; p = okey
for _ in range(nkey):
    n, p = vint(p); keys.append(d[p:p + n].decode('utf8', 'replace')); p += n
vals = []; p = oval
for _ in range(nval):
    k, p = vint(p); t = d[p]; p += 1
    if t == 0: x = struct.unpack_from('<b', d, p)[0]; p += 1
    elif t == 1: x = struct.unpack_from('<h', d, p)[0]; p += 2
    elif t == 2: x = struct.unpack_from('<i', d, p)[0]; p += 4
    elif t == 3: x = struct.unpack_from('<q', d, p)[0]; p += 8
    elif t == 4: x = True
    elif t == 5: x = False
    elif t == 6: x = struct.unpack_from('<f', d, p)[0]; p += 4
    elif t == 7: x = struct.unpack_from('<d', d, p)[0]; p += 8
    elif t == 8: n, p = vint(p); x = d[p:p + n]; p += n
    elif t == 9: x = None
    elif t == 10: x = ('obj', struct.unpack_from('<I', d, p)[0]); p += 4
    else: raise Exception('value type %d at %d' % (t, p))
    vals.append((k, t, x))
cls = []; p = ocls
for _ in range(ncls):
    n, p = vint(p); e, p = vint(p); ex = [struct.unpack_from('<I', d, p + 4 * i)[0] for i in range(e)]; p += 4 * e
    cls.append(d[p:p + n].rstrip(b'\0').decode()); p += n
print('objects %d keys %d values %d classes %d (v%d.%d)' % (nobj, nkey, nval, ncls, v1, v2))
mx = int(sys.argv[2]) if len(sys.argv) > 2 else 40
for i, (c, vi, vc) in enumerate(objs[:mx]):
    items = []
    for k, t, x in vals[vi:vi + vc]:
        if isinstance(x, bytes): x = x[:40]
        items.append('%s=%r' % (keys[k], x))
    print(i, cls[c], ' '.join(items)[:300])
