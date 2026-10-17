#!/bin/sh
# Feasibility survey: unmodified open source Cocoa apps against the GNUstep stack. Each repo is cloned as is (no source edits, no stubs) and every Objective-C
# file is syntax-checked with the GNUstep flags plus ARC. The project's own headers resolve through generated include directories (a directory of headers named
# X is reachable as <X/...>, the way an Xcode framework target exposes them), its .pch is force-included. The errors are summed up by the real names:
# missing system headers, undeclared identifiers / types, missing properties and methods. Output goes to stdout; nothing here fails the build.
REPOS="${OSS_REPOS:-HexFiend/HexFiend MacDownApp/macdown transmission/transmission}"
W=/tmp/oss; rm -rf $W; mkdir -p $W; cd $W || exit 0
BASE="$(gnustep-config --objc-flags) -fblocks -fobjc-arc -w -fsyntax-only"
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
