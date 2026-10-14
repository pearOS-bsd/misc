#!/bin/sh
# Starts wsd and compares its replies with the recorded real-WindowServer replies.
set -e
cd "$(dirname "$0")/.."
SOCK="${TMPDIR:-/tmp}/wsd-golden.$$.sock"
export WS_SOCKET="$SOCK"
./wsd -t -g 640x480 >/dev/null 2>&1 &
WSD=$!
trap 'kill $WSD 2>/dev/null || true; rm -f "$SOCK"' EXIT
i=0; while [ ! -S "$SOCK" ] && [ $i -lt 50 ]; do i=$((i+1)); sleep 0.1; done
./test_golden "$@"
