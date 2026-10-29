#!/bin/sh
# Builds TopBar (GNUstep + Opal): sh topbar/build.sh OUTDIR   -> OUTDIR/TopBar
OUT="${1:?output directory}"; D="$(cd "$(dirname "$0")" && pwd)"; mkdir -p "$OUT"
. /usr/local/GNUstep/System/Library/Makefiles/GNUstep.sh
clang -x objective-c -fblocks -w -fobjc-arc -I"$D/../quartzcore/include" -I"$D/../include" -I"$D/../sdk/include" $(gnustep-config --objc-flags) "$D/TopBar.m" "$D/ControlCenter.m" "$D/Spotlight.m" "$D/ForceQuit.m" "$D/Applications.m" "$D/StatusMenus.m" "$D/NotificationCenter.m" "$D/WifiPanel.m" -x none "${WSCLIENT:-$D/../libwsclient.a}" -o "$OUT/TopBar" \
	-L"${COMPAT:-/root/compat}" -lwsbsdcompat -lQuartzCore -Wl,-rpath,"${COMPAT:-/root/compat}" $(gnustep-config --gui-libs) -lopal -lgnustep-corebase -ldispatch -lm 2>&1 | grep -E "error|undefined" | head
ls -l "$OUT/TopBar" 2>&1 | awk '{print "built", $9, $5, "bytes"}'
