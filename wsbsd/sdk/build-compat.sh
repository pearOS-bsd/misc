#!/bin/sh
# Builds libwsbsdcompat with the GNUstep flags: sh sdk/build-compat.sh OUTDIR
# The ARC sources (AppKit / Foundation additions, FSEvents polling, the C shims) and the string constants (no ARC, see Constants.m) are compiled apart and linked together.
OUT="${1:?output directory}"; D="$(cd "$(dirname "$0")" && pwd)"; mkdir -p "$OUT"
F="-fPIC -fblocks -w -I$D/include $(gnustep-config --objc-flags)"
clang $F -fobjc-arc -c "$D/src/AppKitCompat.m" -o "$OUT/AppKitCompat.o" 2>&1 | grep -E "error" | head
clang $F -fobjc-arc -c "$D/src/FSEvents.m" -o "$OUT/FSEvents.o" 2>&1 | grep -E "error" | head
for c in xattr DiskArb UTType FileManager Security; do clang $F -c "$D/src/$c.c" -o "$OUT/$c.o" 2>&1 | grep -E "error" | head; done
clang $F $(pkg-config --cflags cairo fontconfig freetype2) -c "$D/src/CoreTextFixes.c" -o "$OUT/CoreTextFixes.o" 2>&1 | grep -E "error" | head
clang $F -fno-objc-arc -c "$D/src/Constants.m" -o "$OUT/Constants.o" 2>&1 | grep -E "error" | head
clang -shared -o "$OUT/libwsbsdcompat.so" "$OUT"/*.o $(gnustep-config --gui-libs) -lopal -lgnustep-corebase $(pkg-config --libs cairo fontconfig freetype2) 2>&1 | grep -E "error|undefined" | head
ls -l "$OUT/libwsbsdcompat.so" | awk '{print "built", $9, $5, "bytes"}'
