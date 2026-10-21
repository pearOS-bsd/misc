#!/bin/sh
# The macOS bundle of TextMate (Contents/MacOS, Contents/Resources ...) as a bundle GNUstep's NSBundle accepts as the main bundle: Name.app/Name (the executable) and Name.app/Resources
# (Info.plist, resources) at the top, Contents kept whole beside them for the code that builds paths with /Contents/. usage: sh ports/textmate/assemble.sh [build dir] [out dir]
SRC="${1:-/root/build/tm/release/Applications/TextMate/TextMate.app}"; OUT="${2:-/root/oss/outtm}/TextMate.app"
rm -rf "$OUT"; mkdir -p "$OUT"; cp -R "$SRC/Contents" "$OUT/Contents"
cp "$SRC/Contents/MacOS/TextMate" "$OUT/TextMate"
for d in Resources PlugIns SharedSupport; do [ -e "$OUT/Contents/$d" ] && ln -s "Contents/$d" "$OUT/$d"; done
cp "$OUT/Contents/Info.plist" "$OUT/Contents/Resources/Info-gnustep.plist"
# nibs: ibtool's shim copied the XML xib under the name .nib; GNUstep reads Apple's binary nibs from .nib and XML interface files from .xib
find "$OUT/Contents/Resources" -name '*.nib' -type f | while read -r f; do mv "$f" "${f%.nib}.xib"; done
echo "assembled $OUT"
