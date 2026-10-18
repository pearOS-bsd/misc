#!/bin/sh
# Runs the programs of sdk/tests against the compat layer (needs GNUstep gui/back, Opal and a running wsd: WS_SOCKET): sh ci/sdk-tests.sh
. /usr/local/GNUstep/System/Library/Makefiles/GNUstep.sh
WS="$(cd "$(dirname "$0")/.." && pwd)"; O=/tmp/sdk-compat; mkdir -p $O
# the CoreFoundation headers of corebase are reached through the wrappers the application builds use
sh "$WS/sdk/gen-cf-wrappers.sh" $O/cfwrap 2>&1 | tail -1
export CPATH="$O/cfwrap${CPATH:+:$CPATH}"
sh "$WS/sdk/build-compat.sh" $O 2>&1 | tail -4
GSL="$(gnustep-config --gui-libs)"
FAIL=0
for t in rep_draw anim_test layer_demo; do
	clang -x objective-c -fblocks -w -fobjc-arc -I$O/cfwrap -I"$WS/quartzcore/include" -I"$WS/sdk/include" -include "$WS/sdk/include/wsbsd/prelude.h" $(gnustep-config --objc-flags) "$WS/sdk/tests/$t.m" -o $O/$t \
		-L$O -lwsbsdcompat -lQuartzCore -Wl,-rpath,$O $GSL -lopal -lgnustep-corebase -ldispatch 2>&1 | grep error | head -3
	[ -x $O/$t ] || { echo "SDK TEST $t: did not build"; FAIL=1; continue; }
	LD_LIBRARY_PATH=$O:/usr/local/GNUstep/System/Library/Libraries:/usr/local/GNUstep/Local/Library/Libraries:/usr/local/lib timeout 60 $O/$t > $O/$t.out 2>&1 && echo "SDK TEST $t: ok" || { echo "SDK TEST $t: FAILED"; FAIL=1; }
	grep -v '^20' $O/$t.out | tail -6
done
exit $FAIL
