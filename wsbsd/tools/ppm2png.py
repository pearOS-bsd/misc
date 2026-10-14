#!/usr/bin/env python3
"""Converts the P6 PPM written by wsd (screenshots) to PNG using only the standard library."""
import struct, sys, zlib

def main(src, dst):
    data = open(src, "rb").read()
    parts, i = [], 0
    while len(parts) < 4:                       # P6 <w> <h> <maxval>, whitespace separated, no comments in our files
        while data[i:i + 1].isspace(): i += 1
        j = i
        while not data[j:j + 1].isspace(): j += 1
        parts.append(data[i:j]); i = j
    i += 1
    assert parts[0] == b"P6" and parts[3] == b"255", "unsupported PPM"
    w, h = int(parts[1]), int(parts[2])
    pix = data[i:i + w * h * 3]
    raw = b"".join(b"\x00" + pix[y * w * 3:(y + 1) * w * 3] for y in range(h))
    def chunk(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b"")
    open(dst, "wb").write(png)

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
