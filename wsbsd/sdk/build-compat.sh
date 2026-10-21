#!/bin/sh
# Builds libwsbsdcompat with the GNUstep flags: sh sdk/build-compat.sh OUTDIR
# The ARC sources (AppKit / Foundation additions, FSEvents polling, the C shims) and the string constants (no ARC, see Constants.m) are compiled apart and linked together.
OUT="${1:?output directory}"; D="$(cd "$(dirname "$0")" && pwd)"; mkdir -p "$OUT"
QC="$D/../quartzcore"
F="-fPIC -fblocks -w -I$QC/include -I$D/include $(gnustep-config --objc-flags)"
# Core Animation: libQuartzCore.so from quartzcore/ (the QuartzCore framework of this stack)
gmake -C "$QC" BUILD="$OUT/qc" "$OUT/qc/libQuartzCore.so" 2>&1 | grep -E "error|Error" | head; cp "$OUT/qc/libQuartzCore.so" "$OUT/libQuartzCore.so"
clang $F -fobjc-arc -c "$D/src/AppKitCompat.m" -o "$OUT/AppKitCompat.o" 2>&1 | grep -E "error" | head
clang $F -fobjc-arc -c "$D/src/AppKitAnimation.m" -o "$OUT/AppKitAnimation.o" 2>&1 | grep -E "error" | head
clang $F -fobjc-arc -c "$D/src/AppKitLayers.m" -o "$OUT/AppKitLayers.o" 2>&1 | grep -E "error" | head
clang $F -fobjc-arc -c "$D/src/FSEvents.m" -o "$OUT/FSEvents.o" 2>&1 | grep -E "error" | head
clang $F -fobjc-arc -c "$D/src/AppleEvents.m" -o "$OUT/AppleEvents.o" 2>&1 | grep -E "error" | head
clang $F -fobjc-arc -c "$D/src/AppKitCompat2.m" -o "$OUT/AppKitCompat2.o" 2>&1 | grep -E "error" | head
clang $F -fobjc-arc -c "$D/src/CFPlugIn.m" -o "$OUT/CFPlugIn.o" 2>&1 | grep -E "error" | head
clang $F -fobjc-arc -c "$D/src/Authorization.m" -o "$OUT/Authorization.o" 2>&1 | grep -E "error" | head
clang $F -fobjc-arc -c "$D/src/CGEvent.m" -o "$OUT/CGEvent.o" 2>&1 | grep -E "error" | head
clang $F -fobjc-arc -c "$D/src/RunningApplication.m" -o "$OUT/RunningApplication.o" 2>&1 | grep -E "error" | head
clang $F -fobjc-arc -c "$D/src/Misc3.m" -o "$OUT/Misc3.o" 2>&1 | grep -E "error" | head
clang $F -fobjc-arc -c "$D/src/UserNotifications.m" -o "$OUT/UserNotifications.o" 2>&1 | grep -E "error" | head
clang $F -fobjc-arc -c "$D/src/NSURLSession.m" -I/usr/local/include -o "$OUT/NSURLSession.o" 2>&1 | grep -E "error" | head
clang $F -fobjc-arc -c "$D/src/AppKitCompat3.m" -o "$OUT/AppKitCompat3.o" 2>&1 | grep -E "error" | head
clang $F -fobjc-arc -c "$D/src/AppleEventObjects.m" -o "$OUT/AppleEventObjects.o" 2>&1 | grep -E "error" | head
clang $F -fobjc-arc -c "$D/src/Keychain.m" -o "$OUT/Keychain.o" 2>&1 | grep -E "error" | head
clang $F -fobjc-arc -c "$D/src/QuickLook.m" -o "$OUT/QuickLook.o" 2>&1 | grep -E "error" | head
clang $F -fobjc-arc -c "$D/src/SystemFrameworks.m" -o "$OUT/SystemFrameworks.o" 2>&1 | grep -E "error" | head
clang $F -fobjc-arc -c "$D/src/Quarantine.m" -o "$OUT/Quarantine.o" 2>&1 | grep -E "error" | head
for c in Launch xattr DiskArb UTType FileManager Security CoreServicesMisc ProcCompat CopyFile SecurityConstants CFConstants; do clang $F -c "$D/src/$c.c" -o "$OUT/$c.o" 2>&1 | grep -E "error" | head; done
clang $F $(pkg-config --cflags cairo fontconfig freetype2) -c "$D/src/CoreTextFixes.c" -o "$OUT/CoreTextFixes.o" 2>&1 | grep -E "error" | head
clang $F -fno-objc-arc -c "$D/src/Constants.m" -o "$OUT/Constants.o" 2>&1 | grep -E "error" | head
clang -shared -o "$OUT/libwsbsdcompat.so" "$OUT"/*.o -L"$OUT" -lQuartzCore $(gnustep-config --gui-libs) -lopal -lgnustep-corebase -lcrypto -L/usr/local/lib -lcurl $(pkg-config --libs cairo fontconfig freetype2) 2>&1 | grep -E "error|undefined" | head
ls -l "$OUT/libQuartzCore.so" "$OUT/libwsbsdcompat.so" | awk '{print "built", $9, $5, "bytes"}'
