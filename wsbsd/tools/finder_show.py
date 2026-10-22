#!/usr/bin/env python3
"""finder_show.py CLASS [SELECTOR]: prints the decompiled methods of a Finder class from the local decompilation (~/finder-decomp/out, made by tools/finder_decompile.sh; never committed)."""
import sys, os, re
d = os.path.expanduser("~/finder-decomp/out"); cls = re.sub(r"[^A-Za-z0-9_]", "_", sys.argv[1]); p = os.path.join(d, cls + ".c")
if not os.path.exists(p): sys.exit("no decompilation of %s" % sys.argv[1])
t = open(p, errors="replace").read(); parts = re.split(r"(?m)^(?=/\* 0x[0-9a-f]+ [-+]\S+ \*/)", t)
for s in parts:
    if len(sys.argv) < 3 or re.match(r"/\* 0x[0-9a-f]+ [-+]%s \*/" % re.escape(sys.argv[2]), s): print(s)
