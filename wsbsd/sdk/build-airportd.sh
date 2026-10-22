#!/bin/sh
# airportd as on the Mac: sh sdk/build-airportd.sh OUTDIR   -> OUTDIR/usr/libexec/airportd and OUTDIR/System/Library/LaunchDaemons/com.apple.airportd.plist
# (build-corewlan.sh first: airportd links CoreWLAN/CoreWiFi from the same OUTDIR for the XPC protocol definitions)
OUT="${1:?output directory}"; D="$(cd "$(dirname "$0")" && pwd)"; A="$D/../airportd"
CWF="$OUT/System/Library/PrivateFrameworks/CoreWiFi.framework/Versions/A"; CWL="$OUT/System/Library/Frameworks/CoreWLAN.framework/Versions/A"
mkdir -p "$OUT/usr/libexec" "$OUT/System/Library/LaunchDaemons"
clang -x objective-c -fblocks -fobjc-arc -w -I"$D/include" -I"$A" -I/usr/local/include $(gnustep-config --objc-flags) "$A/main.m" "$A/WSAirportService.m" "$A/WSWiFiSimBackend.m" "$A/WSWiFiWpaBackend.m" "$A/WSIEParser.m" "$D/src/XPC.m" \
  -o "$OUT/usr/libexec/airportd" $(gnustep-config --base-libs) -L"$CWL" -L"$CWF" -l:CoreWLAN -l:CoreWiFi -Wl,-rpath,"/System/Library/Frameworks/CoreWLAN.framework/Versions/A" -Wl,-rpath,"/System/Library/PrivateFrameworks/CoreWiFi.framework/Versions/A" -L/usr/local/lib -lffi -ldispatch 2>&1 | grep -E "error|undefined" | head
cp "$A/mirror/System/Library/LaunchDaemons/com.apple.airportd.plist" "$OUT/System/Library/LaunchDaemons/"
ls -l "$OUT/usr/libexec/airportd" | awk '{print "built", $9, $5, "bytes"}'
