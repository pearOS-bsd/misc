#!/bin/sh
# Renders every pane of the app with Apple's AppKit and writes window screenshots (screencapture -l): tools/macshots.sh OUTDIR
# The app runs as a bundle through `open` so that it becomes the active application (the traffic lights are coloured only then).
OUT=${1:-refs/mac}; mkdir -p "$OUT"
APP=$(mktemp -d)/ksa.app; mkdir -p "$APP/Contents/MacOS"; cp KeyboardSetupAssistant-mac "$APP/Contents/MacOS/ksa"
cat > "$APP/Contents/Info.plist" <<'PL'
<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>CFBundleExecutable</key><string>ksa</string><key>CFBundleIdentifier</key><string>test.ksa</string><key>CFBundlePackageType</key><string>APPL</string><key>CFBundleName</key><string>ksa</string></dict></plist>
PL
cat > "$APP/winid.swift" <<'SW'
import CoreGraphics
import Foundation
let l = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String: Any]]
var best = 0; var id = 0
for w in l where (w[kCGWindowOwnerName as String] as? String) == "ksa" { let b = w[kCGWindowBounds as String] as! [String: Any]; let a = Int((b["Width"] as! Double) * (b["Height"] as! Double)); if a > best { best = a; id = w[kCGWindowNumber as String] as! Int } }
print(id)
SW
for p in 0 1 2 3; do
  KSA_PANE=$p KSA_EXIT_AFTER=5 open -n "$APP" --env KSA_PANE=$p --env KSA_EXIT_AFTER=5 --env KSA_SCRIPT= >/dev/null 2>&1
  sleep 2.5
  ID=$(swift "$APP/winid.swift"); screencapture -x -l "$ID" "$OUT/pane$p.png"; screencapture -x -o -l "$ID" "$OUT/pane$p-noshadow.png"
  pkill -f "$APP/Contents/MacOS/ksa"; sleep 0.5
done
ls "$OUT"
