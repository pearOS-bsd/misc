#!/usr/bin/env python3
"""Overlay comparison of our render with a capture of the real Dock: writes a sheet [real | ours | 50% blend (real red, ours cyan) | difference x3] and prints the mean absolute difference.
usage: overlay.py REAL.png OURS.png OUT.png [x0 y0 x1 y1]   (optional crop box in image pixels, applied to both)"""
import sys
from PIL import Image, ImageChops
a = Image.open(sys.argv[1]).convert("RGB"); b = Image.open(sys.argv[2]).convert("RGB")
if len(sys.argv) > 8:
    box = tuple(int(v) for v in sys.argv[5:9]); a = a.crop(box); b = b.crop(box)
b = b.resize(a.size) if b.size != a.size else b
d = ImageChops.difference(a, b)
la, lb = a.convert("L"), b.convert("L")
blend = Image.merge("RGB", (la, lb, lb))
sheet = Image.new("RGB", (a.size[0] * 5 + 40, a.size[1]), (60, 0, 60))
for i, im in enumerate((a, b, blend, d.point(lambda v: min(255, v * 3)), Image.blend(a, b, 0.5))): sheet.paste(im, (i * (a.size[0] + 10), 0))
sheet.save(sys.argv[3])
n = a.size[0] * a.size[1] * 3
print("mean abs diff %.3f" % (sum(sum(p) for p in d.getdata()) / n))
