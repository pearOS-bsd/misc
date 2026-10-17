#!/usr/bin/env python3
"""xcb: builds an Xcode project's targets with clang on a non-Apple system, without editing the project.
usage: xcb.py PROJECT.xcodeproj list
       xcb.py PROJECT.xcodeproj plan TARGET   (prints what would be compiled, headers exposed and frameworks linked)
       xcb.py PROJECT.xcodeproj build TARGET [--out DIR] [--cc clang] [--cflags "..."] [--ldflags "..."] [--syntax-only] [-j N] [--dep-incs DIR,...]
         stages the public / private headers as <Product/Header.h> (what an Xcode framework target exposes), compiles every C / Objective-C(++) source
         with the target's settings (ARC, defines, prefix header, header search paths, per-file flags) and links; Swift sources are reported and skipped"""
import sys, os, shutil, subprocess, shlex
from concurrent.futures import ThreadPoolExecutor
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pbxproj

SRC_EXT = {".m": "objc", ".mm": "objc++", ".c": "c", ".cpp": "c++", ".cc": "c++", ".swift": "swift"}

def plan(proj, name):
    t = proj.target(name)
    if not t: raise SystemExit("no target " + name)
    env = proj.settings(t)
    env.update({"SRCROOT": proj.root, "PROJECT_DIR": proj.root, "TARGET_NAME": t["name"], "PRODUCT_NAME": env.get("PRODUCT_NAME", t["name"])})
    env["PRODUCT_NAME"] = pbxproj.expand(env["PRODUCT_NAME"], env)
    src = proj.phase_files(proj.phase(t, "PBXSourcesBuildPhase"))
    hdr = proj.phase_files(proj.phase(t, "PBXHeadersBuildPhase"))
    fw = proj.phase_files(proj.phase(t, "PBXFrameworksBuildPhase"))
    res = proj.phase_files(proj.phase(t, "PBXResourcesBuildPhase"))
    return dict(target=t, env=env, sources=src, headers=hdr, frameworks=fw, resources=res, deps=proj.dependencies(t))

def stage_headers(p, out):
    name = p["env"]["PRODUCT_NAME"]; d = os.path.join(out, "headers", name); os.makedirs(d, exist_ok=True); n = 0
    for path, fr, st in p["headers"]:
        if os.path.exists(path):                                             # Xcode's header map exposes the target's Project headers too, inside the target
            shutil.copyfile(path, os.path.join(d, os.path.basename(path))); n += 1
    return n

def compile_flags(proj, p, out, extra):
    env = p["env"]; f = []
    if str(env.get("CLANG_ENABLE_OBJC_ARC", "NO")) == "YES": f.append("-fobjc-arc")
    f += ["-fblocks", "-I" + os.path.join(out, "headers")] + ["-I" + x for x in extra]
    dirs = sorted({os.path.dirname(x[0]) for x in p["sources"] + p["headers"]})
    f += ["-I" + x for x in dirs]
    for v in pbxproj.expand(env.get("HEADER_SEARCH_PATHS", []), env) if isinstance(env.get("HEADER_SEARCH_PATHS", []), list) else shlex.split(pbxproj.expand(env.get("HEADER_SEARCH_PATHS", ""), env)):
        v = v.replace("\"", "")
        if v and v != "$(inherited)": f.append("-I" + (v if os.path.isabs(v) else os.path.join(proj.root, v)))
    for k in ("GCC_PREPROCESSOR_DEFINITIONS",):
        v = env.get(k, [])
        for x in (v if isinstance(v, list) else shlex.split(pbxproj.expand(v, env))):
            x = pbxproj.expand(x, env)
            if x and x != "$(inherited)": f.append("-D" + x)
    pch = env.get("GCC_PREFIX_HEADER")
    if pch and str(env.get("GCC_PRECOMPILE_PREFIX_HEADER", "NO")) != "NO_NEVER":
        pch = pbxproj.expand(pch, env); f += ["-include", pch if os.path.isabs(pch) else os.path.join(proj.root, pch)]
    return f

def build(proj, name, o):
    p = plan(proj, name); t = p["target"]; out = os.path.abspath(o.get("--out", "xcb-out")); os.makedirs(out, exist_ok=True)
    cc = o.get("--cc", "clang"); cflags = shlex.split(o.get("--cflags", "")); syntax = "--syntax-only" in o
    print("staged %d headers as <%s/...>" % (stage_headers(p, out), p["env"]["PRODUCT_NAME"]))
    base = compile_flags(proj, p, out, [x for x in o.get("--dep-incs", "").split(",") if x])
    jobs = []; skipped = []
    for path, fr, st in p["sources"]:
        lang = SRC_EXT.get(os.path.splitext(path)[1])
        if lang is None or lang == "swift": skipped.append(path); continue
        extra = shlex.split(st.get("COMPILER_FLAGS", "")) if isinstance(st, dict) else []
        x = {"objc": ["-x", "objective-c"], "objc++": ["-x", "objective-c++", "-std=c++17"], "c": ["-x", "c"], "c++": ["-x", "c++", "-std=c++17"]}[lang]
        obj = os.path.join(out, "obj", t["name"], os.path.relpath(path, proj.root).replace("/", "_").replace("..", "up") + ".o")
        os.makedirs(os.path.dirname(obj), exist_ok=True)
        jobs.append((path, [cc] + cflags + base + extra + x + (["-fsyntax-only"] if syntax else ["-c", "-o", obj]) + [path], obj))
    def run(j):
        r = subprocess.run(j[1], capture_output=True, text=True); return j, r
    ok = 0; errs = []
    with ThreadPoolExecutor(max_workers=int(o.get("-j", 4))) as ex:
        for j, r in ex.map(run, jobs):
            if r.returncode == 0: ok += 1
            else: errs += [l for l in r.stderr.splitlines() if "error:" in l]
    print("%d of %d sources compile%s" % (ok, len(jobs), " (syntax only)" if syntax else ""))
    for sk in skipped: print("skipped (needs another toolchain):", os.path.relpath(sk, proj.root))
    from collections import Counter
    where = {}
    for e in errs: where.setdefault(e.split("error: ", 1)[1], e.split(": error", 1)[0])
    for msg, n in Counter(e.split("error: ", 1)[1] for e in errs).most_common(25):
        print("%4d %s   [%s]" % (n, msg, os.path.relpath(where[msg], proj.root)))
    return 0 if ok == len(jobs) else 2

def main(a):
    if len(a) < 2: print(__doc__); return 1
    proj = pbxproj.Project(a[0]); cmd = a[1]
    if cmd == "list":
        for t in proj.targets(): print("%-40s %s" % (t.get("name"), t.get("productType", t["isa"])))
    elif cmd == "plan":
        p = plan(proj, a[2]); t = p["target"]
        print("target %s (%s), product %s" % (t["name"], t.get("productType"), p["env"]["PRODUCT_NAME"]))
        print("depends on:", ", ".join(d["name"] for d in p["deps"]) or "-")
        langs = {}
        for path, fr, st in p["sources"]: langs.setdefault(SRC_EXT.get(os.path.splitext(path)[1], "other"), []).append(path)
        for k, v in sorted(langs.items()): print("  %d %s sources" % (len(v), k))
        for path, fr, st in p["headers"]:
            att = (st.get("ATTRIBUTES") or ["Project"])[0]
            print("  header %-8s %s" % (att, os.path.relpath(path, proj.root)))
        for path, fr, st in p["frameworks"]: print("  links", os.path.basename(path))
        print("  %d resources" % len(p["resources"]))
        for k in ("GCC_PREFIX_HEADER", "HEADER_SEARCH_PATHS", "GCC_PREPROCESSOR_DEFINITIONS", "CLANG_ENABLE_OBJC_ARC", "OTHER_LDFLAGS"):
            if k in p["env"]: print("  %s = %s" % (k, p["env"][k]))
    elif cmd == "build":
        o = {}; i = 3
        while i < len(a):
            if a[i] == "--syntax-only": o[a[i]] = 1; i += 1
            else: o[a[i]] = a[i + 1]; i += 2
        return build(proj, a[2], o)
    return 0

if __name__ == "__main__": sys.exit(main(sys.argv[1:]))
