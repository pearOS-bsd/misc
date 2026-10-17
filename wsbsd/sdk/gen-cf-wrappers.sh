#!/bin/sh
# Generates patched COPIES of the CoreFoundation headers (the installed ones are not touched) in which the declarations sit inside
# `#pragma clang arc_cf_code_audited`, the way Apple's headers do with CF_IMPLICIT_BRIDGING_ENABLED. Without it clang's ARC checker rejects
# `(const void *)obj` style casts in calls to CF functions, which Apple's clang accepts. usage: gen-cf-wrappers.sh OUTDIR [HEADER_DIR]
OUT="${1:?output directory}"; SRC="${2:-$(gnustep-config --variable=GNUSTEP_SYSTEM_HEADERS 2>/dev/null)}"
SRC="${SRC:-/usr/local/GNUstep/System/Library/Headers}"
LOCAL="$(dirname "$SRC")"; LOCAL="${LOCAL%/System/Library}/Local/Library/Headers"
rm -rf "$OUT"; mkdir -p "$OUT"
python3 - "$SRC" "$OUT" "$LOCAL" <<'PY'
import os, re, sys
roots, outroot = [sys.argv[1], sys.argv[3]], sys.argv[2]; n = 0
opn = re.compile(r"\s*#\s*if(n?def)?\b"); cls = re.compile(r"\s*#\s*endif\b"); inc = re.compile(r"\s*#\s*(include|import)\b")
for fw in ("CoreFoundation", "CoreText", "CoreGraphics", "ImageIO"):
  out = os.path.join(outroot, fw)
  srcs = [os.path.join(r, fw) for r in roots if os.path.isdir(os.path.join(r, fw))]
  if not srcs: continue
  os.makedirs(out, exist_ok=True)
  files = {}
  for sdir in srcs:
    for nm in os.listdir(sdir): files.setdefault(nm, os.path.join(sdir, nm))
  for name in sorted(files):
    if not name.endswith(".h"): continue
    src = os.path.dirname(files[name])
    lines = open(os.path.join(src, name), encoding="utf-8", errors="replace").read().split("\n")
    depth = []; d = 0; stack = []; match = {}
    for i, l in enumerate(lines):
        if opn.match(l): d += 1; stack.append(i)
        depth.append(d)
        if cls.match(l) and stack: match[stack.pop()] = i; d -= 1
    first = next((i for i, l in enumerate(lines) if opn.match(l)), -1)
    last_end = max(match.values()) if match else -1
    guarded = first >= 0 and first in match and match[first] == last_end and all(not l.strip() or l.lstrip().startswith(("//", "/*", "*")) for l in lines[last_end + 1:])
    base = 1 if guarded else 0
    guard_end = match[first] if guarded else len(lines)
    last_inc = -1
    for i in range(guard_end):
        if inc.match(lines[i]): last_inc = i
    start = last_inc + 1
    if last_inc >= 0 and depth[last_inc] > base:                    # the last include sits in a nested conditional: the region begins after that block
        j = last_inc
        while j < guard_end and not (cls.match(lines[j]) and depth[j] == base + 1): j += 1
        start = j + 1
    elif last_inc < 0:
        start = next((i + 1 for i, l in enumerate(lines[:guard_end]) if re.match(r"\s*#\s*define\b", l)), 0)
    if start > guard_end: start = guard_end
    lines.insert(guard_end, "#pragma clang arc_cf_code_audited end")
    lines.insert(start, "#pragma clang arc_cf_code_audited begin")
    open(os.path.join(out, name), "w").write("\n".join(lines)); n += 1
print("patched %d headers (CoreFoundation, CoreText, CoreGraphics, ImageIO) into %s" % (n, outroot))

# Declarations where Apple's headers are more precise than GNUstep's: patched copies of single headers (the installed ones are not touched).
# old text -> new text; every pair has to match exactly once or the header is left as it is.
PATCHES = {
  "AppKit/NSMenuItem.h": [("@protocol NSMenuItem <NSValidatedUserInterfaceItem, NSCopying, NSCoding, NSObject>",
                           "@protocol NSMenuItem <NSValidatedUserInterfaceItem, NSCopying, NSCoding, NSObject>\n@property (nonatomic, getter=isEnabled) BOOL enabled;")],
  "AppKit/NSWindow.h": [("- (id) windowController;", "- (NSWindowController *) windowController;")],
  "AppKit/NSAlert.h": [("- (id) window;", "- (NSWindow *) window;")],
  "Foundation/NSFileManager.h": [("@class NSDirectoryEnumerator;", "@class NSDirectoryEnumerator<ObjectType>;"),
                                 ("@interface NSDirectoryEnumerator : NSEnumerator", "@interface NSDirectoryEnumerator<__covariant ObjectType> : NSEnumerator")],
}
np = 0
for rel, pairs in PATCHES.items():
    for r in roots:
        f = os.path.join(r, rel)
        if not os.path.exists(f): continue
        t = open(f, encoding="utf-8", errors="replace").read()
        if all(t.count(a) == 1 for a, _ in pairs):
            for a, b in pairs: t = t.replace(a, b)
            dst = os.path.join(outroot, rel); os.makedirs(os.path.dirname(dst), exist_ok=True); open(dst, "w").write(t); np += 1
        else: print("patch skipped (declaration not found exactly once):", rel)
        break
print("patched %d AppKit / Foundation headers" % np)
PY
