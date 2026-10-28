#!/usr/bin/env python3
"""Demo content of the images: the files a new account has (Desktop, Documents, Downloads, ...) with a few folders and files on the Desktop and one folder ("Sample Files") that holds a lot of mixed files and folders, so that the Finder, the desktop and the Dock stacks have something to show.
Usage: mkdemo.py DIR   (DIR becomes the "User Template": the rc script copies it into the home of the session). Everything is generated here (no third-party files): text, csv, json, small PNGs, PDFs with one line of text, zip archives, scripts and source files."""
import os, sys, zlib, struct, zipfile, random, time, json

out = sys.argv[1]
random.seed(7)

def w(path, data, mtime_days=0):
    p = os.path.join(out, path)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    mode = "wb" if isinstance(data, bytes) else "w"
    with open(p, mode) as f:
        f.write(data)
    if mtime_days:
        t = time.time() - mtime_days * 86400 - random.randint(0, 80000)
        os.utime(p, (t, t))

def d(path):
    os.makedirs(os.path.join(out, path), exist_ok=True)

def png(wd, ht, fn):
    raw = b"".join(b"\0" + b"".join(bytes(fn(x, y, wd, ht)) for x in range(wd)) for y in range(ht))
    def chunk(t, b):
        c = struct.pack(">I", len(b)) + t + b
        return c + struct.pack(">I", zlib.crc32(t + b) & 0xffffffff)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", wd, ht, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")

def gradient(a, b):
    return lambda x, y, wd, ht: (int(a[0] + (b[0] - a[0]) * x / wd), int(a[1] + (b[1] - a[1]) * y / ht), int(a[2] + (b[2] - a[2]) * (x + y) / (wd + ht)))

def pdf(text):
    body = "BT /F1 18 Tf 72 720 Td (%s) Tj ET" % text.replace("(", "[").replace(")", "]")
    objs = ["<< /Type /Catalog /Pages 2 0 R >>", "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>",
            "<< /Length %d >>\nstream\n%s\nendstream" % (len(body), body), "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"]
    b = b"%PDF-1.4\n"; offs = []
    for i, o in enumerate(objs):
        offs.append(len(b)); b += ("%d 0 obj\n%s\nendobj\n" % (i + 1, o)).encode()
    x = len(b); b += ("xref\n0 %d\n0000000000 65535 f \n" % (len(objs) + 1)).encode()
    for o in offs: b += ("%010d 00000 n \n" % o).encode()
    return b + ("trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n" % (len(objs) + 1, x)).encode()

def zipbytes(files):
    import io
    bio = io.BytesIO()
    with zipfile.ZipFile(bio, "w", zipfile.ZIP_DEFLATED) as z:
        for n, t in files.items(): z.writestr(n, t)
    return bio.getvalue()

LOREM = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. "
def para(n): return (LOREM * n).strip() + "\n"

# the folders of a new account
for f in ("Desktop", "Documents", "Downloads", "Movies", "Music", "Pictures", "Public", "Library/Preferences"):
    d(f)

# the Desktop
w("Desktop/Welcome.txt", "Welcome to macbsd.\n\nThis is a demo account: the Dock, the menu bar, the Finder, the Terminal and UITest are running.\nTry the Finder (Dock), double-click Sample Files, drag icons between the Desktop and a Finder window,\nright-click an item for its menu (tags, Get Info, Quick Look: Space), View > as List / Columns / Gallery.\n", 1)
w("Desktop/Notes.txt", para(6) + "\n- buy milk\n- call the dentist\n- review the report\n", 2)
w("Desktop/Report.pdf", pdf("Quarterly report - demo"), 3)
w("Desktop/photo.png", png(320, 200, gradient((30, 90, 200), (240, 150, 60))), 4)
w("Desktop/budget.csv", "month,income,expenses\n" + "\n".join("%s,%d,%d" % (m, random.randint(2000, 3500), random.randint(1200, 2800)) for m in "Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec".split()) + "\n", 5)
w("Desktop/script.sh", "#!/bin/sh\necho 'hello from a script on the Desktop'\nuname -a\n", 6)
w("Desktop/Archive.zip", zipbytes({"readme.txt": "an archive\n", "data/one.txt": para(2), "data/two.txt": para(3)}), 8)
for f in ("Projects/web-site", "Projects/notes", "Photos", "Documents Archive"):
    d("Desktop/" + f)
w("Desktop/Projects/web-site/index.html", "<!doctype html><title>demo</title><h1>demo site</h1><p>" + LOREM + "</p>\n", 9)
w("Desktop/Projects/web-site/style.css", "body { font-family: sans-serif; margin: 2em; }\nh1 { color: #0a84ff; }\n", 9)
w("Desktop/Projects/notes/ideas.md", "# Ideas\n\n- a window server\n- a desktop\n- a dock\n", 10)
w("Desktop/Photos/sunrise.png", png(240, 160, gradient((250, 180, 80), (90, 60, 160))), 11)
w("Desktop/Photos/forest.png", png(240, 160, gradient((20, 90, 40), (180, 220, 120))), 12)
w("Desktop/Photos/ocean.png", png(240, 160, gradient((10, 40, 120), (120, 200, 230))), 13)
w("Desktop/Documents Archive/old-report.pdf", pdf("An older report"), 40)
w("Desktop/Documents Archive/letter.txt", para(4), 41)

# one folder with a lot of mixed files and folders
S = "Sample Files"
exts = [("txt", lambda i: para(1 + i % 5)), ("md", lambda i: "# Document %d\n\n%s" % (i, para(2))), ("json", lambda i: json.dumps({"id": i, "name": "item-%d" % i, "tags": ["a", "b", "c"][: 1 + i % 3]}, indent=2) + "\n"),
        ("csv", lambda i: "a,b,c\n" + "\n".join("%d,%d,%d" % (i, i * 2, i * 3) for _ in range(5)) + "\n"), ("c", lambda i: "#include <stdio.h>\nint main(void) { printf(\"%d\\n\", " + str(i) + "); return 0; }\n"),
        ("py", lambda i: "print(%d * 2)\n" % i), ("html", lambda i: "<p>page %d</p>\n" % i), ("sh", lambda i: "#!/bin/sh\necho %d\n" % i), ("log", lambda i: "\n".join("2026-10-28 12:%02d:%02d event %d" % (i % 60, j, j) for j in range(12)) + "\n"), ("pdf", None), ("png", None), ("zip", None)]
names = "alpha bravo charlie delta echo foxtrot golf hotel india juliet kilo lima mike november oscar papa quebec romeo sierra tango uniform victor whiskey xray yankee zulu".split()
for i, n in enumerate(names):
    ext, gen = exts[i % len(exts)]
    path = "%s/%s-%02d.%s" % (S, n, i, ext)
    if ext == "pdf": w(path, pdf("Document %s" % n), 1 + i)
    elif ext == "png": w(path, png(96, 64, gradient((i * 9 % 256, 80, 200 - i * 5 % 150), (240, i * 7 % 256, 60))), 1 + i)
    elif ext == "zip": w(path, zipbytes({"a.txt": para(1), "b.txt": para(2)}), 1 + i)
    else: w(path, gen(i), 1 + i)
for i in range(1, 25):
    w("%s/IMG_%04d.png" % (S, 1000 + i), png(64, 48, gradient((i * 10 % 256, 100, 255 - i * 8 % 200), (50, i * 11 % 256, 150))), 20 + i)
for i in range(1, 15):
    w("%s/Untitled %d.txt" % (S, i), para(1), 30 + i)
w("%s/README.txt" % S, "A folder with many mixed files and folders for trying the Finder: sorting, grouping, the views, searching, tags, drag and drop.\n", 1)
for folder, files in {"Music": ["track-%d.txt" % i for i in range(1, 9)], "Movies": ["clip-%d.txt" % i for i in range(1, 5)], "Pictures": ["wall-%d.png" % i for i in range(1, 7)],
                      "Documents": ["contract.pdf", "invoice.pdf", "cv.pdf", "notes.txt", "todo.md"], "Source": ["main.c", "util.c", "util.h", "Makefile", "build.sh", "app.py"], "Archive": ["2023.zip", "2024.zip", "backup.zip"],
                      "Misc": ["one.txt", "two.txt", "three.json"], "Projects/alpha": ["spec.md", "plan.txt"], "Projects/beta": ["spec.md", "data.csv"], "Projects/beta/docs": ["manual.pdf", "faq.txt"], "Empty Folder": []}.items():
    d("%s/%s" % (S, folder))
    for j, f in enumerate(files):
        p = "%s/%s/%s" % (S, folder, f)
        if f.endswith(".png"): w(p, png(80, 60, gradient((j * 40 % 256, 120, 220), (230, j * 30 % 256, 90))), 50 + j)
        elif f.endswith(".pdf"): w(p, pdf(f), 50 + j)
        elif f.endswith(".zip"): w(p, zipbytes({"x.txt": para(1)}), 50 + j)
        elif f.endswith(".json"): w(p, '{"demo": true}\n', 50 + j)
        elif f.endswith(".csv"): w(p, "a,b\n1,2\n3,4\n", 50 + j)
        elif f.endswith(".c") or f.endswith(".h"): w(p, "/* %s */\n" % f, 50 + j)
        elif f == "Makefile": w(p, "all:\n\t@echo demo\n", 50 + j)
        else: w(p, para(1), 50 + j)
d("%s/Folder %s" % (S, "with a very long name that does not fit under its icon on the Desktop or in the Finder"))
for i in range(1, 7): d("%s/Folder %d" % (S, i))
print("demo content:", sum(len(fs) for _, _, fs in os.walk(out)), "files in", out)
