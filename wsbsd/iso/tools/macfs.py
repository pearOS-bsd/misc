#!/usr/bin/env python3
"""The macOS file layout on a FreeBSD root, real files only.

  macfs.py skeleton  ROOT MANIFEST   create every directory of the reference Mac (modes included) and a minimal Info.plist in every framework / application bundle that has a Resources or Contents directory
  macfs.py install   ROOT MANIFEST COMPONENTS   put what we built where the Mac has it (frameworks: Versions/<letter>/<Name>; applications; tools), then turn every symlink entry of the manifest into a real copy
  macfs.py desymlink ROOT   replace every symlink below ROOT (FreeBSD base has some) by a copy of its target; dangling ones are removed
  macfs.py verify    ROOT MANIFEST   exit 1 if there is a symlink, or a directory of the manifest is missing; prints the coverage

Only names, types and modes come from the Mac (iso/manifest, made by tools/mac-manifest.sh); the contents are ours."""
import functools, json, os, shutil, stat, sys

def read(manifest, name):
    out = []
    with open(os.path.join(manifest, name), errors="replace") as f:
        for line in f:
            if line.startswith("#") or not line.strip(): continue
            t, mode, rest = line.rstrip("\n").split(" ", 2)
            target = None
            if t == "l" and " -> " in rest: rest, target = rest.split(" -> ", 1)
            out.append((t, int(mode, 8), rest, target))
    return out

TREE_FILES = ["layout.txt", "system.txt", "frameworks.txt", "privateframeworks.txt", "coreservices.txt", "system-applications.txt", "usr-lib.txt"]

@functools.lru_cache(maxsize=None)
def all_entries(manifest):
    seen, res = set(), []
    for n in TREE_FILES:
        for e in read(manifest, n):
            if e[2] in seen: continue
            seen.add(e[2]); res.append(e)
    return tuple(res)

def dest(root, p): return os.path.join(root, p.lstrip("/"))

def skeleton(root, manifest):
    n = 0
    for t, mode, path, target in all_entries(manifest):
        if t == "d" and path != "/":
            d = dest(root, path); os.makedirs(d, exist_ok=True)
            try: os.chmod(d, mode or 0o755)
            except OSError: pass
            n += 1
    # an Info.plist in every bundle that the manifest lists as a framework / app directory
    entries = all_entries(manifest); vmap = {}
    for tt, _, p, _ in entries:
        if tt == "d" and os.path.basename(os.path.dirname(p)) == "Versions": vmap.setdefault(os.path.dirname(os.path.dirname(p)), []).append(os.path.basename(p))
    for t, mode, path, target in entries:
        if t != "d": continue
        for ext, sub in ((".framework", "Versions"), (".app", "Contents")):
            if path.endswith(ext):
                base = os.path.basename(path)[:-len(ext)]
                if ext == ".framework":
                    vers = vmap.get(path, [])
                    for v in vers:
                        rd = dest(root, path + "/Versions/" + v + "/Resources"); os.makedirs(rd, exist_ok=True)
                        write_plist(os.path.join(rd, "Info.plist"), base, "FMWK", v)
                else:
                    cd = dest(root, path + "/Contents"); os.makedirs(cd, exist_ok=True)
                    write_plist(os.path.join(cd, "Info.plist"), base, "APPL", "1.0")
    print("skeleton: %d directories" % n)

def write_plist(path, name, kind, version):
    if os.path.exists(path): return
    ident = "com.apple." + name.replace(" ", "")
    with open(path, "w") as f:
        f.write('<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0">\n<dict>\n'
                '\t<key>CFBundleIdentifier</key>\n\t<string>%s</string>\n\t<key>CFBundleName</key>\n\t<string>%s</string>\n\t<key>CFBundlePackageType</key>\n\t<string>%s</string>\n'
                '\t<key>CFBundleVersion</key>\n\t<string>%s</string>\n</dict>\n</plist>\n' % (ident, name, kind, version))

def copy_real(src, dst):
    if os.path.isdir(src) and not os.path.islink(src):
        shutil.copytree(src, dst, symlinks=False, dirs_exist_ok=True)
    else:
        os.makedirs(os.path.dirname(dst), exist_ok=True); shutil.copy2(src, dst)

def install(root, manifest, comp_file):
    comp = json.load(open(comp_file)); entries = all_entries(manifest); placed = 0
    def fw_dirs(kind, name):
        base = "/System/Library/%s/%s.framework" % (kind, name)
        vers = sorted(os.path.basename(p) for t, _, p, _ in entries if t == "d" and os.path.dirname(p) == base + "/Versions")
        return base, vers
    for kind, key in (("Frameworks", "frameworks"), ("PrivateFrameworks", "privateframeworks")):
        for name, spec in comp.get(key, {}).items():
            base, vers = fw_dirs(kind, name)
            if not vers: print("no such framework on the Mac: %s" % base); continue
            v = vers[-1]
            for src in spec.get("binary", []) if isinstance(spec.get("binary"), list) else [spec.get("binary")]:
                if src and os.path.exists(os.path.join(root, src.lstrip("/"))):
                    copy_real(os.path.join(root, src.lstrip("/")), dest(root, "%s/Versions/%s/%s" % (base, v, name))); placed += 1; break
            for rsrc, rdst in spec.get("resources", {}).items():
                s = os.path.join(root, rsrc.lstrip("/"))
                if os.path.exists(s): copy_real(s, dest(root, "%s/Versions/%s/Resources/%s" % (base, v, rdst))); placed += 1
    for dst, src in comp.get("files", {}).items():            # arbitrary placements: destination path on the Mac layout <- path in the staging root
        s = os.path.join(root, src.lstrip("/"))
        if os.path.exists(s): copy_real(s, dest(root, dst)); placed += 1
        else: print("missing component source %s" % src)
    # symlink entries of the manifest become real copies (shortest paths first: Versions/Current before AppKit -> Versions/Current/AppKit)
    links = sorted([e for e in entries if e[0] == "l"], key=lambda e: e[2].count("/"))
    for t, mode, path, target in links:
        d = dest(root, path)
        src = os.path.normpath(os.path.join(os.path.dirname(d), target)) if not target.startswith("/") else dest(root, target)
        if os.path.lexists(d) or not os.path.exists(src): continue
        copy_real(src, d); placed += 1
    print("install: %d placements" % placed)

def desymlink(root):
    n = 0
    for _ in range(8):                                            # a link may point at a link: repeat until none is left
        links = []
        for dp, dn, fn in os.walk(root):
            for x in dn + fn:
                p = os.path.join(dp, x)
                if os.path.islink(p): links.append(p)
        if not links: break
        for p in links:
            t = os.readlink(p)
            src = os.path.join(root, t.lstrip("/")) if t.startswith("/") else os.path.normpath(os.path.join(os.path.dirname(p), t))
            os.unlink(p)
            if os.path.exists(src) and not os.path.islink(src):
                copy_real(src, p); n += 1
    print("desymlink: %d links replaced by copies" % n)

def verify(root, manifest):
    bad = 0
    links = []
    for dp, dn, fn in os.walk(root):
        for x in dn + fn:
            if os.path.islink(os.path.join(dp, x)): links.append(os.path.join(dp, x)[len(root):])
    if links:
        print("SYMLINKS (%d), for example:" % len(links)); [print("  " + l) for l in links[:15]]; bad = 1
    dirs = [(p) for t, _, p, _ in all_entries(manifest) if t == "d"]
    missing = [p for p in dirs if not os.path.isdir(dest(root, p))]
    print("directories of the Mac manifest: %d, present: %d" % (len(dirs), len(dirs) - len(missing)))
    if missing: print("MISSING directories, for example:"); [print("  " + m) for m in missing[:15]]; bad = 1
    files = [(p) for t, _, p, _ in all_entries(manifest) if t in ("f", "l") and "/Versions/" not in p.replace("/Versions/Current", "") or False]
    fw = [p for t, _, p, _ in all_entries(manifest) if t == "d" and p.startswith("/System/Library/Frameworks/") and p.endswith(".framework")]
    have = [p for p in fw if os.path.exists(os.path.join(dest(root, p), "Versions"))]
    withbin = 0
    for p in fw:
        nm = os.path.basename(p)[:-10]
        if os.path.isfile(os.path.join(dest(root, p), nm)): withbin += 1
    print("frameworks on the Mac: %d, present: %d, with their own library: %d" % (len(fw), len(have), withbin))
    return bad

if __name__ == "__main__":
    c = sys.argv[1] if len(sys.argv) > 1 else ""
    if c == "skeleton": skeleton(sys.argv[2], sys.argv[3])
    elif c == "install": install(sys.argv[2], sys.argv[3], sys.argv[4])
    elif c == "desymlink": desymlink(sys.argv[2])
    elif c == "verify": sys.exit(verify(sys.argv[2], sys.argv[3]))
    else: print(__doc__); sys.exit(2)
