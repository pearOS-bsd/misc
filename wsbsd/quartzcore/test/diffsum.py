#!/usr/bin/env python3
"""diffsum.py REAL OURS [N]: groups the differences of a fuzz run by scenario kind and key"""
import re, sys
a = open(sys.argv[1]).read().split('\n'); b = open(sys.argv[2]).read().split('\n'); N = int(sys.argv[3]) if len(sys.argv) > 3 else 3
def nums(s): return re.findall(r'-?\d+\.?\d*(?:e[-+]?\d+)?|nan|inf', s)
cnt = {}
for x, y in zip(a, b):
    if x == y or not x.startswith('#'): continue
    nx, ny = nums(x), nums(y)
    try:
        if len(nx) == len(ny) and all((p == q) or abs(float(p) - float(q)) <= 2e-5 * max(1, abs(float(p))) for p, q in zip(nx, ny)): continue
    except ValueError: pass
    m = re.match(r'#\d+ kind=(\d) key=(\S+)', x); cnt.setdefault((m.group(1), m.group(2)), []).append((x, y))
for k, v in sorted(cnt.items()):
    print('kind %s key %s: %d' % (k[0], k[1], len(v)))
    for q in v[:N]: print('   real', q[0]); print('   ours', q[1])
