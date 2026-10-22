#!/usr/bin/env python3
"""ut_dump.py LSDUMP.txt OUT.json: reads the output of `lsregister -dump` (the Launch Services database of the reference Mac) and writes the table of uniform type identifiers: for every UTI its
conformances, the tags by class (extension, mime, ostype, pboard), the flags, the English description, the declaring bundle and the order of declaration (the order decides the preferred tag)."""
import re, sys, json, collections
entries = []; cur = None; order = 0; pending_bundle = None; in_icons = False
for line in open(sys.argv[1], errors="replace"):
    line = line.rstrip("\n")
    if line.startswith("type id:"): cur = None; pending_bundle = None; continue
    if cur is None and line.startswith("bundle:"): pending_bundle = line.split()[1]; continue
    m = re.match(r"uti:\s+(\S+)$", line)
    if m:
        u = m.group(1); order += 1
        cur = {"uti": u, "conforms": [], "tags": {"ext": [], "mime": [], "ostype": [], "pboard": [], "other": []}, "flags": [], "desc": None, "bundles": [], "order": order, "icon": {}}; entries.append(cur)
        if pending_bundle and pending_bundle not in cur["bundles"]: cur["bundles"].append(pending_bundle)
        continue
    if cur is None: continue
    if line.startswith("icons:"): in_icons = True; continue
    if in_icons:
        if re.match(r"(conforms to|tags|flags|localizedDescription|bundle|uti|type id):", line) or line.startswith("-----"): in_icons = False
        else:
            for k, v in re.findall(r'"?([A-Za-z_][A-Za-z_\-]*)"?\s*=\s*"?([^";\s][^";]*?)"?;', line):
                if k in ("UTTypeIconFile", "UTTypeSymbolName", "ISSymbolName", "class-name", "_UTTypeTemplateIconFile", "UTTypeIconText", "UTTypeIconBadgeName", "UTTypeIconBackgroundName", "UTTypeIconCoreGlyphName") and k not in cur["icon"]: cur["icon"][k] = v
            continue
    m = re.match(r"bundle:\s+(\S+)", line)
    if m and m.group(1) not in cur["bundles"]: cur["bundles"].append(m.group(1))
    m = re.match(r"flags:\s+(.*?)\s+\(([0-9a-f]+)\)", line)
    if m:
        for f in m.group(1).split():
            if f not in cur["flags"]: cur["flags"].append(f)
    m = re.match(r'localizedDescription:\s+.*"LSDefaultLocalizedValue" = "([^"]*)"', line) or re.match(r'localizedDescription:\s+"en" = "([^"]*)"', line)
    if m and not cur["desc"]: cur["desc"] = m.group(1)
    m = re.match(r"conforms to:\s+(.*)", line)
    if m:
        for c in [x.strip() for x in m.group(1).split(",") if x.strip()]:
            if c not in cur["conforms"]: cur["conforms"].append(c)
    m = re.match(r"tags:\s+(.*)", line)
    if m:
        for tg in re.findall(r"""'[^']*'|"[^"]*"|[^,\s][^,]*""", m.group(1)):
            tg = tg.strip()
            if tg.startswith("."): k = "ext"; v = tg[1:]
            elif tg.startswith("'") and tg.endswith("'") and len(tg) >= 3: k = "ostype"; v = tg[1:-1]
            elif tg.startswith('"') and tg.endswith('"'): k = "pboard"; v = tg[1:-1]
            elif "/" in tg: k = "mime"; v = tg
            else: k = "other"; v = tg
            if v not in cur["tags"][k]: cur["tags"][k].append(v)
types = collections.OrderedDict()      # entries of inactive declarations (imported by an application that is not the owner) are ignored; the others are merged in the order of declaration
for e in entries:
    if "inactive" in e["flags"]: continue
    t = types.setdefault(e["uti"], {"uti": e["uti"], "conforms": [], "tags": {k: [] for k in e["tags"]}, "flags": [], "desc": None, "bundles": [], "order": e["order"], "icon": {}})
    for f in e["flags"]:
        if f not in t["flags"]: t["flags"].append(f)
    for b in e["bundles"]:
        if b not in t["bundles"]: t["bundles"].append(b)
    for c in e["conforms"]:
        if c not in t["conforms"]: t["conforms"].append(c)
    for k, vs in e["tags"].items():
        for v in vs:
            if v not in t["tags"][k]: t["tags"][k].append(v)
    t["desc"] = t["desc"] or e["desc"]
    for k, v in e["icon"].items(): t["icon"].setdefault(k, v)
json.dump(list(types.values()), open(sys.argv[2], "w"), ensure_ascii=False, separators=(",", ":"))
ext = sum(len(t["tags"]["ext"]) for t in types.values()); print("%d types, %d extension tags" % (len(types), ext))
