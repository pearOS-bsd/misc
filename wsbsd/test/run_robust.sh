#!/bin/sh
# Starts wsd (-t), runs the robustness/fuzz test, then checks that wsd is still alive and quits on request.
set -e
cd "$(dirname "$0")/.."
SOCK="${TMPDIR:-/tmp}/wsd-robust.$$.sock"
export WS_SOCKET="$SOCK"
# shellcheck disable=SC2086
./wsd -t -g 640x480 ${WSD_ARGS:-} >/dev/null 2>&1 &
WSD=$!
trap 'kill $WSD 2>/dev/null || true; rm -f "$SOCK"' EXIT
i=0; while [ ! -S "$SOCK" ] && [ $i -lt 50 ]; do i=$((i+1)); sleep 0.1; done
rc=0
./test_robust || rc=$?
kill -0 $WSD 2>/dev/null || { echo "FAIL: wsd died"; rc=1; }
exit $rc
