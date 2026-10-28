#!/bin/sh
# Builds defaults (GNUstep base): sh defaults/build.sh OUTDIR   -> OUTDIR/defaults
OUT="${1:?output directory}"; D="$(cd "$(dirname "$0")" && pwd)"; mkdir -p "$OUT"
. /usr/local/GNUstep/System/Library/Makefiles/GNUstep.sh
clang -x objective-c -fblocks -w -fobjc-arc $(gnustep-config --objc-flags) "$D/defaults.m" -o "$OUT/defaults" $(gnustep-config --base-libs) 2>&1 | grep -E "error|undefined" | head
ls -l "$OUT/defaults" 2>&1 | awk '{print "built", $9, $5, "bytes"}'
