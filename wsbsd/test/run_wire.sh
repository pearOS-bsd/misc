#!/bin/sh
# Starts wsd on a private socket and runs the protocol conformance test against it.
set -e
cd "$(dirname "$0")/.."
SOCK="${TMPDIR:-/tmp}/wsd-wire.$$.sock"
export WS_SOCKET="$SOCK"
./wsd -t -g 640x480 2>/dev/null &
WSD=$!
trap 'kill $WSD 2>/dev/null || true; rm -f "$SOCK"' EXIT
i=0; while [ ! -S "$SOCK" ] && [ $i -lt 50 ]; do i=$((i+1)); sleep 0.1; done
./test_wire
wait $WSD 2>/dev/null || true
