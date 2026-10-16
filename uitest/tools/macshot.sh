#!/bin/sh
# Renders the gallery with Apple's AppKit: tools/macshot.sh OUTDIR  -> OUTDIR/gallery.png (window without shadow), OUTDIR/manifest.txt
OUT=${1:-refs/mac}; mkdir -p "$OUT"
UI_EXIT_AFTER=1 ./UITest-mac > "$OUT/manifest.txt" 2>/dev/null
APP=$(mktemp -d)/uitest.app; mkdir -p "$APP/Contents/MacOS"; cp UITest-mac "$APP/Contents/MacOS/uitest"
cat > "$APP/Contents/Info.plist" <<'PL'
<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>CFBundleExecutable</key><string>uitest</string><key>CFBundleIdentifier</key><string>test.uitest</string><key>CFBundlePackageType</key><string>APPL</string><key>CFBundleName</key><string>uitest</string></dict></plist>
PL
cat > "$APP/winid.swift" <<'SW'
import CoreGraphics
import Foundation
let l = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String: Any]]
var best = 0; var id = 0
for w in l where (w[kCGWindowOwnerName as String] as? String) == "uitest" { let b = w[kCGWindowBounds as String] as! [String: Any]; let a = Int((b["Width"] as! Double) * (b["Height"] as! Double)); if a > best { best = a; id = w[kCGWindowNumber as String] as! Int } }
print(id)
SW
open -n "$APP" --env UI_EXIT_AFTER=8
sleep 3; ID=$(swift "$APP/winid.swift"); screencapture -x -o -l "$ID" "$OUT/gallery.png"
pkill -f "$APP/Contents/MacOS/uitest"; ls "$OUT"
