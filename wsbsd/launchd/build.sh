#!/bin/sh
# launchd: sh launchd/build.sh OUTDIR   -> OUTDIR/usr/libexec/launchd, OUTDIR/System/Library/LaunchAgents/*.plist
OUT="${1:?output directory}"; D="$(cd "$(dirname "$0")" && pwd)"
. /usr/local/GNUstep/System/Library/Makefiles/GNUstep.sh
mkdir -p "$OUT/usr/libexec" "$OUT/System/Library/LaunchAgents"
clang -x objective-c -fblocks -fobjc-arc -w $(gnustep-config --objc-flags) "$D/launchd.m" -o "$OUT/usr/libexec/launchd" $(gnustep-config --base-libs) || exit 1
cp "$D"/agents/*.plist "$OUT/System/Library/LaunchAgents/"
ls -l "$OUT/usr/libexec/launchd" | awk '{print "built", $9, $5, "bytes"}'
