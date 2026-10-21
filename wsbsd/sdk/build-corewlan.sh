#!/bin/sh
# Builds the Wi-Fi frameworks as libraries laid out as on the Mac: sh sdk/build-corewlan.sh OUTDIR   (then installed by the ISO builder under /System/Library/...)
#   OUTDIR/System/Library/PrivateFrameworks/CoreWiFi.framework/Versions/A/CoreWiFi
#   OUTDIR/System/Library/Frameworks/CoreWLAN.framework/Versions/A/CoreWLAN
OUT="${1:?output directory}"; D="$(cd "$(dirname "$0")" && pwd)"
F="-fPIC -fblocks -w -fno-objc-arc -I$D/include $(gnustep-config --objc-flags)"
CWF="$OUT/System/Library/PrivateFrameworks/CoreWiFi.framework/Versions/A"; CWL="$OUT/System/Library/Frameworks/CoreWLAN.framework/Versions/A"
mkdir -p "$CWF" "$CWL" "$OUT/obj"
for f in "$D"/src/CoreWiFi/*.m; do clang $F -c "$f" -o "$OUT/obj/wifi_$(basename "$f" .m).o" 2>&1 | grep -E "error" | head; done
clang -shared -o "$CWF/CoreWiFi" "$OUT"/obj/wifi_*.o $(gnustep-config --base-libs) 2>&1 | head -5
for f in "$D"/src/CoreWLAN/*.m; do clang $F -c "$f" -o "$OUT/obj/wlan_$(basename "$f" .m).o" 2>&1 | grep -E "error" | head; done
clang -shared -o "$CWL/CoreWLAN" "$OUT"/obj/wlan_*.o -L"$CWF" -l:CoreWiFi $(gnustep-config --base-libs) -Wl,-rpath,'$ORIGIN' 2>&1 | head -5
for d in "$OUT/System/Library/PrivateFrameworks/CoreWiFi.framework" "$OUT/System/Library/Frameworks/CoreWLAN.framework"; do n=$(basename "$d" .framework); ln -sfn A "$d/Versions/Current"; ln -sfn Versions/Current/$n "$d/$n"; done
ls -l "$CWF/CoreWiFi" "$CWL/CoreWLAN" | awk '{print "built", $9, $5, "bytes"}'
