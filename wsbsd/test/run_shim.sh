#!/bin/sh
# Runs the shim test program against wsd and compares its output line by line with the output of the real SkyLight (docs/golden/shim_basic.txt).
set -e
cd "$(dirname "$0")/.."
SOCK="${TMPDIR:-/tmp}/wsd-shim.$$.sock"
export WS_SOCKET="$SOCK"
./wsd -t -g 640x480 >/dev/null 2>&1 &
WSD=$!
trap 'kill $WSD 2>/dev/null || true; rm -f "$SOCK" "$SOCK.out"' EXIT
i=0; while [ ! -S "$SOCK" ] && [ $i -lt 50 ]; do i=$((i+1)); sleep 0.1; done
./test_shim > "$SOCK.out"
if [ -f docs/golden/shim_basic.txt ]; then
  if diff -u docs/golden/shim_basic.txt "$SOCK.out"; then echo "shim: output identical to the real SkyLight"; else echo "shim: DIFFERS from the real SkyLight"; exit 1; fi
else cat "$SOCK.out"; echo "shim: no golden file yet"; fi
