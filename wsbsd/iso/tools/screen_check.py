#!/usr/bin/env python3
"""screen_check.py PPM PNG: exit 0 when the QEMU screen shows a desktop (many colours, not dark), 1 otherwise; the PNG is a copy for the artifact."""
import sys
from PIL import Image
try:
    im = Image.open(sys.argv[1]).convert('RGB')
except Exception as e:
    print('no screen yet', e); sys.exit(1)
w, h = im.size
px = list(im.resize((160, 90)).getdata())
colors = len(set(px)); lum = sum(sum(p) for p in px) / (3 * len(px))
bar = list(im.crop((0, 0, w, 30)).resize((64, 4)).getdata()); barlum = sum(sum(p) for p in bar) / (3 * len(bar))
print('size', im.size, 'colours', colors, 'mean', round(lum, 1), 'bar', round(barlum, 1))
im.save(sys.argv[2])
# a desktop: either a wallpaper (many colours) or, on a flat background, the menu bar's text (bright pixels in its first 30 rows) and some content
top = im.crop((0, 0, w, 30)).convert('L'); bright = sum(1 for p in top.getdata() if p > 200)
print('bright pixels in the bar', bright)
sys.exit(0 if ((colors > 400 and lum > 12) or (bright > 150 and lum > 12)) else 1)
