#!/bin/sh
# Builds loginwindow (GNUstep + Opal): sh loginwindow/build.sh OUTDIR   -> OUTDIR/loginwindow
OUT="${1:?output directory}"; D="$(cd "$(dirname "$0")" && pwd)"; mkdir -p "$OUT"
. /usr/local/GNUstep/System/Library/Makefiles/GNUstep.sh
clang -x objective-c -fblocks -w -fobjc-arc -I"$D/../quartzcore/include" -I"$D/../include" -I"$D/../sdk/include" $(gnustep-config --objc-flags) "$D/LoginWindow.m" -x none -o "$OUT/loginwindow" \
	-L"${COMPAT:-/root/compat}" -lwsbsdcompat -lQuartzCore -Wl,-rpath,"${COMPAT:-/root/compat}" $(gnustep-config --gui-libs) -lopal -lgnustep-corebase -ldispatch -lcrypt -lm 2>&1 | grep -E "error|undefined" | head
ls -l "$OUT/loginwindow" 2>&1 | awk '{print "built", $9, $5, "bytes"}'
