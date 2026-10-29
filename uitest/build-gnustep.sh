#!/bin/sh
# UITest on GNUstep: sh build-gnustep.sh [WS] [COMPAT]  (called by `make gnustep`, which runs with BSD make or GNU make)
# With WS (the wsbsd tree) and no COMPAT the notification sender is built in: the SDK's UserNotifications.m and XPC.m are compiled into the app
# (linking the whole compat library crashes the gallery at start). With COMPAT: the Touch Bar build as before.
WS="$1"; COMPAT="$2"; cd "$(dirname "$0")" || exit 1
if [ -n "$WS" ] && [ -z "$COMPAT" ]; then
  mkdir -p obj
  FL="-fblocks -w -I$WS/sdk/include -I/usr/local/include $(gnustep-config --objc-flags)"
  cc -x objective-c -fobjc-arc $FL -c "$WS/sdk/src/UserNotifications.m" -o obj/un.o || exit 1
  cc -x objective-c -fobjc-arc $FL -c "$WS/sdk/src/XPC.m" -o obj/xpc.o || exit 1
  cc -x objective-c $FL -c src/main.m -o obj/main.o || exit 1
  exec cc -o UITest-gnustep obj/main.o obj/un.o obj/xpc.o $(gnustep-config --gui-libs) -L/usr/local/lib -ldispatch -lffi
elif [ -n "$COMPAT" ]; then
  exec cc -o UITest-gnustep src/main.m $(gnustep-config --objc-flags) $(gnustep-config --gui-libs) -DUI_TB_BUILD -fblocks -I"$WS"/sdk/include -L"$COMPAT" -lwsbsdcompat -Wl,-rpath,"$COMPAT"
else
  exec cc -o UITest-gnustep src/main.m $(gnustep-config --objc-flags) $(gnustep-config --gui-libs)
fi
