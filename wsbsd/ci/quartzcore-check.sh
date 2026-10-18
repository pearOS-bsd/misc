#!/bin/sh
# Core Animation on FreeBSD: builds libQuartzCore against GNUstep Opal and runs the tests that compare it with the values recorded from Apple's QuartzCore (quartzcore/test/ref).
export IGNORE_OSVERSION=yes
WS="${GITHUB_WORKSPACE:-$(cd "$(dirname "$0")/../.." && pwd)}/wsbsd"
[ -d "$WS" ] || WS="$(cd "$(dirname "$0")/.." && pwd)"
pkg install -y python3 >/dev/null 2>&1
sh "$WS/ci/opal-libs.sh" >/tmp/opal-libs.log 2>&1; tail -3 /tmp/opal-libs.log
. /usr/local/GNUstep/System/Library/Makefiles/GNUstep.sh
cd "$WS/quartzcore" || exit 1
gmake -j2 2>&1 | grep -E "error|Error" | head
gmake check-ref 2>&1 | grep -E "lines compared|differences|Uncaught|FAIL|Error" 
# the compositor: a frame of every scene rendered without a display (timings are in the log)
gmake bench 2>&1 | tail -20
