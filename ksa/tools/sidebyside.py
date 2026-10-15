#!/usr/bin/env python3
"""Side-by-side comparison of the same pane rendered on macOS (AppKit) and on BSD (GNUstep on wsd).
usage: sidebyside.py MAC.png BSD_SCREEN.png OUT.png [--diff]
MAC.png is a window screenshot (screencapture -l, with or without shadow); BSD_SCREEN.png a whole wsd screenshot: the window is located by its
title bar colour. Writes the two renderings next to each other and a difference image, and prints the mean absolute difference."""
import sys
from PIL import Image, ImageChops
mac = Image.open(sys.argv[1]).convert("RGBA"); bsd = Image.open(sys.argv[2]).convert("RGB")
# the mac capture without shadow is the window itself; with shadow it is larger: crop the opaque bounding box
bbox = mac.split()[3].point(lambda a: 255 if a > 250 else 0).getbbox()
mac = mac.crop(bbox) if bbox else mac
W, H = mac.size
# the window on wsd: the top-most row with a long run of title bar colour; the run's left end (minus the 1 px rim) is the window's left edge
px = bsd.load(); sw, sh = bsd.size
tb = mac.convert("RGB").load()[W // 2, 20]                    # the mac title bar colour, sampled in the middle of the bar
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
        # row y is inside the bar: walk up to the top rim, then to the left rim
        while y > 0 and near(px[start + 100, y - 1]): y -= 1
        x0 = start
        while x0 > 0 and near(px[x0 - 1, y + 20]): x0 -= 1
        best = (x0 - 1, y - 1); break
if not best: best = ((sw - W) // 2, (sh - H) // 2)
crop = bsd.crop((best[0], best[1], best[0] + W, best[1] + H))
bg = Image.new("RGBA", mac.size, (0, 0, 0, 255)); bg.alpha_composite(mac); macrgb = bg.convert("RGB")
diff = ImageChops.difference(macrgb, crop)
mean = sum(sum(p) for p in diff.getdata()) / (3.0 * W * H)
out = Image.new("RGB", (W * 3 + 20, H), (255, 0, 255))
out.paste(macrgb, (0, 0)); out.paste(crop, (W + 10, 0)); out.paste(diff.point(lambda v: min(255, v * 4)), (2 * W + 20, 0))
out.save(sys.argv[3]); print("window at", best, "mean abs diff per channel %.2f" % mean)
