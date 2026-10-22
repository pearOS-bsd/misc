#!/usr/bin/env python3
"""nibdump.py NIB: prints the objects of a compiled nib (NIBArchive) as a tree of their keys and values: class names, titles, key equivalents, actions, connections (object references appear as #index)."""
import struct, sys
d = open(sys.argv[1], "rb").read(); assert d[:10] == b"NIBArchive"
(v1, v2, nobj, oobj, nkey, okey, nval, oval, ncls, ocls) = struct.unpack_from("<10I", d, 10)
def varint(p):
    n = 0; s = 0
    while True:
        b = d[p]; p += 1; n |= (b & 0x7F) << s; s += 7
        if b & 0x80: return n, p
keys = []; p = okey
for _ in range(nkey): l, p = varint(p); keys.append(d[p:p + l].decode("utf8", "replace")); p += l
classes = []; p = ocls
for _ in range(ncls): l, p = varint(p); ex, p = varint(p); p += 4 * ex; classes.append(d[p:p + l].rstrip(b"\0").decode("utf8", "replace")); p += l
objs = []; p = oobj
for _ in range(nobj): c, p = varint(p); vi, p = varint(p); vc, p = varint(p); objs.append((c, vi, vc))
vals = []; p = oval
for _ in range(nval):
    k, p = varint(p); t = d[p]; p += 1
    if t == 0: v = struct.unpack_from("<b", d, p)[0]; p += 1
    elif t == 1: v = struct.unpack_from("<h", d, p)[0]; p += 2
    elif t == 2: v = struct.unpack_from("<i", d, p)[0]; p += 4
    elif t == 3: v = struct.unpack_from("<q", d, p)[0]; p += 8
    elif t == 4: v = True
    elif t == 5: v = False
    elif t == 6: v = struct.unpack_from("<f", d, p)[0]; p += 4
    elif t == 7: v = struct.unpack_from("<d", d, p)[0]; p += 8
    elif t == 8: l, p = varint(p); raw = d[p:p + l]; p += l; v = raw.decode("utf8") if all(32 <= b < 127 or b in (9, 10) or b > 127 for b in raw) and raw else raw.hex()
    elif t == 9: v = None
    elif t == 10: v = "#%d" % struct.unpack_from("<I", d, p)[0]; p += 4
    else: v = "?type%d" % t
    vals.append((keys[k], v))
for i, (c, vi, vc) in enumerate(objs):
    print("#%d %s" % (i, classes[c]) + "".join("  %s=%r" % kv for kv in vals[vi:vi + vc]))
