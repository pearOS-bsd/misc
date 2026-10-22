#!/usr/bin/env python3
"""nib2plist.py IN.nib OUT_DIR: converts a compiled nib (NIBArchive, the format of Xcode 4.x and later nibs) to the keyed archive property list that GNUstep's nib loader reads: OUT_DIR/keyedobjects.nib.
The objects keep their keys; strings, numbers and collections become the plain values of a keyed archive; object references become UIDs."""
import struct, sys, plistlib, os
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
    elif t == 8: l, p = varint(p); v = ("data", d[p:p + l]); p += l
    elif t == 9: v = ("nil",)
    elif t == 10: v = ("ref", struct.unpack_from("<I", d, p)[0]); p += 4
    else: raise SystemExit("unknown value type %d" % t)
    vals.append((keys[k], v))
out = ["$null"]; clsidx = {}
def cls_uid(name):
    if name not in clsidx:
        chain = [name]
        if name.startswith("NSMutable"): chain.append(name.replace("NSMutable", "NS"))
        chain.append("NSObject"); out.append({"$classname": name, "$classes": chain}); clsidx[name] = len(out) - 1
    return plistlib.UID(clsidx[name])
# the index of object i in the archive: 1 + i (strings become plain values below, so they keep a slot and are referenced inline)
def objstr(i): c, vi, vc = objs[i]; return dict(vals[vi:vi + vc]).get("NS.bytes") if classes[c] == "NSString" else None
slots = {}; prims = {}
def prim(v):
    key = (type(v).__name__, v)
    if key not in prims: out.append(v); prims[key] = len(out) - 1
    return plistlib.UID(prims[key])
def conv(v):
    if isinstance(v, tuple):
        if v[0] == "ref": return ref(v[1])
        if v[0] == "data": return v[1]
        return plistlib.UID(0)
    return v
def ref(i):
    c, vi, vc = objs[i]; name = classes[c]
    if name == "NSString":
        s = dict(vals[vi:vi + vc]).get("NS.bytes"); s = s if isinstance(s, str) else (s[1].decode("utf8", "replace") if isinstance(s, tuple) else "")
        return prim(s)
    if name == "NSNumber":
        kv = dict(vals[vi:vi + vc])
        for k in ("NS.intval", "NS.dblval", "NS.boolval"):
            if k in kv: return prim(kv[k])
        return prim(0)
    if i in slots: return plistlib.UID(slots[i])
    out.append(None); idx = len(out) - 1; slots[i] = idx
    kv = vals[vi:vi + vc]; o = {"$class": cls_uid(name)}
    if name in ("NSArray", "NSMutableArray", "NSSet", "NSMutableSet", "NSOrderedSet"): o["NS.objects"] = [conv(v) for k, v in kv if k == "UINibEncoderEmptyKey"]
    elif name in ("NSDictionary", "NSMutableDictionary"):
        seq = [conv(v) for k, v in kv if k == "UINibEncoderEmptyKey"]; o["NS.keys"] = seq[0::2]; o["NS.objects"] = seq[1::2]
    else:
        for k, v in kv:
            if k in o: continue
            o[k] = conv(v)
    out[idx] = o; return plistlib.UID(idx)
top = {"IB.objectdata": ref(1)} if False else None
root_vals = dict(vals[objs[0][1]:objs[0][1] + objs[0][2]])
top = {k: conv(v) for k, v in root_vals.items()}
os.makedirs(sys.argv[2], exist_ok=True)
plistlib.dump({"$archiver": "NSKeyedArchiver", "$version": 100000, "$top": top, "$objects": out}, open(os.path.join(sys.argv[2], "keyedobjects.nib"), "wb"), fmt=plistlib.FMT_BINARY)
print("%d objects" % len(out))
