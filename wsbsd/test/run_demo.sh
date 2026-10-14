#!/bin/sh
# Starts wsd on a private socket, runs the test window client, writes the screenshot (PPM, and PNG when a converter exists), stops wsd.
#   WSD_ARGS  extra wsd options, e.g. "-r gl"       OUT  output base name (default window)
set -e
cd "$(dirname "$0")/.."
OUT="${OUT:-window}"
SOCK="${TMPDIR:-/tmp}/wsd-demo.$$.sock"
export WS_SOCKET="$SOCK"
# shellcheck disable=SC2086
./wsd -t -g 1280x800 ${WSD_ARGS:-} &
WSD=$!
trap 'kill $WSD 2>/dev/null || true; rm -f "$SOCK"' EXIT
i=0; while [ ! -S "$SOCK" ] && [ $i -lt 50 ]; do i=$((i+1)); sleep 0.1; done
./test_window "$OUT.ppm" quit
wait $WSD 2>/dev/null || true
if command -v sips >/dev/null 2>&1; then sips -s format png "$OUT.ppm" --out "$OUT.png" >/dev/null 2>&1 || true
elif command -v python3 >/dev/null 2>&1; then python3 tools/ppm2png.py "$OUT.ppm" "$OUT.png" || true; fi
ls -l "$OUT.ppm"
