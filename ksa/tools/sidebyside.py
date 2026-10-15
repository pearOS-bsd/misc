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
# the window on wsd: find the first row/col where the title bar colour (35,35,36 +-3) block of width W starts
px = bsd.load(); sw, sh = bsd.size
best = None
for y in range(0, sh - H + 1):
    for x in range(0, sw - W + 1, 1):
        r, g, b = px[x + 100, y + 8]
        if abs(r - 35) < 6 and abs(g - 35) < 6 and abs(b - 36) < 6 and px[x + 100, y + H // 2][0] < 80 and abs(px[x + 100 + 1, y + 8][0] - r) < 4:
            best = (x, y); break
    if best: break
if not best: best = ((sw - W) // 2, (sh - H) // 2)
crop = bsd.crop((best[0], best[1], best[0] + W, best[1] + H))
bg = Image.new("RGBA", mac.size, (0, 0, 0, 255)); bg.alpha_composite(mac); macrgb = bg.convert("RGB")
diff = ImageChops.difference(macrgb, crop)
mean = sum(sum(p) for p in diff.getdata()) / (3.0 * W * H)
out = Image.new("RGB", (W * 3 + 20, H), (255, 0, 255))
out.paste(macrgb, (0, 0)); out.paste(crop, (W + 10, 0)); out.paste(diff.point(lambda v: min(255, v * 4)), (2 * W + 20, 0))
out.save(sys.argv[3]); print("window at", best, "mean abs diff per channel %.2f" % mean)
