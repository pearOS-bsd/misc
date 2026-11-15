#!/bin/sh
# Builds AppKit.framework's binary (a Mach-O dylib) from appkit/decompiled/src plus the open backend (libwsclient): run on a Mac.
#   sh open/build-appkit.sh OUTDIR      (from the root of wsbsd)
set -e
OUT="${1:?output directory}"; R="$(cd "$(dirname "$0")/.." && pwd)"; mkdir -p "$OUT/o"
S="$R/appkit/decompiled/src"
for f in "$S"/*.m; do b=$(basename "$f" .m); [ "$b" = NSSliderAccessoryBehavior ] && continue
  grep -qx "$b" "$R/open/uifoundation-classes.txt" && continue		# these classes live in UIFoundation (the cache): the real ones are used
  cc -arch x86_64 -fobjc-arc -Wno-everything -I"$S" -I"$R/include" -c "$f" -o "$OUT/o/$b.o" || echo "FAILED $b"; done
cc -arch x86_64 -fobjc-arc -Wno-everything -I"$S" -c "$R/appkit/decompiled/test/stubs.m" -o "$OUT/o/stubs.o"
for c in client compositor_sw region ipc evrec buffer; do cc -arch x86_64 -Wno-everything -DWS_DARWIN_ON_BSD -I"$R/include" -c "$R/src/$c.c" -o "$OUT/o/ws_$c.o"; done
[ -f "$R/open/stubs-extra.m" ] && cc -arch x86_64 -fobjc-arc -Wno-everything -c "$R/open/stubs-extra.m" -o "$OUT/o/stubs_extra.o"
cc -arch x86_64 -dynamiclib -install_name /open/AppKit -Wl,-reexport_framework,Foundation -framework Foundation -framework CoreGraphics -framework CoreFoundation -F/System/Library/PrivateFrameworks -Wl,-reexport_framework,UIFoundation -Wl,-undefined,dynamic_lookup -o "$OUT/AppKit" "$OUT"/o/*.o
echo built "$OUT/AppKit"
# /open/Cocoa: the umbrella of our AppKit (apps that link Cocoa get ours + Foundation)
echo "" > "$OUT/empty.c"; cc -arch x86_64 -dynamiclib -install_name /open/Cocoa -Wl,-reexport_library,"$OUT/AppKit" -Wl,-reexport_framework,Foundation -o "$OUT/Cocoa" "$OUT/empty.c"
# stand-ins for libraries that would pull the real AppKit into the process (open-patch.py points the load commands here): one dylib per library, from open/stubs-lib-NAME.m
for f in "$R"/open/stubs-lib-*.m; do [ -f "$f" ] || continue; n=$(basename "$f" .m); n=${n#stubs-lib-}
  cc -arch x86_64 -fobjc-arc -Wno-everything -dynamiclib -install_name /open/stub-$n -framework Foundation -o "$OUT/stub-$n" "$f"; done
