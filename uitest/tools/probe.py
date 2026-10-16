#!/usr/bin/env python3
"""Prints the colour transitions along the middle row and middle column of a control in the Mac gallery: probe.py MAC.png MANIFEST NAME [dx dy]"""
import sys
from PIL import Image
mac = Image.open(sys.argv[1]).convert("RGBA"); bb = mac.split()[3].point(lambda a: 255 if a > 250 else 0).getbbox(); mac = mac.crop(bb)
CH = next(int(l.split()[2]) for l in open(sys.argv[2]) if l.startswith("CONTENT"))
W, H = mac.size; TB = H - CH; p = mac.load()
for line in open(sys.argv[2]):
    t = line.split()
    if len(t) == 6 and t[1] == sys.argv[3]:
        x, y, w, h = map(int, t[2:]); break
else: sys.exit("no such control")
def runs(pts):
    out = []; prev = None
    for k, c in pts:
        if prev is None or sum(abs(a - b) for a, b in zip(c[:3], prev[:3])) > 6: out.append((k, tuple(c[:3])))
        prev = c
    return out
my = TB + y + h // 2; mx = x + w // 2
print("control", sys.argv[3], x, y, w, h, "(content coords)")
print("row  y=%d:" % (y + h // 2), runs([(i - x, p[i, my]) for i in range(x - 6, x + w + 6)])[:40])
print("col  x=%d:" % (w // 2), runs([(j - y, p[mx, j]) for j in range(TB + y - 6, TB + y + h + 6)])[:40])
