#!/usr/bin/env python3
"""Per-control side-by-side of the gallery rendered on macOS (AppKit) and BSD (GNUstep on wsd).
usage: compare.py MAC.png BSD_SCREEN.png MANIFEST OUT.png   (prints a table of mean absolute differences per control)"""
import sys
from PIL import Image, ImageChops, ImageDraw
mac = Image.open(sys.argv[1]).convert("RGBA"); bsd = Image.open(sys.argv[2]).convert("RGB")
bbox = mac.split()[3].point(lambda a: 255 if a > 250 else 0).getbbox(); mac = mac.crop(bbox) if bbox else mac
W, H = mac.size
bg = Image.new("RGBA", mac.size, (0, 0, 0, 255)); bg.alpha_composite(mac); macrgb = bg.convert("RGB")
px = bsd.load(); sw, sh = bsd.size
tb = macrgb.load()[W // 2, 20]
def near(c): return all(abs(c[i] - tb[i]) <= 6 for i in range(3))
best = None
for y in range(0, sh - 40):
    run = 0; start = 0
    for x in range(sw):
        if near(px[x, y]):
            if run == 0: start = x
            run += 1
            if run >= W - 80: break
        else: run = 0
    if run >= W - 80:
        while y > 0 and near(px[start + 100, y - 1]): y -= 1
        x0 = start
        while x0 > 0 and near(px[x0 - 1, y + 20]): x0 -= 1
        best = (x0 - 1, y - 1); break
if not best: best = ((sw - W) // 2, (sh - H) // 2)
crop = bsd.crop((best[0], best[1], best[0] + W, best[1] + H))
TB = H - 700                                              # the title bar height: the manifest uses content coordinates
rows = []; table = []
S = 3
for line in open(sys.argv[3]):
    t = line.split()
    if len(t) != 6 or t[0] != "CTRL": continue
    name, x, y, w, h = t[1], *map(int, t[2:])
    pad = 6; box = (max(0, x - pad), TB + y - pad, min(W, x + w + pad), TB + y + h + pad)
    a, b = macrgb.crop(box), crop.crop(box); d = ImageChops.difference(a, b)
    mean = sum(sum(p) for p in d.getdata()) / (3.0 * a.size[0] * a.size[1])
    table.append((mean, name)); rows.append((name, mean, a, b, d))
cw = max(r[2].size[0] for r in rows) * S; ch = max(r[2].size[1] for r in rows) * S
sheet = Image.new("RGB", (cw * 3 + 40 + 150, (ch + 6) * len(rows)), (60, 0, 60)); dr = ImageDraw.Draw(sheet)
for i, (name, mean, a, b, d) in enumerate(rows):
    y0 = i * (ch + 6); dr.text((4, y0 + 4), "%s\n%.1f" % (name, mean), fill=(255, 255, 255))
    for k, im in enumerate((a, b, d.point(lambda v: min(255, v * 3)))):
        sheet.paste(im.resize((im.size[0] * S, im.size[1] * S), Image.NEAREST), (150 + k * (cw + 10), y0))
sheet.save(sys.argv[4])
for mean, name in sorted(table, reverse=True): print("%6.2f  %s" % (mean, name))
print("window at", best)
