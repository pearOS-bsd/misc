#!/usr/bin/env python3
"""xcb: builds an Xcode project's targets with clang on a non-Apple system, without editing the project.
usage: xcb.py PROJECT.xcodeproj list
       xcb.py PROJECT.xcodeproj plan TARGET   (prints what would be compiled, headers exposed and frameworks linked)
       xcb.py PROJECT.xcodeproj build TARGET [--out DIR] [--cc clang] [--cflags "..."] [--ldflags "..."] [--syntax-only] [-j N] [--dep-incs DIR,...] [--overlay overlay.json] [--bundle-libs a.so,b.so]
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
    deps = proj.dependencies(t); have = {d["id"] for d in deps}
    prod = {o.get("productReference"): k for k, o in proj.objs.items() if o.get("isa") == "PBXNativeTarget" and o.get("productReference")}
    for b in (proj.phase(t, "PBXFrameworksBuildPhase") or {}).get("files", []):     # implicit dependencies: a linked product of another target of the project
        fr = proj.objs[b].get("fileRef")
        if fr in prod and prod[fr] not in have and prod[fr] != t["id"]: have.add(prod[fr]); deps.append(proj.objs[prod[fr]] | {"id": prod[fr]})
    return dict(target=t, env=env, sources=src, headers=hdr, frameworks=fw, resources=res, deps=deps)

def stage_headers(p, out):
    name = p["env"]["PRODUCT_NAME"]; d = os.path.join(out, "headers", name); os.makedirs(d, exist_ok=True); n = 0
    for path, fr, st in p["headers"]:
        if os.path.exists(path):                                             # Xcode's header map exposes the target's Project headers too, inside the target
            dst = os.path.join(d, os.path.basename(path))
            if os.path.lexists(dst): os.remove(dst)
            os.symlink(os.path.realpath(path), dst); n += 1                    # a link, so #import sees one file whichever way it is reached
    return n

import re
_inc = re.compile(r'^\s*#\s*(?:import|include)\s*[<"]([^>"]+)[>"]', re.M)
def alias_case(proj, p, out):
    """The sources were written on a case-insensitive file system: an include whose case differs from the file's (HFFUnctions.h for HFFunctions.h) is made to resolve by a link."""
    hdrs = {}
    for oid, o in proj.objs.items():
        if o.get("isa") == "PBXFileReference" and o.get("path", "").endswith(".h") and os.path.exists(proj.path_of(oid)):
            hdrs.setdefault(os.path.basename(proj.path_of(oid)).lower(), os.path.realpath(proj.path_of(oid)))
    have = set()
    for root, dirs, files in os.walk(os.path.join(out, "headers")):
        for f in files: have.add(os.path.relpath(os.path.join(root, f), os.path.join(out, "headers")))
    srcdirs = {os.path.dirname(x[0]) for x in p["sources"] + p["headers"]}
    n = 0
    for path in [x[0] for x in p["sources"] + p["headers"]]:
        try: text = open(path, encoding="utf-8", errors="replace").read()
        except OSError: continue
        for name in _inc.findall(text):
            base = os.path.basename(name)
            if not base.endswith(".h") or name in have or any(os.path.exists(os.path.join(d, name)) for d in srcdirs): continue
            real = hdrs.get(base.lower())
            if real and os.path.basename(real) != base:
                dst = os.path.join(out, "headers", name); os.makedirs(os.path.dirname(dst), exist_ok=True)
                if not os.path.lexists(dst): os.symlink(real, dst); have.add(name); n += 1
    return n

def compile_flags(proj, p, out, extra):
    env = p["env"]; f = []
    f.append("-fobjc-arc" if str(env.get("CLANG_ENABLE_OBJC_ARC", "NO")) == "YES" else "-fno-objc-arc")
    if str(env.get("CLANG_ENABLE_MODULES", "NO")) == "YES":                  # `@import Cocoa;`: clang modules (the module maps of a non-Apple SDK come with --cflags)
        f += ["-fmodules", "-fimplicit-module-maps", "-fmodules-cache-path=" + os.path.join(os.path.dirname(out), "modcache")]
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
    seen = set()                                                              # Xcode's header map: every header the project references answers to its bare name
    for oid, o in proj.objs.items():
        if o.get("isa") == "PBXFileReference" and o.get("path", "").endswith(".h"):
            d = os.path.dirname(proj.path_of(oid))
            if d not in seen and os.path.isdir(d): seen.add(d); f += ["-idirafter", d]
    pch = env.get("GCC_PREFIX_HEADER")
    if pch and str(env.get("GCC_PRECOMPILE_PREFIX_HEADER", "NO")) != "NO_NEVER":
        pch = pbxproj.expand(pch, env); f += ["-include", pch if os.path.isabs(pch) else os.path.join(proj.root, pch)]
    return f

LIB_TYPES = ("com.apple.product-type.framework", "com.apple.product-type.library.dynamic", "com.apple.product-type.library.static")

def fw_flags(p, o):
    """Frameworks of the target's link phase: mapped with --fw-map "Cocoa=-lgnustep-gui;Foundation=-lgnustep-base" (on macOS the default is -framework NAME); the ones with no mapping are reported."""
    m = dict(x.split("=", 1) for x in o.get("--fw-map", "").split(";") if "=" in x)
    flags, unmapped = [], []
    for path, fr, st in p["frameworks"]:
        base = os.path.basename(path)
        if "$(BUILT_PRODUCTS_DIR)" in path: continue                        # another target of the project: linked through the dependency
        n = base.rsplit(".", 1)[0]
        if base.endswith((".framework", ".tbd", ".dylib")):
            if n in m: flags += shlex.split(m[n])
            elif not base.endswith(".framework"): flags.append("-l" + n.replace("lib", "", 1).split(".")[0])     # libz.1.tbd -> -lz
            elif sys.platform == "darwin": flags += ["-framework", n]
            else: unmapped.append(n)
    return flags, unmapped

def load_overlay(o):
    f = o.get("--overlay")
    if not f: return None
    import json
    d = json.load(open(f)); d["dir"] = os.path.dirname(os.path.abspath(f)); return d

def build_target(proj, name, o, out, state):
    if name in state: return state[name]["rc"]
    p = plan(proj, name); t = p["target"]; tout = os.path.join(out, name.replace(" ", "_")); os.makedirs(tout, exist_ok=True)
    cc = o.get("--cc", "clang"); cflags = shlex.split(o.get("--cflags", "")); syntax = "--syntax-only" in o
    dep_incs, dep_libs, rc = [], [], 0
    for d in p["deps"]:
        if d.get("productType") in LIB_TYPES:
            rc |= build_target(proj, d["name"], o, out, state)
            pr = state[d["name"]]; dep_incs.append(os.path.join(pr["tout"], "headers"))
            if pr.get("lib"): dep_libs.append(pr["lib"])
        else: print("(dependency %s is a %s: not built here)" % (d["name"], d.get("productType", d["isa"]).rsplit(".", 1)[-1]))
    ov = load_overlay(o)
    if ov:                                                                    # a port layer: sources written for the platform replace the ones that cannot be built (e.g. Swift)
        rep = {os.path.normpath(os.path.join(proj.root, k)): os.path.join(ov["dir"], v) for k, v in ov.get("replace", {}).items()}
        p["sources"] = [(rep.get(os.path.normpath(path), path), fr, st) for path, fr, st in p["sources"]]
        dep_incs += [os.path.join(ov["dir"], x) for x in ov.get("include", [])]
        cflags = cflags + ["-D" + x for x in ov.get("defines", [])]
    print("== target %s (%s)" % (name, (t.get("productType") or t["isa"]).rsplit(".", 1)[-1]))
    print("staged %d headers as <%s/...>" % (stage_headers(p, tout), p["env"]["PRODUCT_NAME"]))
    na = alias_case(proj, p, tout)
    if na: print("%d includes differ from the file name only by case (resolved by links)" % na)
    gen = os.path.join(tout, "gen"); gens = []
    for path, fr, st in p["sources"]:
        if path.endswith(".defs"):                                           # Mach IPC interface definitions: client stubs from the MIG stand-in
            subprocess.run([sys.executable, os.path.join(os.path.dirname(os.path.abspath(__file__)), "mig.py"), path, gen], check=False); gens.append(path)
    p["sources"] = [x for x in p["sources"] if x[0] not in gens]
    if gens: dep_incs.append(gen)
    base = compile_flags(proj, p, tout, dep_incs + [x for x in o.get("--dep-incs", "").split(",") if x])
    jobs = []; skipped = []
    for path, fr, st in p["sources"]:
        lang = SRC_EXT.get(os.path.splitext(path)[1])
        if lang is None or lang == "swift": skipped.append(path); continue
        extra = shlex.split(st.get("COMPILER_FLAGS", "")) if isinstance(st, dict) else []
        x = {"objc": ["-x", "objective-c"], "objc++": ["-x", "objective-c++", "-std=c++17"], "c": ["-x", "c"], "c++": ["-x", "c++", "-std=c++17"]}[lang]
        obj = os.path.join(tout, "obj", os.path.relpath(path, proj.root).replace("/", "_").replace("..", "up") + ".o")
        os.makedirs(os.path.dirname(obj), exist_ok=True)
        jobs.append((path, [cc] + cflags + base + extra + x + (["-fsyntax-only"] if syntax else ["-c", "-o", obj]) + [path], obj))
    def run(j):
        r = subprocess.run(j[1], capture_output=True, text=True); return j, r
    ok = 0; errs = []
    with ThreadPoolExecutor(max_workers=int(o.get("-j", 4))) as ex:
        for j, r in ex.map(run, jobs):
            if r.returncode == 0: ok += 1
            else:
                errs += [l for l in r.stderr.splitlines() if "error:" in l]
                if os.environ.get("XCB_V"):
                    print("FAILED:", j[0])
                    for l in [l for l in r.stderr.splitlines() if "error:" in l or l.startswith(" ")][:int(os.environ.get("XCB_V")) if os.environ.get("XCB_V").isdigit() else 30]: print("   ", l)
    print("%d of %d sources compile%s" % (ok, len(jobs), " (syntax only)" if syntax else ""))
    for sk in skipped: print("skipped (needs another toolchain):", os.path.relpath(sk, proj.root))
    from collections import Counter
    msgs = []
    for e in errs:
        m = re.search(r"error:\s*(.*)$", e)
        msgs.append((m.group(1).strip() or "(empty message)", e.split(": error", 1)[0]))
    where = {}
    for msg, loc in msgs: where.setdefault(msg, loc)
    for msg, n in Counter(m for m, _ in msgs).most_common(25):
        print("%4d %s   [%s]" % (n, msg, os.path.relpath(where[msg], proj.root) if os.path.isabs(where[msg]) else where[msg]))
    pr = {"tout": tout, "rc": rc | (0 if ok == len(jobs) else 2)}
    ptype = t.get("productType", ""); pname = p["env"]["PRODUCT_NAME"]
    if not syntax and ok == len(jobs) and jobs:
        objs = [j[2] for j in jobs]; fl, unmapped = fw_flags(p, o)
        ld = [x for x in pbxproj.expand(p["env"].get("OTHER_LDFLAGS", []), p["env"]) if x and x != "$(inherited)"] if sys.platform == "darwin" else []
        ld = ld if isinstance(ld, list) else shlex.split(ld)
        extra_ld = shlex.split(o.get("--ldflags", ""))
        if unmapped: print("frameworks with no --fw-map entry (not linked):", ", ".join(unmapped))
        if ptype in ("com.apple.product-type.framework", "com.apple.product-type.library.dynamic"):
            lib = os.path.join(tout, "lib" + pname.replace(" ", "") + o.get("--shared-ext", ".so" if sys.platform != "darwin" else ".dylib"))
            cmd = [cc, o.get("--shared-flag", "-shared" if sys.platform != "darwin" else "-dynamiclib"), "-o", lib] + objs + dep_libs + fl + ld + extra_ld
        elif ptype == "com.apple.product-type.library.static":
            lib = os.path.join(tout, "lib" + pname.replace(" ", "") + ".a"); cmd = ["ar", "rcs", lib] + objs
        else:
            lib = None; exe = os.path.join(tout, pname.replace(" ", "")); cmd = [cc, "-o", exe] + objs + dep_libs + fl + ld + extra_ld + ([] if sys.platform == "darwin" else ["-Wl,-rpath,$ORIGIN/lib"])
        r = subprocess.run(cmd, capture_output=True, text=True)
        target_file = lib or exe
        if r.returncode == 0:
            print("linked", os.path.relpath(target_file, out)); pr["lib"] = lib; pr["exe"] = None if lib else exe
            if ptype == "com.apple.product-type.application" and "--no-bundle" not in o: pr["app"] = make_bundle(proj, p, tout, pname, exe, dep_libs, o)
        else:
            print("link failed:"); pr["rc"] |= 2
            if os.environ.get("XCB_V"): print("  link command:", " ".join(shlex.quote(x) for x in cmd))
            und = sorted({l.split("undefined symbol:", 1)[1].strip() for l in r.stderr.splitlines() if "undefined symbol:" in l})
            if und: print("  undefined symbols (%d): %s" % (len(und), " ".join(und)))
            for l in [l for l in r.stderr.splitlines() if "undefined symbol:" not in l and not l.strip().startswith(">>>")][:12]: print("  " + l)
    state[name] = pr
    return pr["rc"]


def make_bundle(proj, p, tout, pname, exe, dep_libs, o):
    """A GNUstep application bundle: NAME.app/{NAME, lib/*.so, Resources/...}; the resources of the project (nibs and xibs from their .lproj directories are also placed at the top of
    Resources, where GNUstep looks without the Base localization), an Info-gnustep.plist made from the project's Info.plist."""
    import plistlib
    app = os.path.join(tout, pname.replace(" ", "") + ".app"); res = os.path.join(app, "Resources"); lib = os.path.join(app, "lib")
    shutil.rmtree(app, ignore_errors=True); os.makedirs(res); os.makedirs(lib)
    shutil.copy2(exe, os.path.join(app, os.path.basename(exe)))
    for l in dep_libs + [x for x in o.get("--bundle-libs", "").split(",") if x]:
        if os.path.exists(l): shutil.copy2(l, lib)
    n = 0
    for path, fr, st in p["resources"]:
        if not os.path.exists(path) or path.endswith((".icns", ".xcassets", ".xcdatamodeld")): continue
        parent = os.path.basename(os.path.dirname(path)); dstdir = res
        if parent.endswith(".lproj") and parent != "Base.lproj": dstdir = os.path.join(res, parent)
        os.makedirs(dstdir, exist_ok=True)
        if os.path.isdir(path): shutil.copytree(path, os.path.join(dstdir, os.path.basename(path)), dirs_exist_ok=True)
        else: shutil.copy2(path, os.path.join(dstdir, os.path.basename(path)))
        n += 1
    env = dict(p["env"]); env.update({"EXECUTABLE_NAME": pname.replace(" ", ""), "PRODUCT_NAME": pname, "TARGET_NAME": p["target"]["name"]})
    info = env.get("INFOPLIST_FILE")
    d = {}
    if info:
        ip = pbxproj.expand(info, env); ip = ip if os.path.isabs(ip) else os.path.join(proj.root, ip)
        if os.path.exists(ip):
            d = plistlib.load(open(ip, "rb"))
            for k, v in list(d.items()):
                if isinstance(v, str): d[k] = pbxproj.expand(v, env)
    d.setdefault("NSPrincipalClass", "NSApplication"); d["NSExecutable"] = pname.replace(" ", ""); d.setdefault("CFBundleName", pname)
    d.setdefault("CFBundleExecutable", pname.replace(" ", ""))
    plistlib.dump(d, open(os.path.join(res, "Info-gnustep.plist"), "wb"), fmt=plistlib.FMT_XML)
    print("bundle %s: %d resources, Info-gnustep.plist (NSMainNibFile=%s)" % (os.path.relpath(app, os.path.dirname(tout)), n, d.get("NSMainNibFile")))
    return app

def build(proj, name, o):
    out = os.path.abspath(o.get("--out", "xcb-out")); os.makedirs(out, exist_ok=True)
    return build_target(proj, name, o, out, {})

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
