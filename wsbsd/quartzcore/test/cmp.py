#!/usr/bin/env python3
"""cmp.py REAL OURS [tolerance]: compares two outputs line by line; numbers are compared with a relative tolerance (default 1e-9), everything else must be equal."""
import sys, re
tol = float(sys.argv[3]) if len(sys.argv) > 3 else 1e-9
num = re.compile(r'-?\d+\.?\d*(?:e[-+]?\d+)?|-?inf|nan', re.I)
a = open(sys.argv[1]).read().split('\n'); b = open(sys.argv[2]).read().split('\n')
bad = 0
if len(a) != len(b): print('line counts differ', len(a), len(b)); bad += 1
for i, (x, y) in enumerate(zip(a, b)):
    if x == y: continue
    tx, ty = num.findall(x), num.findall(y)
    sx, sy = num.sub('#', x), num.sub('#', y)
    ok = sx == sy and len(tx) == len(ty)
    if ok:
        for p, q in zip(tx, ty):
            try: u, v = float(p), float(q)
            except ValueError: ok = p == q; continue
            if u != u and v != v: continue
            if abs(u - v) > tol * max(1.0, abs(u), abs(v)): ok = False; break
    if not ok:
        bad += 1
        if bad <= 12: print('line %d:\n  real: %s\n  ours: %s' % (i + 1, x, y))
print('%d lines compared, %d differences' % (len(a), bad))
sys.exit(1 if bad else 0)
