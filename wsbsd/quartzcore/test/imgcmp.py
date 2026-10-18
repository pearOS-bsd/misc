#!/usr/bin/env python3
"""imgcmp.py DIR_REAL DIR_OURS [OUTDIR]: compares the .bgra scenes (400x300): mean and max absolute error per scene; writes side-by-side PNGs when OUTDIR is given (needs PIL)"""
import sys, os
W, H = 400, 300
try:
    from PIL import Image
except ImportError:
    Image = None
a, b = sys.argv[1], sys.argv[2]; out = sys.argv[3] if len(sys.argv) > 3 else None
tot = 0
for f in sorted(os.listdir(a)):
    if not f.endswith('.bgra') or not os.path.exists(os.path.join(b, f)): continue
    x = open(os.path.join(a, f), 'rb').read(); y = open(os.path.join(b, f), 'rb').read()
    n = len(x); s = 0; m = 0; bad = 0
    for i in range(0, n, 4):
        d = max(abs(x[i] - y[i]), abs(x[i + 1] - y[i + 1]), abs(x[i + 2] - y[i + 2]), abs(x[i + 3] - y[i + 3]))
        s += d; m = max(m, d)
        if d > 8: bad += 1
    print('%-20s mean abs err %.3f  max %3d  pixels off by >8: %d (%.2f%%)' % (f[:-5], s / (n / 4), m, bad, 100.0 * bad / (n / 4)))
    if out and Image:
        os.makedirs(out, exist_ok=True)
        def img(d):
            im = Image.frombytes('RGBA', (W, H), d, 'raw', 'BGRA'); bg = Image.new('RGBA', (W, H), (0, 0, 0, 255)); bg.alpha_composite(im); return bg
        d = bytes(abs(x[i] - y[i]) for i in range(n)); 
        diff = Image.frombytes('RGBA', (W, H), bytes(min(255, 4 * v) if j % 4 != 3 else 255 for j, v in enumerate(d)), 'raw', 'BGRA')
        sheet = Image.new('RGB', (W * 3, H)); sheet.paste(img(x).convert('RGB'), (0, 0)); sheet.paste(img(y).convert('RGB'), (W, 0)); sheet.paste(diff.convert('RGB'), (2 * W, 0)); sheet.save(os.path.join(out, f[:-5] + '.png'))
