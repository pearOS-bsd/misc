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
clang -x objective-c -fblocks -w -fobjc-arc -I"$WS/sdk/include" $(gnustep-config --objc-flags) "$WS/sdk/tests/cwlan_golden_test.m" -o "$O/cwlan_golden_test" $(gnustep-config --base-libs) -L"$CWL" -L"$CWF" -l:CoreWLAN -l:CoreWiFi -Wl,-rpath,"$CWL" -Wl,-rpath,"$CWF" -L/usr/local/lib -lffi -ldispatch 2>&1 | grep error | head -3
[ -x "$O/cwlan_golden_test" ] || { echo "SDK TEST cwlan_golden_test: did not build"; FAIL=1; }
[ -x "$O/cwlan_golden_test" ] && { LD_LIBRARY_PATH=/usr/local/GNUstep/System/Library/Libraries:/usr/local/lib timeout 120 "$O/cwlan_golden_test" "$WS/sdk/tests/golden/cwlan_golden.json" > "$O/cwlan_golden_test.out" 2>&1 && echo "SDK TEST cwlan_golden_test: ok" || { echo "SDK TEST cwlan_golden_test: FAILED"; FAIL=1; }; grep -v '^20' "$O/cwlan_golden_test.out" | tail -6; }
# CWNetworkProfile / CWConfiguration against what the real framework printed (properties, description, equality, external form, archives)
for pr in "profile_probe cwprofile_probe" "profile_probe2 cwprofile_probe2" "cfg_probe cwconfig_probe" "coding_probe cwcoding_probe"; do
	set -- $pr; src=$1; gold=$2
	clang -x objective-c -fblocks -fobjc-arc -w -I"$WS/sdk/include" -I/usr/local/include $(gnustep-config --objc-flags) "$WS/tools/cwprobe/$src.m" -o "$O/$src" $(gnustep-config --base-libs) -L"$CWL" -L"$CWF" -l:CoreWLAN -l:CoreWiFi -Wl,-rpath,"$CWL" -Wl,-rpath,"$CWF" -L/usr/local/lib -lffi -ldispatch 2>&1 | grep error | head -3
	if [ -x "$O/$src" ]; then LD_LIBRARY_PATH=/usr/local/GNUstep/System/Library/Libraries:/usr/local/lib "$O/$src" 2>&1 | sed -e 's/0x[0-9a-f]*/PTR/g' -e 's/_processIdentifier:integer=[0-9]*/_processIdentifier:integer=N/' > "$O/$gold.out"; if cmp -s "$O/$gold.out" "$WS/sdk/tests/golden/$gold.txt"; then echo "SDK TEST $gold: ok"; else echo "SDK TEST $gold: FAILED"; diff "$WS/sdk/tests/golden/$gold.txt" "$O/$gold.out" | head -6; FAIL=1; fi; else echo "SDK TEST $gold: did not build"; FAIL=1; fi
done
# wpa_supplicant backend of airportd against a fake control socket and the IE parser
clang -x objective-c -fblocks -fobjc-arc -w -I"$WS/sdk/include" -I"$WS/airportd" -I/usr/local/include $(gnustep-config --objc-flags) "$WS/sdk/tests/wpa_backend_tests.m" "$WS/airportd/WSWiFiWpaBackend.m" "$WS/airportd/WSIEParser.m" "$WS/airportd/WSWiFiSimBackend.m" -o "$O/wpa_backend_tests" $(gnustep-config --base-libs) -L/usr/local/lib -ldispatch 2>&1 | grep error | head -5
[ -x "$O/wpa_backend_tests" ] || { echo "SDK TEST wpa_backend_tests: did not build"; FAIL=1; }
[ -x "$O/wpa_backend_tests" ] && { LD_LIBRARY_PATH=/usr/local/GNUstep/System/Library/Libraries:/usr/local/lib timeout 60 "$O/wpa_backend_tests" > "$O/wpa_backend_tests.out" 2>&1 && echo "SDK TEST wpa_backend_tests: ok" || { echo "SDK TEST wpa_backend_tests: FAILED"; FAIL=1; }; grep -v '^20' "$O/wpa_backend_tests.out" | tail -8; }
# airportd with the simulated Wi-Fi world and CoreWLAN talking to it over XPC (scan, hotspot detection, join, events, auto-join)
clang -x objective-c -fblocks -fobjc-arc -w -I"$WS/sdk/include" -I"$WS/airportd" -I/usr/local/include $(gnustep-config --objc-flags) "$WS/sdk/tests/cwlan_airportd_tests.m" "$WS/airportd/WSAirportService.m" "$WS/airportd/WSWiFiSimBackend.m" "$WS/sdk/src/XPC.m" -o "$O/cwlan_airportd_tests" $(gnustep-config --base-libs) -L"$CWL" -L"$CWF" -l:CoreWLAN -l:CoreWiFi -Wl,-rpath,"$CWL" -Wl,-rpath,"$CWF" -L/usr/local/lib -lffi -ldispatch 2>&1 | grep error | head -3
[ -x "$O/cwlan_airportd_tests" ] || { echo "SDK TEST cwlan_airportd_tests: did not build"; FAIL=1; }
[ -x "$O/cwlan_airportd_tests" ] && { rm -rf /tmp/wsbsd-airportd-test; LD_LIBRARY_PATH=/usr/local/GNUstep/System/Library/Libraries:/usr/local/lib timeout 120 "$O/cwlan_airportd_tests" > "$O/cwlan_airportd_tests.out" 2>&1 && echo "SDK TEST cwlan_airportd_tests: ok" || { echo "SDK TEST cwlan_airportd_tests: FAILED"; FAIL=1; }; grep -v '^20' "$O/cwlan_airportd_tests.out" | tail -6; }
exit $FAIL
