#!/usr/bin/env python3
"""build.ninja of TextMate: rave writes a bash test ([[ ... ]], $'\\xFF\\xFE') into the UTF-16 conversion rule, and ninja runs rules with /bin/sh. Rewritten as POSIX sh (od instead of $'' strings)."""
import sys
path = sys.argv[1] if len(sys.argv) > 1 else "build.ninja"
s = open(path).read()
old = """[[ "$$(head -c2 $in)" == $$'\\xFF\\xFE' || "$$(head -c2 $in)" == $$'\\xFE\\xFF' ]]"""
t = """"$$(head -c2 $in | od -An -tx1 | tr -d ' \\n')\""""
new = "[ %s = fffe ] || [ %s = feff ]" % (t, t)
n = s.count(old)
open(path, "w").write(s.replace(old, new))
print("fix-ninja: %d rule(s) rewritten" % n)
