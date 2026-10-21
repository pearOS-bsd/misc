#!/usr/bin/env python3
"""libs-gui, NSScroller: a scroller has no intrinsic size. The scroll view sizes it, and the 9 x 15 of the cell made the layout engine hug the scrollers of every scroll view: a horizontal scroller
as wide as its scroll view pulled the scroll view narrow with the same weight as a gutter pulled itself narrow (the weights tied and the gutter of TextMate got 327 of 428 points).
usage: patch-scroller-intrinsic.py NSScroller.m"""
import sys
path = sys.argv[1]
s = open(path).read()
if "intrinsicContentSize" in s:
    sys.exit(0)
old = "- (BOOL) isFlipped\n"
assert old in s
s = s.replace(old, "- (NSSize) intrinsicContentSize\n{\n  return NSMakeSize(NSViewNoIntrinsicMetric, NSViewNoIntrinsicMetric);\n}\n\n" + old, 1)
open(path, "w").write(s)
