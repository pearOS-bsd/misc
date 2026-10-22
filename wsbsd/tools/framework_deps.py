#!/usr/bin/env python3
"""framework_deps.py NAME ALL...: the frameworks (among ALL, in docs/desktop/frameworks) that define superclasses of classes of NAME: "imports" and "known" lists for tools/gen_objc_stubs.py (--imports, --known-from)."""
import sys, re, os
def classes(n):
    d = {}; cur = None
    for l in open("docs/desktop/frameworks/%s.objc.txt" % n, errors="replace"):
        m = re.match(r"@class (\S+) : (\S+)", l)
        if m: d[m.group(1)] = m.group(2)
    return d
name, others = sys.argv[1], sys.argv[2:]
mine = classes(name); owner = {}
for o in others:
    if o != name:
        for c in classes(o):
            owner.setdefault(c, o)
deps = []
for c, s in mine.items():
    if s not in mine and s in owner and owner[s] not in deps: deps.append(owner[s])
print(",".join("%s/%s_Generated.h" % (d, d) for d in deps) + " " + ",".join("docs/desktop/frameworks/%s.objc.txt" % d for d in deps))
