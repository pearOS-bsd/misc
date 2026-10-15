#!/bin/sh
# Starts wsd (-t) and runs one client test binary against it:  sh test/run_one.sh test_props
set -e
cd "$(dirname "$0")/.."
SOCK="${TMPDIR:-/tmp}/wsd-one.$$.sock"
export WS_SOCKET="$SOCK"
./wsd -t $WSD_FLAGS -g 640x480 >/dev/null 2>&1 &
WSD=$!
trap 'kill $WSD 2>/dev/null || true; rm -f "$SOCK"' EXIT
i=0; while [ ! -S "$SOCK" ] && [ $i -lt 50 ]; do i=$((i+1)); sleep 0.1; done
rc=0; "./$1" || rc=$?
exit $rc
