#!/bin/sh
# Renders a mode of the gallery (alert | menu) with Apple's AppKit and captures the largest window the app owns on top of the gallery: tools/macmode.sh MODE OUTDIR
MODE=$1; OUT=${2:-refs/mac}; mkdir -p "$OUT"
APP=$(mktemp -d)/uitest.app; mkdir -p "$APP/Contents/MacOS"; cp UITest-mac "$APP/Contents/MacOS/uitest"
cat > "$APP/Contents/Info.plist" <<'PL'
<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>CFBundleExecutable</key><string>uitest</string><key>CFBundleIdentifier</key><string>test.uitest</string><key>CFBundlePackageType</key><string>APPL</string><key>CFBundleName</key><string>uitest</string></dict></plist>
PL
cat > "$APP/winid.swift" <<'SW'
import CoreGraphics
import Foundation
let l = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String: Any]]
// the frontmost window of the app that is not the gallery (940 wide): the alert panel / the menu
for w in l where (w[kCGWindowOwnerName as String] as? String) == "uitest" { let b = w[kCGWindowBounds as String] as! [String: Any]; if (b["Width"] as! Double) != 940 && (b["Width"] as! Double) > 40 { print(w[kCGWindowNumber as String]!); break } }
SW
open -n "$APP" --env UI_EXIT_AFTER=10 --env UI_MODE=$MODE --env UI_APPEARANCE=${UI_APPEARANCE:-dark}
sleep 3.5; ID=$(swift "$APP/winid.swift"); echo "window $ID"; screencapture -x -o -l "$ID" "$OUT/$MODE.png"
pkill -f "$APP/Contents/MacOS/uitest"; ls "$OUT"
