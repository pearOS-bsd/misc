#!/usr/bin/env python3
"""gen_objc_stubs.py DUMP.txt NAME OUTDIR [--skip FILE]: turns an inventory written by tools/objc_dump.m (a framework of the real Mac, read at run time) into
  OUTDIR/NAME_Generated.h   every class (with ivars, properties) and protocol, with the exact selectors and types
  OUTDIR/NAME_Generated.m   the implementation: properties with a backing ivar are synthesized, every other method is a stub returning 0 / nil / NO (init methods return self)
A method listed in the skip file (one "+Class sel" or "-Class sel" per line, collected from the `/* impl: -[Class sel] */` markers of the hand-written files) is not generated.
The hand-written code then replaces the stubs one method at a time, the interface stays the one of the real framework."""
import re, sys, os
dump, name, outdir = sys.argv[1], sys.argv[2], sys.argv[3]
skip = set(); skipclass = set()
coding = {}   # class -> [(key, kind)] the real encodeWithCoder: writes (docs/corewlan/coding.txt, from tools/cwprobe/coding_probe.m)
if "--coding" in sys.argv:
    for l in open(sys.argv[sys.argv.index("--coding") + 1]):
        if ": " not in l: continue
        cn, rest = l.rstrip("\n").split(": ", 1); coding[cn] = [tuple(x.split(":", 1)[0:2]) for x in rest.split(" ") if ":" in x]
IMPORTS = sys.argv[sys.argv.index("--imports") + 1].split(",") if "--imports" in sys.argv else []
if "--skip-class" in sys.argv: skipclass = set(sys.argv[sys.argv.index("--skip-class") + 1].split(","))
if "--skip" in sys.argv:
    for l in open(sys.argv[sys.argv.index("--skip") + 1]):
        l = l.strip()
        if l: skip.add(l)
os.makedirs(outdir, exist_ok=True)

def split_enc(enc):
    """encoding string of a method -> list of type encodings (return, self, _cmd, args...), offsets dropped"""
    out = []; i = 0; n = len(enc)
    def one(i):
        j = i
        while j < n and enc[j] in "rnNoORV": j += 1
        c = enc[j]
        if c in "{(":
            close = "}" if c == "{" else ")"; depth = 0
            while True:
                if enc[j] == c: depth += 1
                elif enc[j] == close:
                    depth -= 1
                    if depth == 0: j += 1; break
                j += 1
        elif c == "[":
            while enc[j] != "]": j += 1
            j += 1
        elif c == "^":
            _, k = one(j + 1); return enc[i:k], k
        elif c == "@":
            j += 1
            if j < n and enc[j] == "?": j += 1
            elif j < n and enc[j] == '"':
                j = enc.index('"', j + 1) + 1
        else:
            j += 1
        return enc[i:j], j
    while i < n:
        t, j = one(i)
        if isinstance(t, str) is False: pass
        out.append(t if isinstance(t, str) else t); i = j
        while i < n and enc[i].isdigit(): i += 1
    return out

def one_type(t):
    """encoding of one type -> (C type used in declarations)"""
    t = t.lstrip("rnNoORV")
    base = {"c": "char", "C": "unsigned char", "s": "short", "S": "unsigned short", "i": "int", "I": "unsigned int", "l": "long", "L": "unsigned long",
            "q": "long long", "Q": "unsigned long long", "f": "float", "d": "double", "B": "BOOL", "v": "void", "*": "char *", "#": "Class", ":": "SEL", "@": "id", "@?": "id"}
    if t in base: return base[t]
    if t.startswith("@"):
        m = re.match(r'@"([A-Za-z_0-9]+)', t)
        return "id" if not m else "id"
    if t.startswith("^"):
        inner = t[1:]
        if inner.startswith("@"): return "id *"
        if inner.startswith("{") or inner.startswith("v") or inner.startswith("("): return "void *"
        return one_type(inner) + " *"
    if t.startswith("{") or t.startswith("(") or t.startswith("["): return "void *"
    return "id"

def sig(sel, enc):
    ts = split_enc(enc)
    ret = one_type(ts[0]); args = [one_type(a) for a in ts[3:]]
    parts = sel.split(":")
    if len(parts) == 1: return ret, parts[0], ""
    if len(args) != len(parts) - 1: args = (args + ["id"] * len(parts))[:len(parts) - 1]
    return ret, sel, " ".join("%s:(%s)a%d" % (p, a, i) for i, (p, a) in enumerate(zip(parts[:-1], args)))

classes = []; protocols = []
cur = None
for line in open(dump, errors="replace"):
    line = line.rstrip("\n")
    if line.startswith("@class "):
        m = re.match(r"@class (\S+) : (\S+?)(?: <(.*)>)? instanceSize=(\d+)", line)
        if "." in m.group(1) or "$" in m.group(1): cur = None; continue
        cur = {"name": m.group(1), "super": m.group(2), "protos": [p.strip() for p in (m.group(3) or "").split(",") if p.strip()], "ivars": [], "props": [], "methods": []}
        classes.append(cur)
    elif line.startswith("@protocol "):
        cur = {"name": line.split()[1], "methods": []}; protocols.append(cur)
    elif cur is None: continue
    elif "methods" in cur and line.startswith("  ivar "):
        parts = line.split(None, 3); _, off, nm = parts[:3]; enc = parts[3] if len(parts) > 3 else "?"; cur["ivars"].append((nm, enc.strip())) if nm not in [i for i, _ in cur["ivars"]] else None
    elif line.startswith("  property "):
        m = re.match(r"  property (\S+) \((.*)\)$", line)
        if m.group(1) not in [x[0] for x in cur["props"]]: cur["props"].append((m.group(1), m.group(2)))
    elif line.startswith("  optional ") or line.startswith("  required "):
        kind, rest = line.split(None, 2)[0:2] + [None] if False else (line.split(None, 1)[0], line.split(None, 1)[1]); sign = rest[0]; sel, enc = (rest[1:].split(None, 1) + [""])[:2]
        if not sel.startswith("."): cur["methods"].append((kind, sign, sel, enc.strip()))
    elif line.startswith("  -") or line.startswith("  +"):
        body = line.strip(); sign = body[0]; rest = body[1:]; rest = re.sub(r"\s+imp=.*$", "", rest)
        sel, enc = (rest.split(None, 1) + [""])[:2]
        if not sel.startswith(".") and (sign, sel) not in cur.setdefault("_seen", set()): cur["_seen"].add((sign, sel)); cur["methods"].append((sign, sel, enc.strip()))

known = {c["name"] for c in classes}
def ivar_type(enc):
    m = re.match(r'@"([A-Za-z_0-9]+)(?:<.*>)?"$', enc)
    if m: return "%s *" % m.group(1) if m.group(1) in known or m.group(1).startswith("NS") else "id"
    return one_type(enc) if enc != "@" else "id"
def prop_decl(nm, attrs):
    parts = attrs.split(","); t = parts[0][1:]; flags = set(parts[1:]); ivar = None
    mods = ["nonatomic" if "N" in flags else "atomic"]
    if "R" in flags: mods.append("readonly")
    isobj = t.startswith("@")
    if "C" in flags and isobj: mods.append("copy")
    elif "&" in flags and isobj: mods.append("strong")
    elif "W" in flags and isobj: mods.append("weak")
    getter = setter = None
    for f in parts[1:]:
        if f.startswith("G"): getter = f[1:]
        if f.startswith("S"): setter = f[1:]
        if f.startswith("V"): ivar = f[1:]
    if getter: mods.append("getter=%s" % getter)
    if setter: mods.append("setter=%s" % setter)
    m = re.match(r'@"([A-Za-z_0-9]+)(<.*>)?"$', t)
    if m and m.group(1) in known | {"NSString", "NSArray", "NSData", "NSDictionary", "NSSet", "NSNumber", "NSDate", "NSURL", "NSUUID", "NSMutableArray", "NSMutableDictionary", "NSError", "NSOrderedSet", "NSSet"}: ctype = m.group(1) + " *"
    elif m and m.group(2) is None and m.group(1).startswith("NS"): ctype = m.group(1) + " *"
    else: ctype = one_type(t) if not t.startswith("@") else "id"
    return "@property (%s) %s %s;" % (", ".join(mods), ctype, nm), ivar, (getter or nm), (setter or ("set" + nm[0].upper() + nm[1:] + ":"))

# header
order = []; seen = set(); byname = {c["name"]: c for c in classes}
# an instance variable of the same name as one of a superclass (legal in the runtime, an error for the compiler): the subclass's one is renamed
def ancestors_ivars(c):
    names = set(); s = byname.get(c["super"])
    while s: names |= set(i for i, _ in s["ivars"]); s = byname.get(s["super"])
    return names
for c in classes:
    anc = ancestors_ivars(c); c["ivars"] = [((i + "__" + c["name"]) if i in anc else i, e) for i, e in c["ivars"]]
def visit(c):
    if c["name"] in seen: return
    seen.add(c["name"])
    s = byname.get(c["super"])
    if s: visit(s)
    order.append(c)
for c in classes: visit(c)
H = ['/* generated by tools/gen_objc_stubs.py from the inventory of the real %s: every class, ivar, property, protocol and selector with its type */' % name, '#import <Foundation/Foundation.h>'] + ['#import <%s>' % i for i in IMPORTS] + ['']
SYSTEM = set(l.strip() for l in open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "docs", "desktop", "system-classes.txt"))) if os.path.exists(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "docs", "desktop", "system-classes.txt")) else set()
SYSTEM |= skipclass
if "--known-from" in sys.argv:
    for f_ in sys.argv[sys.argv.index("--known-from") + 1].split(","): SYSTEM |= set(l.split()[1] for l in open(f_) if l.startswith("@class"))
dumped = set(c["name"] for c in classes)
missing_supers = sorted(set(c["super"] for c in classes if c["super"] and c["super"] not in dumped and c["super"] not in SYSTEM and not c["super"].startswith("NS") and c["super"] != "-") | set(c["super"] for c in classes if c["super"] and c["super"] not in dumped and c["super"].startswith("NS") and c["super"] not in SYSTEM))
refd = set()
for c in classes:
    for nm_, enc_ in c["ivars"]: refd.update(re.findall(r'@"([A-Za-z_][A-Za-z_0-9]*)', enc_))
    for nm_, at_ in c["props"]: refd.update(re.findall(r'@"([A-Za-z_][A-Za-z_0-9]*)', at_))
H += ["@class %s;" % n for n in sorted(refd - dumped)] + ["@class %s;" % c["name"] for c in classes] + [""]
H += ["@interface %s : NSObject @end   /* stand-in: the class of the real system is not part of this stack */" % n for n in missing_supers] + [""]
H += ["@protocol %s;" % p["name"] for p in protocols] + [""]
for p in protocols:
    H.append("@protocol %s" % p["name"]); cur_kind = None
    for kind, sign, sel, enc in p["methods"]:
        if kind != cur_kind: H.append("@%s" % kind); cur_kind = kind
        ret, s, args = sig(sel, enc) if enc else ("void", sel, "")
        H.append("%s (%s)%s%s;" % (sign, ret, s if not args else "", args))
    H.append("@end"); H.append("")
for c in order:
    pnames = {p["name"] for p in protocols}
    protos = [p for p in c["protos"] if p not in ("NSObject",) and (p in pnames or p in ("NSCopying", "NSMutableCopying", "NSCoding", "NSSecureCoding", "NSFastEnumeration", "NSXPCListenerDelegate", "NSURLSessionDelegate"))]
    H.append("@interface %s : %s%s" % (c["name"], c["super"], (" <%s>" % ", ".join(protos)) if protos else ""))
    if c["ivars"]:
        H.append("{")
        for nm, enc in c["ivars"]: H.append("\t%s %s;" % (ivar_type(enc), nm))
        H.append("}")
    accessors = set()
    for nm, attrs in c["props"]:
        d, iv, g, s = prop_decl(nm, attrs); H.append(d); accessors.add(g)
        if "R" not in attrs.split(",")[1:]: accessors.add(s)
    for sign, sel, enc in c["methods"]:
        if sign == "-" and sel in accessors: continue
        if sel in (".cxx_destruct", "dealloc"): continue
        ret, s, args = sig(sel, enc); H.append("%s (%s)%s%s;" % (sign, ret, s if not args else "", args))
    H.append("@end"); H.append("")
open(os.path.join(outdir, name + "_Generated.h"), "w").write("\n".join(H))

# implementation
M = ['/* generated by tools/gen_objc_stubs.py, see the header; the stubs are replaced by hand-written code method by method (a skip file lists those) */', '#import <%s/%s_Generated.h>' % (name, name), '']
nstub = nreal = 0
for c in order:
    M.append("@implementation %s" % c["name"]); accessors = set(); done_props = set()
    for nm, attrs in c["props"]:
        d, iv, g, s = prop_decl(nm, attrs)
        parts = attrs.split(",")
        if nm in done_props: continue
        done_props.add(nm)
        if iv and any(i == iv for i, _ in [(x[0], 0) for x in c["ivars"]]): M.append("@synthesize %s = %s;" % (nm, iv)); nreal += 1
        else: M.append("@dynamic %s;" % nm)
        accessors.add(g)
        if "R" not in parts[1:]: accessors.add(s)
    if c["name"] in skipclass: M.append("/* the methods of %s are hand-written (sdk/src/CoreWLAN/%s_impl.m) */" % (c["name"], c["name"])); M.append("@end"); M.append(""); continue
    cprotos = c["protos"]; nvals = any(True for nm, attrs in c["props"] if any(i == prop_decl(nm, attrs)[1] for i, _ in c["ivars"]))
    auto = set()
    if (nvals or c["name"] in coding) and ("NSCoding" in cprotos or "NSSecureCoding" in cprotos): auto |= {"encodeWithCoder:", "initWithCoder:"}
    if "NSSecureCoding" in cprotos: auto |= {"supportsSecureCoding"}
    if nvals and ("NSCopying" in cprotos or "NSMutableCopying" in cprotos): auto |= {"copyWithZone:"}
    if any(True for nm, attrs in c["props"]): auto |= {"dealloc"}
    for sign, sel, enc in c["methods"]:
        if sel in (".cxx_destruct", "dealloc", "conformsToProtocol:"): continue
        if sel in auto and "%s%s %s" % (sign, c["name"], sel) not in skip: continue
        if "%s%s %s" % (sign, c["name"], sel) in skip: continue
        ret, s, args = sig(sel, enc)
        if sign == "-" and sel in accessors:
            if any(sel == (prop_decl(nm, a)[2]) or sel == prop_decl(nm, a)[3] for nm, a in c["props"]):
                nm_ = [nm for nm, a in c["props"] if sel in (prop_decl(nm, a)[2], prop_decl(nm, a)[3])][0]
                a_ = dict(c["props"])[nm_]; iv = prop_decl(nm_, a_)[1]
                if iv and any(i == iv for i, _ in c["ivars"]): continue
        if ret == "id": body = "return self;" if sel.startswith("init") else "return nil;"
        elif ret == "void": body = ""
        elif ret in ("float", "double"): body = "return 0;"
        else: body = "return 0;"
        M.append("%s (%s)%s%s { %s }" % (sign, ret, s if not args else "", args, body)); nstub += 1
    # value-class behaviour: dealloc of owned properties, NSCoding / NSSecureCoding, NSCopying
    owned = []; vals = []
    for nm, attrs in c["props"]:
        d, iv, g, st = prop_decl(nm, attrs); parts = attrs.split(",")
        if not (iv and any(i == iv for i, _ in c["ivars"])): continue
        t = parts[0][1:]; flags = set(parts[1:])
        if t.startswith("@") and ("C" in flags or "&" in flags): owned.append(iv)
        vals.append((nm, iv, t))
    has = lambda pr: pr in c["protos"]
    sup_has = lambda pr: byname.get(c["super"]) is not None and pr in byname[c["super"]]["protos"]
    if owned and "%s%s %s" % ("-", c["name"], "dealloc") not in skip:
        M.append("- (void)dealloc { " + " ".join("[%s release]; %s = nil;" % (v, v) for v in owned) + " [super dealloc]; }")
    def enc_stmt(nm, iv, t):
        k = '@"%s"' % nm
        if t.startswith("@"): return "[c encodeObject:%s forKey:%s];" % (iv, k)
        if t in ("B",): return "[c encodeBool:%s forKey:%s];" % (iv, k)
        if t in ("f", "d"): return "[c encodeDouble:%s forKey:%s];" % (iv, k)
        if t in ("c", "C", "s", "S", "i", "I", "l", "L", "q", "Q"): return "[c encodeInt64:(long long)%s forKey:%s];" % (iv, k)
        return ""
    def dec_stmt(nm, iv, t):
        k = '@"%s"' % nm
        if t.startswith("@"): return "%s = [[c decodeObjectForKey:%s] retain];" % (iv, k)
        if t == "B": return "%s = [c decodeBoolForKey:%s];" % (iv, k)
        if t in ("f", "d"): return "%s = [c decodeDoubleForKey:%s];" % (iv, k)
        if t in ("c", "C", "s", "S", "i", "I", "l", "L", "q", "Q"): return "%s = (%s)[c decodeInt64ForKey:%s];" % (iv, one_type(t), k)
        return ""
    if (has("NSCoding") or has("NSSecureCoding")) and c["name"] in coding:
        # the keys and kinds the real class writes: "_ivar" keys, the superclass's first
        ents = [(k, kd.split("=")[0]) for k, kd in coding[c["name"]]]
        sup = [(k, kd.split("=")[0]) for k, kd in coding.get(c["super"], [])] if c["super"] in coding else []
        callsuper = bool(sup) and ents[:len(sup)] == sup and (sup_has("NSCoding") or sup_has("NSSecureCoding"))
        own = ents[len(sup):] if callsuper else ents
        ivt = dict(c["ivars"]); E = []; D = []
        for k, kind in own:
            iv_ = k if k in ivt else "_" + k if "_" + k in ivt else next((i for i in ivt if i.lstrip("_").lower() == k.lstrip("_").lower()), None)
            if iv_ is None: continue
            t = ivt[iv_]; q = '@"%s"' % k; k_ = k; k = iv_
            isobj = t.startswith("@")
            if kind == "object":
                if t.startswith("^"): E.append("[c encodeObject:(id)%s forKey:%s];" % (k, q)); D.append("%s = (void *)[[c decodeObjectForKey:%s] retain];" % (k, q))
                elif t.startswith("{"): E.append("[c encodeObject:({ unsigned long long r_ = 0; memcpy(&r_, &%s, sizeof %s < 8 ? sizeof %s : 8); [NSNumber numberWithUnsignedLongLong:r_]; }) forKey:%s];" % (k, k, k, q)); D.append("{ unsigned long long r_ = [[c decodeObjectOfClass:[NSNumber class] forKey:%s] unsignedLongLongValue]; memcpy(&%s, &r_, sizeof %s < 8 ? sizeof %s : 8); }" % (q, k, k, k))
                elif isobj: E.append("[c encodeObject:%s forKey:%s];" % (k, q)); D.append("%s = [[c decodeObjectForKey:%s] retain];" % (k, q))
                elif t == "B": E.append("[c encodeObject:[NSNumber numberWithBool:%s] forKey:%s];" % (k, q)); D.append("%s = [[c decodeObjectOfClass:[NSNumber class] forKey:%s] boolValue];" % (k, q))
                elif t in ("f", "d"): E.append("[c encodeObject:[NSNumber numberWithDouble:%s] forKey:%s];" % (k, q)); D.append("%s = [[c decodeObjectOfClass:[NSNumber class] forKey:%s] doubleValue];" % (k, q))
                elif t in ("C", "S", "I", "L", "Q"): E.append("[c encodeObject:[NSNumber numberWithUnsignedLongLong:%s] forKey:%s];" % (k, q)); D.append("%s = (%s)[[c decodeObjectOfClass:[NSNumber class] forKey:%s] unsignedLongLongValue];" % (k, one_type(t), q))
                else: E.append("[c encodeObject:[NSNumber numberWithLongLong:%s] forKey:%s];" % (k, q)); D.append("%s = (%s)[[c decodeObjectOfClass:[NSNumber class] forKey:%s] longLongValue];" % (k, one_type(t), q))
            else:
                fn = {"bool": "Bool", "int": "Int", "int32": "Int32", "int64": "Int64", "integer": "Integer", "float": "Float", "double": "Double"}.get(kind)
                if not fn: continue
                E.append("[c encode%s:%s forKey:%s];" % (fn, k, q)); D.append("%s = (%s)[c decode%sForKey:%s];" % (k, one_type(t), fn, q))
        if "-%s encodeWithCoder:" % c["name"] not in skip:
            M.append("- (void)encodeWithCoder:(NSCoder *)c { " + ("[super encodeWithCoder:c]; " if callsuper else "") + " ".join(E) + " }")
        if "-%s initWithCoder:" % c["name"] not in skip:
            M.append("- (id)initWithCoder:(NSCoder *)c { self = " + ("[super initWithCoder:c]" if callsuper else "[super init]") + "; if (!self) return nil; " + " ".join(D) + " return self; }")
    elif (has("NSCoding") or has("NSSecureCoding")) and vals:
        if "-%s encodeWithCoder:" % c["name"] not in skip:
            M.append("- (void)encodeWithCoder:(NSCoder *)c { " + ("[super encodeWithCoder:c]; " if sup_has("NSCoding") or sup_has("NSSecureCoding") else "") + " ".join(enc_stmt(*v) for v in vals) + " }")
        if "-%s initWithCoder:" % c["name"] not in skip:
            M.append("- (id)initWithCoder:(NSCoder *)c { self = " + ("[super initWithCoder:c]" if sup_has("NSCoding") or sup_has("NSSecureCoding") else "[super init]") + "; if (!self) return nil; " + " ".join(dec_stmt(*v) for v in vals) + " return self; }")
    if has("NSSecureCoding") and "+%s supportsSecureCoding" % c["name"] not in skip: M.append("+ (BOOL)supportsSecureCoding { return YES; }")
    if (has("NSCopying") or has("NSMutableCopying")) and "-%s copyWithZone:" % c["name"] not in skip and vals:
        cp = []
        for nm, iv, t in vals: cp.append("o->%s = %s;" % (iv, ("[%s retain]" % iv) if t.startswith("@") and iv in owned else iv) if not t.startswith("{") else "")
        M.append("- (id)copyWithZone:(NSZone *)z { %s *o = %s; " % (c["name"], "[super copyWithZone:z]" if sup_has("NSCopying") else "[[self class] allocWithZone:z] init]".replace("[[self class] allocWithZone:z] init]", "[[[self class] allocWithZone:z] init]")) + " ".join(cp) + " return o; }")
    M.append("@end"); M.append("")
open(os.path.join(outdir, name + "_Generated.m"), "w").write("\n".join(M))
print("%s: %d classes, %d protocols, %d stub methods, %d synthesized properties" % (name, len(classes), len(protocols), nstub, nreal))
