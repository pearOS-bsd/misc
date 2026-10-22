#!/bin/sh
# Builds the Finder as it sits on the Mac: sh finder/build.sh OUTDIR  ->  OUTDIR/System/Library/CoreServices/Finder.app/Contents/{MacOS/Finder,Info.plist,Resources}
OUT="${1:?output directory}"; D="$(cd "$(dirname "$0")" && pwd)"; Q="$D/../quartzcore/include"
APP="$OUT/System/Library/CoreServices/Finder.app/Contents"; mkdir -p "$APP/MacOS" "$APP/Resources" "$OUT/obj"
F="-fobjc-arc -fblocks -w -ferror-limit=0 -I$Q -I$D/../sdk/include -I$D/src $(gnustep-config --objc-flags)"
for f in "$D"/src/*.mm; do b=$(basename "$f" .mm); clang++ -x objective-c++ $F -c "$f" -o "$OUT/obj/finder_$b.o" 2>&1 | grep -E "error" | head -5; done
clang++ -o "$APP/MacOS/Finder" "$OUT"/obj/finder_*.o $(gnustep-config --gui-libs) -L"${COMPAT:-/usr/local/lib}" -lwsbsdcompat -lQuartzCore -lopal -lgnustep-corebase -ldispatch -lffi -Wl,-rpath,"${COMPAT:-/usr/local/lib}" 2>&1 | head -5
cp "$D/Info.plist" "$APP/Info.plist"; [ -d "$D/Resources" ] && cp -R "$D/Resources/." "$APP/Resources/" 2>/dev/null
ls -l "$APP/MacOS/Finder" | awk '{print "built", $9, $5, "bytes"}'
