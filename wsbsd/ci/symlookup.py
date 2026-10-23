"""symlookup.py LIB OFFSET: the symbol of LIB (nm -n, local ones too) that contains the offset (hex)"""
import subprocess, sys
lib, off = sys.argv[1], int(sys.argv[2], 16); last = ""
for l in subprocess.run(["nm", "-n", lib], capture_output=True, text=True).stdout.splitlines():
    p = l.split()
    if len(p) >= 3 and all(c in "0123456789abcdefABCDEF" for c in p[0]):
        if int(p[0], 16) <= off: last = l.strip()
        else: break
print(last or "no symbol")
