#!/bin/sh
# Feasibility survey: unmodified open source Cocoa apps against the GNUstep stack. Each repo is cloned as is (no source edits, no stubs) and every Objective-C
# file is syntax-checked with the GNUstep flags plus ARC. The project's own headers resolve through generated include directories (a directory of headers named
# X is reachable as <X/...>, the way an Xcode framework target exposes them), its .pch is force-included. The errors are summed up by the real names:
# missing system headers, undeclared identifiers / types, missing properties and methods. Output goes to stdout; nothing here fails the build.
REPOS="${OSS_REPOS:-HexFiend/HexFiend MacDownApp/macdown transmission/transmission}"
WS="${WS:-$(cd "$(dirname "$0")/.." && pwd)}"
W=/tmp/oss; rm -rf $W; mkdir -p $W; cd $W || exit 0
# CoreFoundation: GNUstep CoreBase from source (not part of the pkg set); a failed build only shows up as the missing CF types in the survey
if [ "${OSS_COREBASE:-1}" = 1 ]; then
	pkg install -y icu >/dev/null 2>&1 || true
	timeout 120 git clone --depth 1 -q https://github.com/gnustep/libs-corebase corebase 2>/dev/null
	( cd corebase && ./configure CPPFLAGS="-I/usr/local/include" LDFLAGS="-L/usr/local/lib" > $W/cb-conf.log 2>&1 && gmake -j2 GNUSTEP_INSTALLATION_DOMAIN=SYSTEM > $W/cb-build.log 2>&1 && gmake install GNUSTEP_INSTALLATION_DOMAIN=SYSTEM > $W/cb-inst.log 2>&1 ) && echo "corebase: installed" || { echo "corebase: build FAILED"; tail -5 $W/cb-conf.log; grep -E "error" $W/cb-build.log | head -8; }
	ls /usr/local/GNUstep/System/Library/Headers/CoreFoundation 2>/dev/null | head -3
fi
# Opal: CoreGraphics, CoreText and ImageIO headers and libraries (built the way ci/opal-build.sh does)
if [ "${OSS_OPAL:-1}" = 1 ]; then
	pkg install -y libdispatch cairo freetype2 fontconfig lcms2 bzip2 >/dev/null 2>&1 || true
	[ -f /usr/local/libdata/pkgconfig/bzip2.pc ] || printf 'Name: bzip2\nDescription: bzip2\nVersion: 1.0.8\nLibs: -lbz2\nCflags:\n' > /usr/local/libdata/pkgconfig/bzip2.pc
	timeout 120 git clone --depth 1 -q https://github.com/gnustep/libs-opal opal 2>/dev/null
	( cd opal && gmake -j2 messages=yes > $W/opal-build.log 2>&1 && gmake install > $W/opal-inst.log 2>&1 ) && echo "opal: installed" || { echo "opal: build FAILED"; grep -E "error" $W/opal-build.log | head -8; }
	ls /usr/local/GNUstep/System/Library/Headers/CoreText 2>/dev/null | head -3
fi
BASE="-I$WS/sdk/include -include $WS/sdk/include/wsbsd/prelude.h $(gnustep-config --objc-flags) -fblocks -fobjc-arc -w -fsyntax-only"
for r in $REPOS; do
	n=$(echo $r | tr / _)
	timeout 120 git clone --depth 1 -q https://github.com/$r $n 2>/dev/null || { echo "== $r: clone failed"; continue; }
	INC=$W/$n.inc; mkdir -p $INC
	for h in $(find $n -name '*.h' -not -path '*/Pods/*' | head -3000); do d=$(dirname $h); b=$(basename $d); [ -e $INC/$b ] || ln -s $W/$d $INC/$b; done
	DIRS=""; for d in $(find $n -name '*.h' -not -path '*/Pods/*' | head -3000 | xargs -n1 dirname | sort -u); do DIRS="$DIRS -I$W/$d"; done
	PCH=$(find $n -name '*.pch' | head -1); [ -n "$PCH" ] && PCH="-include $W/$PCH"
	files=$(find $n \( -name '*.m' -o -name '*.mm' \) -not -path '*/Tests/*' -not -path '*Test*' -not -path '*/Pods/*' -not -path '*/Carthage/*' -not -path '*/third-party/*' -not -path '*/ThirdParty/*' -not -path '*/libtransmission/*' | head -400)
	total=0; ok=0; : > $W/$n.err
	for f in $files; do
		total=$((total+1))
		case $f in *.mm) LANG="-x objective-c++ -std=c++17";; *) LANG="-x objective-c";; esac
		if timeout 30 clang $BASE $LANG -I$INC $DIRS $PCH $f >$W/one.err 2>&1; then ok=$((ok+1)); else grep "error:" $W/one.err >> $W/$n.err; fi
	done
	echo "== $r: $ok of $total Objective-C/C++ files compile unmodified"
	echo "-- missing headers:"; grep "file not found" $W/$n.err | sed "s/.*error: //" | sort | uniq -c | sort -rn | head -10
	echo "-- undeclared identifiers / types:"; grep -E "undeclared identifier|unknown type name|no type or protocol" $W/$n.err | sed "s/.*error: //" | sort | uniq -c | sort -rn | head -25
	echo "-- missing properties / methods / classes:"; grep -E "not found on object|no visible @interface|no known (class|instance) method|cannot find (interface|protocol)" $W/$n.err | sed "s/.*error: //" | sort | uniq -c | sort -rn | head -20
	echo "-- other:"; grep -vE "file not found|undeclared identifier|unknown type name|no type or protocol|not found on object|no visible @interface|no known|cannot find" $W/$n.err | sed "s/.*error: //" | sort | uniq -c | sort -rn | head -10
done

# the compatibility layer itself has to compile against this GNUstep (errors are shown, the survey goes on)
echo "== sdk/src/AppKitCompat.m"; clang -I$WS/sdk/include $(gnustep-config --objc-flags) -fblocks -fobjc-arc -Wno-everything -fsyntax-only $WS/sdk/src/AppKitCompat.m 2>&1 | grep -E "error" | head -20; echo "(end of compat check)"

# The same survey through the Xcode project driver (tools/xcb): headers staged the way Xcode exposes them, the target's own flags, ARC, defines and prefix header;
# the CF / CoreText / CoreGraphics headers are patched copies with the ARC "audited" regions Apple's have (sdk/gen-cf-wrappers.sh), libwsbsdcompat provides the rest
if command -v python3 >/dev/null 2>&1 && [ -d $W/HexFiend_HexFiend ]; then
	sh "$WS/sdk/gen-cf-wrappers.sh" $W/cfwrap 2>&1 | tail -1
	sh "$WS/sdk/build-compat.sh" $W/compat 2>&1 | tail -3
	GSL="$(gnustep-config --gui-libs)"
	XF="-I$W/cfwrap -I$WS/sdk/include -include $WS/sdk/include/wsbsd/prelude.h $(gnustep-config --objc-flags) -w"
	echo "== xcb: Hex Fiend, target HexFiend_Framework (framework, 61 Objective-C sources): compile and link"
	python3 "$WS/tools/xcb/xcb.py" $W/HexFiend_HexFiend/app/HexFiend_2.xcodeproj build HexFiend_Framework --out $W/xcb-hf --cc clang --cflags "$XF" \
		--fw-map "Cocoa=$GSL;Foundation=$(gnustep-config --base-libs)" --ldflags "$GSL -L$W/compat -lwsbsdcompat -lopal -lgnustep-corebase -ldispatch" -j 2 2>&1 | head -40
	O=$W/xcb-hf/HexFiend_Framework
	if [ -f $O/libHexFiend.so ]; then
		clang -x objective-c -fobjc-arc $XF -I$O/headers "$WS/sdk/tests/hexfiend_smoke.m" -o $W/hf_smoke -L$O -lHexFiend -L$W/compat -lwsbsdcompat $GSL -lopal -lgnustep-corebase -ldispatch 2>&1 | grep error | head -5
		echo "== Hex Fiend engine smoke test (HFByteArray from the unmodified sources):"
		LD_LIBRARY_PATH=$O:$W/compat:/usr/local/GNUstep/System/Library/Libraries:/usr/local/GNUstep/Local/Library/Libraries:/usr/local/lib $W/hf_smoke 2>&1 | tail -3; echo "exit status $?"
	fi
fi
