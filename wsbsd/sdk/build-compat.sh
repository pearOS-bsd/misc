#!/bin/sh
# Builds libwsbsdcompat (sdk/src/AppKitCompat.m) with the GNUstep flags: sh sdk/build-compat.sh OUTDIR
OUT="${1:?output directory}"; D="$(cd "$(dirname "$0")" && pwd)"; mkdir -p "$OUT"
clang -shared -fPIC -fobjc-arc -fblocks -w -I"$D/include" $(gnustep-config --objc-flags) "$D/src/AppKitCompat.m" -o "$OUT/libwsbsdcompat.so" $(gnustep-config --gui-libs) 2>&1 | grep -E "error" | head
ls -l "$OUT/libwsbsdcompat.so" | awk '{print "built", $9, $5, "bytes"}'
