#!/bin/sh
# usernoted and wsnotify: sh sdk/build-usernoted.sh OUTDIR [COMPAT]   -> OUTDIR/usr/libexec/usernoted, OUTDIR/usr/local/bin/wsnotify, OUTDIR/System/Library/LaunchDaemons/com.apple.usernoted.plist
# (wsnotify uses UserNotifications from libwsbsdcompat; the daemon carries XPC.m itself, as airportd does)
OUT="${1:?output directory}"; D="$(cd "$(dirname "$0")" && pwd)"; U="$D/../usernoted"; COMPAT="${2:-${COMPAT:-/root/compat}}"
. /usr/local/GNUstep/System/Library/Makefiles/GNUstep.sh
mkdir -p "$OUT/usr/libexec" "$OUT/usr/local/bin" "$OUT/System/Library/LaunchDaemons"
clang -x objective-c -fblocks -fobjc-arc -w -I"$D/include" -I"$U" -I/usr/local/include $(gnustep-config --objc-flags) "$U/main.m" "$U/WSUserNotificationService.m" "$D/src/XPC.m" -o "$OUT/usr/libexec/usernoted" $(gnustep-config --base-libs) -L/usr/local/lib -ldispatch -lffi 2>&1 | grep -E "error" | head
clang -x objective-c -fblocks -fobjc-arc -w -I"$D/include" $(gnustep-config --objc-flags) "$U/wsnotify.m" -o "$OUT/usr/local/bin/wsnotify" -L"$COMPAT" -lwsbsdcompat -Wl,-rpath,"$COMPAT" $(gnustep-config --base-libs) -L/usr/local/lib -ldispatch -lffi 2>&1 | grep -E "error" | head
cp "$U/com.apple.usernoted.plist" "$OUT/System/Library/LaunchDaemons/"
ls -l "$OUT/usr/libexec/usernoted" "$OUT/usr/local/bin/wsnotify" 2>&1 | awk '{print "built", $9, $5, "bytes"}'
