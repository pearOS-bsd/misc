#!/bin/sh
# builds an unmodified Xcode project on FreeBSD with xcb + the compat layer (sdk/): sh ci/build-app.sh <project.xcodeproj> <target> <out dir> [more xcb arguments]
# needs GNUstep (gui, base), libs-opal and corebase installed (ci/gnustep-setup.sh, ci/opal-build.sh) and the compat layer built (sdk/build-compat.sh)
. /usr/local/GNUstep/System/Library/Makefiles/GNUstep.sh
WS="$(cd "$(dirname "$0")/.." && pwd)"
PROJ="$1"; TARGET="$2"; OUT="$3"; shift 3
COMPAT="${COMPAT:-/root/compat}"; CFWRAP="${CFWRAP:-/root/cfwrap}"
sh "$WS/sdk/gen-cf-wrappers.sh" "$CFWRAP" >/dev/null
[ -f "$COMPAT/libwsbsdcompat.so" ] || sh "$WS/sdk/build-compat.sh" "$COMPAT"
GSL="$(gnustep-config --gui-libs)"
XF="-fmodule-map-file=$WS/sdk/modules/module.modulemap -I$WS/sdk/modules -I$CFWRAP -I$WS/quartzcore/include -I$WS/sdk/include -isystem /usr/local/include/tcl8.6 -include $WS/sdk/include/wsbsd/prelude.h $(gnustep-config --objc-flags) -w -Wno-error=incompatible-function-pointer-types -Wno-error=int-conversion -Wno-error=implicit-function-declaration -fobjc-weak"
python3 "$WS/tools/xcb/xcb.py" "$PROJ" build "$TARGET" --out "$OUT" --cc clang --cflags "$XF" \
  --fw-map "Cocoa=$GSL;Tcl=-L/usr/local/lib -ltcl86" --ldflags "$GSL -L$COMPAT -lwsbsdcompat -lQuartzCore -lopal -lgnustep-corebase -ldispatch -lz" --bundle-libs "$COMPAT/libwsbsdcompat.so,$COMPAT/libQuartzCore.so" -j 4 "$@" 2>&1 | cut -c1-${XCB_COLS:-220}
