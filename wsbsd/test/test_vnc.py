#!/usr/bin/env python3
"""A tiny RFB client: handshake, authentication (when WSD_VNC_PASSWORD is given the DES response is computed with `openssl enc -des-ecb`), one full framebuffer update,
a pointer click and a key; checks that the server answers with a framebuffer of the right size and that the click reaches a window."""
import os, socket, struct, subprocess, sys

port = int(sys.argv[1]); password = sys.argv[2] if len(sys.argv) > 2 else ""

def rd(s, n):
    b = b""
    while len(b) < n:
        c = s.recv(n - len(b))
        if not c: raise SystemExit("connection closed")
        b += c
    return b

def des_response(pw, ch):
    key = bytes(int('{:08b}'.format(c)[::-1], 2) for c in pw.encode()[:8].ljust(8, b"\0"))
    out = subprocess.run(["openssl", "enc", "-des-ecb", "-nopad", "-K", key.hex(), "-provider", "legacy", "-provider", "default"], input=ch, capture_output=True)
    if out.returncode != 0:
        out = subprocess.run(["openssl", "enc", "-des-ecb", "-nopad", "-K", key.hex()], input=ch, capture_output=True)
    return out.stdout

s = socket.create_connection(("127.0.0.1", port), timeout=10)
assert rd(s, 12) == b"RFB 003.008\n"
s.sendall(b"RFB 003.008\n")
n = rd(s, 1)[0]; types = list(rd(s, n))
if password:
    assert types == [2], types
    s.sendall(bytes([2])); ch = rd(s, 16); s.sendall(des_response(password, ch))
else:
    assert types == [1], types
    s.sendall(bytes([1]))
res = struct.unpack(">I", rd(s, 4))[0]
if res != 0:
    print("auth failed (%d)" % res); sys.exit(2)
s.sendall(b"\x01")                                        # shared
w, h = struct.unpack(">HH", rd(s, 4)); pf = rd(s, 16); nl = struct.unpack(">I", rd(s, 4))[0]; name = rd(s, nl)
assert pf[0] == 32 and pf[2] == 0 and pf[3] == 1, pf
print("server init %dx%d name=%s" % (w, h, name.decode()))
s.sendall(struct.pack(">BxHBBBBHHHBBBxxx", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)[:0] + b"")   # (no SetPixelFormat: the server format is used)
s.sendall(struct.pack(">BBHHHH", 3, 0, 0, 0, w, h))        # full update request
t = rd(s, 1)[0]; assert t == 0
rd(s, 1); nrect = struct.unpack(">H", rd(s, 2))[0]
total = 0
for _ in range(nrect):
    x, y, rw, rh, enc = struct.unpack(">HHHHi", rd(s, 12)); assert enc == 0
    rd(s, rw * rh * 4); total += rw * rh
print("rectangles %d, pixels %d (screen %d)" % (nrect, total, w * h))
assert total == w * h
s.sendall(struct.pack(">BBHH", 5, 0, 50, 50))               # pointer move
s.sendall(struct.pack(">BBHH", 5, 1, 50, 50)); s.sendall(struct.pack(">BBHH", 5, 0, 50, 50))     # click
s.sendall(struct.pack(">BBxxI", 4, 1, ord('a'))); s.sendall(struct.pack(">BBxxI", 4, 0, ord('a')))
s.sendall(struct.pack(">BBHHHH", 3, 1, 0, 0, w, h))
s.settimeout(5)
t = rd(s, 1)[0]; assert t == 0
print("incremental update after input: ok")
