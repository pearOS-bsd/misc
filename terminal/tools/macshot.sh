#!/bin/sh
# Renders the Terminal app with Apple's AppKit for the parity check: tools/macshot.sh OUTDIR -> OUTDIR/terminal.png (window without shadow)
# Same fixed session on both systems: sh, prompt "$ ", "echo hello" and a colour line.
OUT=${1:-refs/mac}; mkdir -p "$OUT"; make mac >/dev/null 2>&1
APP=$(mktemp -d)/term.app; mkdir -p "$APP/Contents/MacOS"; cp Terminal-mac "$APP/Contents/MacOS/term"
cat > "$APP/Contents/Info.plist" <<'PL'
<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>CFBundleExecutable</key><string>term</string><key>CFBundleIdentifier</key><string>test.term</string><key>CFBundlePackageType</key><string>APPL</string><key>CFBundleName</key><string>term</string></dict></plist>
PL
cat > "$APP/winid.swift" <<'SW'
import CoreGraphics
import Foundation
let l = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String: Any]]
var best = 0; var id = 0
for w in l where (w[kCGWindowOwnerName as String] as? String) == "term" { let b = w[kCGWindowBounds as String] as! [String: Any]; let a = Int((b["Width"] as! Double) * (b["Height"] as! Double)); if a > best { best = a; id = w[kCGWindowNumber as String] as! Int } }
print(id)
SW
INPUT="PS1='\$ '; clear; echo hello from the shell; printf '\\033[1;31mred\\033[0m \\033[38;5;33mblue\\033[0m\\n'"
open -n "$APP" --env SHELL=/bin/sh --env TERMINAL_COLS=80 --env TERMINAL_ROWS=24 --env TERMINAL_EXIT_AFTER=10 --env "TERMINAL_INITIAL_INPUT=$INPUT
"
sleep 4; ID=$(swift "$APP/winid.swift"); screencapture -x -o -l "$ID" "$OUT/terminal.png"
pkill -f "$APP/Contents/MacOS/term"; ls "$OUT"
