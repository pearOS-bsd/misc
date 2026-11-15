#!/bin/sh
# Builds the Open and Save Panel Service (GNUstep + Opal) as a bundle laid out like Apple's:
#   sh appkit/xpcservices/build.sh OUTDIR  ->  OUTDIR/com.apple.appkit.xpc.openAndSavePanelService.xpc/Contents/{Info.plist,MacOS/com.apple.appkit.xpc.openAndSavePanelService}
# It belongs in /System/Library/Frameworks/AppKit.framework/Versions/C/XPCServices/ (where the Mac has it).
OUT="${1:?output directory}"; D="$(cd "$(dirname "$0")" && pwd)"; B="$OUT/com.apple.appkit.xpc.openAndSavePanelService.xpc"
mkdir -p "$B/Contents/MacOS"; cp "$D/com.apple.appkit.xpc.openAndSavePanelService.xpc/Contents/Info.plist" "$B/Contents/"
. /usr/local/GNUstep/System/Library/Makefiles/GNUstep.sh
clang -x objective-c -fblocks -w -fobjc-arc -I"$D/../../include" $(gnustep-config --objc-flags) "$D/main.m" -L"${COMPAT:-/root/compat}" -lwsbsdcompat -Wl,-rpath,"${COMPAT:-/root/compat}" $(gnustep-config --gui-libs) -lopal -lgnustep-corebase -ldispatch -lm \
	-o "$B/Contents/MacOS/com.apple.appkit.xpc.openAndSavePanelService" 2>&1 | grep -E "error|undefined" | head
ls -l "$B/Contents/MacOS/com.apple.appkit.xpc.openAndSavePanelService" 2>&1 | awk '{print "built", $9, $5, "bytes"}'
