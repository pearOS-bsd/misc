#!/usr/bin/env python3
"""impl_skips.py FILE...: lists the methods the hand-written files define in `@implementation Class (Impl)` blocks as lines "-Class selector" / "+Class selector" (the skip file of tools/gen_objc_stubs.py: a
generated stub is not emitted for them). A method is a line starting with "- (" or "+ (" at the beginning of a line."""
import re, sys
cls = None
for path in sys.argv[1:]:
    for line in open(path):
        m = re.match(r"@implementation (\w+) \(Impl\)", line)
        if m: cls = m.group(1); continue
        if line.startswith("@end"): cls = None; continue
        if cls and re.match(r"[-+] ?\(", line):
            sign = line[0]
            # a line can hold several methods ("- (a)x { ... } - (b)y { ... }"): split on the method starts
            for part in re.split(r"(?<=[};])\s*(?=[-+] ?\()", line):
                part = part.strip()
                if not re.match(r"[-+] ?\(", part): continue
                sg = part[0]; rest = re.sub(r"^[-+] ?\([^)]*(?:\([^)]*\)[^)]*)*\)\s*", "", part)
                sel = ""
                m2 = re.match(r"(\w+)\s*(?=[{;]|$)", rest)
                if m2: sel = m2.group(1)
                else:
                    sel = "".join(x + ":" for x in re.findall(r"(\w+):\s*\(", rest))
                if sel: print("%s%s %s" % (sg, cls, sel))
