#!/usr/bin/env python3
"""framework_dups.py A B: the classes that the inventory of framework A (docs/desktop/frameworks/A.objc.txt) lists but that belong to framework B too (objc_dump picks classes by image file name), comma separated."""
import sys
def classes(n): return [l.split()[1] for l in open("docs/desktop/frameworks/%s.objc.txt" % n) if l.startswith("@class")]
b = set(classes(sys.argv[2])); print(",".join(c for c in classes(sys.argv[1]) if c in b))
