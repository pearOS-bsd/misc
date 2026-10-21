#!/bin/sh
# libs-gui: NSImage keeps a bit field called "template", a keyword of C++: no Objective-C++ file can include <AppKit/AppKit.h>. Renamed in the header and in NSImage.m (the layout is the same).
# usage: patch-nsimage-template.sh GUI_SOURCE_DIR [INSTALLED_HEADER_DIR]
python3 - "$@" <<'PY'
import sys, re
g = sys.argv[1]
def sub(path, pat, rep):
    try:
        s = open(path).read()
    except OSError:
        return
    n = re.sub(pat, rep, s)
    if n != s:
        open(path, "w").write(n)
sub(g + "/Headers/AppKit/NSImage.h", r"unsigned(\s+)template: 1;", r"unsigned\1templateFlag: 1;")
sub(g + "/Source/NSImage.m", r"_flags\.template\b", "_flags.templateFlag")
if len(sys.argv) > 2:
    sub(sys.argv[2] + "/AppKit/NSImage.h", r"unsigned(\s+)template: 1;", r"unsigned\1templateFlag: 1;")
PY
grep -n "templateFlag" "$1/Headers/AppKit/NSImage.h" "$1/Source/NSImage.m" | head -3
