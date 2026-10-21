#!/usr/bin/env python3
"""build.ninja of TextMate: rave writes a bash test ([[ ... ]], $'\\xFF\\xFE') into the UTF-16 conversion rule, and ninja runs rules with /bin/sh. Rewritten as POSIX sh (od instead of $'' strings)."""
import sys
path = sys.argv[1] if len(sys.argv) > 1 else "build.ninja"
s = open(path).read()
old = """[[ "$$(head -c2 $in)" == $$'\\xFF\\xFE' || "$$(head -c2 $in)" == $$'\\xFE\\xFF' ]]"""
t = """"$$(head -c2 $in | od -An -tx1 | tr -d ' \\n')\""""
new = "[ %s = fffe ] || [ %s = feff ]" % (t, t)
n = s.count(old)
s = s.replace(old, new)
import re
s, m = re.subn(r"\$\$\(<(\S+?)\)", r"$$(cat \1)", s)             # bash's $(<file) is $(cat file) in sh
open(path, "w").write(s)
print("fix-ninja: %d + %d rule(s) rewritten" % (n, m))
