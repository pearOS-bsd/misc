#!/bin/sh
# Runs the programs of sdk/tests against the compat layer (needs GNUstep gui/back, Opal and a running wsd: WS_SOCKET): sh ci/sdk-tests.sh
. /usr/local/GNUstep/System/Library/Makefiles/GNUstep.sh
WS0="$(cd "$(dirname "$0")/.." && pwd)"
# Opal (CoreGraphics) and corebase (CoreFoundation): built from source when this runner does not have them yet
ls /usr/local/GNUstep/*/Library/Libraries/libopal.so >/dev/null 2>&1 || { sh "$WS0/ci/opal-libs.sh" > /tmp/opal-libs-sdk.log 2>&1; tail -3 /tmp/opal-libs-sdk.log; . /usr/local/GNUstep/System/Library/Makefiles/GNUstep.sh; }
WS="$(cd "$(dirname "$0")/.." && pwd)"; O=/tmp/sdk-compat; mkdir -p $O
# the CoreFoundation headers of corebase are reached through the wrappers the application builds use
sh "$WS/sdk/gen-cf-wrappers.sh" $O/cfwrap 2>&1 | tail -1
export CPATH="$O/cfwrap${CPATH:+:$CPATH}"
sh "$WS/sdk/build-compat.sh" $O 2>&1 | tail -4
GSL="$(gnustep-config --gui-libs)"
FAIL=0
export WSBSD_SDK_INCLUDE="$WS/sdk/include" WSBSD_QL_CFLAGS="-I$O/cfwrap $(gnustep-config --objc-flags | tr '\n' ' ')"
for t in rep_draw anim_test layer_demo sys_tests ql_tests sec_tests net_tests cfstr_tests vfl_tests xpc_tests; do
	clang -x objective-c -fblocks -w -fobjc-arc -I$O/cfwrap -I"$WS/quartzcore/include" -I"$WS/sdk/include" -include "$WS/sdk/include/wsbsd/prelude.h" $(gnustep-config --objc-flags) "$WS/sdk/tests/$t.m" -o $O/$t \
		-L$O -lwsbsdcompat -lQuartzCore -Wl,-rpath,$O $GSL -lopal -lgnustep-corebase -ldispatch -lcrypto -lcurl -lffi 2>&1 | grep error | head -3
	[ -x $O/$t ] || { echo "SDK TEST $t: did not build"; FAIL=1; continue; }
	LD_LIBRARY_PATH=$O:/usr/local/GNUstep/System/Library/Libraries:/usr/local/GNUstep/Local/Library/Libraries:/usr/local/lib timeout 60 $O/$t > $O/$t.out 2>&1 && echo "SDK TEST $t: ok" || { echo "SDK TEST $t: FAILED"; FAIL=1; }
	grep -v '^20' $O/$t.out | tail -6
done
# CoreWLAN: the framework builds as on the Mac (System/Library/...) and CWNetwork / CWChannel answer like the real ones (golden file from a Mac, tools/cwprobe)
CW="$O/cwout"; rm -rf "$CW"; sh "$WS/sdk/build-corewlan.sh" "$CW" > "$O/cwlan-build.out" 2>&1
CWL="$CW/System/Library/Frameworks/CoreWLAN.framework/Versions/A"; CWF="$CW/System/Library/PrivateFrameworks/CoreWiFi.framework/Versions/A"
clang -x objective-c -fblocks -w -fobjc-arc -I"$WS/sdk/include" $(gnustep-config --objc-flags) "$WS/sdk/tests/cwlan_golden_test.m" -o "$O/cwlan_golden_test" $(gnustep-config --base-libs) -L"$CWL" -L"$CWF" -l:CoreWLAN -l:CoreWiFi -Wl,-rpath,"$CWL" -Wl,-rpath,"$CWF" 2>&1 | grep error | head -3
[ -x "$O/cwlan_golden_test" ] || { echo "SDK TEST cwlan_golden_test: did not build"; FAIL=1; }
[ -x "$O/cwlan_golden_test" ] && { LD_LIBRARY_PATH=/usr/local/GNUstep/System/Library/Libraries:/usr/local/lib timeout 120 "$O/cwlan_golden_test" "$WS/sdk/tests/golden/cwlan_golden.json" > "$O/cwlan_golden_test.out" 2>&1 && echo "SDK TEST cwlan_golden_test: ok" || { echo "SDK TEST cwlan_golden_test: FAILED"; FAIL=1; }; grep -v '^20' "$O/cwlan_golden_test.out" | tail -6; }
exit $FAIL
