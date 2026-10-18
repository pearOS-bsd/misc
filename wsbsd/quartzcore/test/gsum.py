#!/usr/bin/env python3
"""gsum.py REAL OURS [tol]: sections of a golden run that differ"""
import re, sys
a = open(sys.argv[1]).read().split('\n'); b = open(sys.argv[2]).read().split('\n'); tol = float(sys.argv[3]) if len(sys.argv) > 3 else 2e-6
sec = None; cnt = {}
def nums(s): return re.findall(r'-?\d+\.?\d*(?:e[-+]?\d+)?|nan', s)
for x, y in zip(a, b):
    if x.startswith('##'): sec = x; continue
    if x != y:
        nx, ny = nums(x), nums(y)
        if len(nx) == len(ny) and all(p == q or p == 'nan' and q == 'nan' or (p != 'nan' and q != 'nan' and abs(float(p) - float(q)) <= tol * max(1, abs(float(p)))) for p, q in zip(nx, ny)): continue
        cnt.setdefault(sec, []).append((x, y))
for k, v in cnt.items(): print(k, len(v), v[0], v[1] if len(v) > 1 else '')
print('sections differing:', len(cnt))
