#!/bin/sh
# Builds TextEdit (GNUstep + Opal): sh textedit/build.sh OUTDIR   -> OUTDIR/TextEdit
OUT="${1:?output directory}"; D="$(cd "$(dirname "$0")" && pwd)"; mkdir -p "$OUT"
. /usr/local/GNUstep/System/Library/Makefiles/GNUstep.sh
clang -x objective-c -fblocks -w -fobjc-arc -I"$D/src" $(gnustep-config --objc-flags) "$D/src/main.m" -x none -o "$OUT/TextEdit" \
	$(gnustep-config --gui-libs) -lopal -lgnustep-corebase -ldispatch -lm 2>&1 | grep -E "error|undefined" | head
ls -l "$OUT/TextEdit" 2>&1 | awk '{print "built", $9, $5, "bytes"}'
