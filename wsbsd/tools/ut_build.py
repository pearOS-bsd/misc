#!/usr/bin/env python3
"""ut_build.py DB.json PROBE1.txt DYN_X.json OUT.json: the final uniform type table: the declarations of tools/ut_dump.py, the tags for which the system prefers another declaration than the first ("prefer", found
by comparing tools/utprobe/ut_probe.m output with the table) and the dynamic-identifier codes of the core types that are written in the short form ("dyn_codes")."""
import json, re, sys, collections
db = json.load(open(sys.argv[1])); oracle = {}
for l in open(sys.argv[2]):
    m = re.match(r"(ext|mime|ostype) (.*?) -> (\S+)$", l.rstrip("\n"))
    if m and " conf " not in l: oracle[(m.group(1), m.group(2))] = m.group(3)
cand = collections.OrderedDict()
for t in db:
    for k in ("ext", "mime", "ostype"):
        for v in t["tags"][k]: cand.setdefault((k, v), []).append(t["uti"])
prefer = {"%s:%s" % k: oracle[k] for k, c in cand.items() if k in oracle and not oracle[k].startswith("dyn.") and c[0] != oracle[k]}
json.dump({"types": db, "prefer": prefer, "dyn_codes": json.load(open(sys.argv[3]))}, open(sys.argv[4], "w"), ensure_ascii=False, separators=(",", ":"))
print(len(db), "types,", len(prefer), "preferences")
