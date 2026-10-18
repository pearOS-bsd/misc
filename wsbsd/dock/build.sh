#!/bin/sh
# Builds Dock (GNUstep + Opal): sh dock/build.sh OUTDIR   -> OUTDIR/Dock
OUT="${1:?output directory}"; D="$(cd "$(dirname "$0")" && pwd)"; mkdir -p "$OUT"
. /usr/local/GNUstep/System/Library/Makefiles/GNUstep.sh
QC="$D/../quartzcore"
clang -x objective-c -fblocks -w -fobjc-arc -I"$QC/include" -I"$D/../sdk/include" -I"$D" $(gnustep-config --objc-flags) "$D/Dock.m" "$D/DockRender.m" -x c "$D/dock_layout.c" "$D/genie.c" -o "$OUT/Dock" \
	-L"${COMPAT:-/root/compat}" -lwsbsdcompat -lQuartzCore -Wl,-rpath,"${COMPAT:-/root/compat}" $(gnustep-config --gui-libs) -lopal -lgnustep-corebase -ldispatch -lm 2>&1 | grep -E "error|undefined" | head
ls -l "$OUT/Dock" 2>&1 | awk '{print "built", $9, $5, "bytes"}'
