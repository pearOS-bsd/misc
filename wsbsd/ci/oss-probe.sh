#!/bin/sh
# Feasibility survey: unmodified open source Cocoa apps against the GNUstep stack. Each repo is cloned as is, every Objective-C source file is syntax-checked
# with the GNUstep flags (no source edits, no stubs), and the errors are summed up: missing headers first, then the most frequent messages.
# Output goes to stdout (and wsbsd/oss-probe.log through the caller). Nothing here fails the build.
REPOS="${OSS_REPOS:-HexFiend/HexFiend MacDownApp/macdown transmission/transmission}"
W=/tmp/oss; rm -rf $W; mkdir -p $W; cd $W || exit 0
FLAGS="$(gnustep-config --objc-flags) -fblocks -w -fsyntax-only -Wno-error"
for r in $REPOS; do
	n=$(echo $r | tr / _)
	timeout 120 git clone --depth 1 -q https://github.com/$r $n 2>/dev/null || { echo "== $r: clone failed"; continue; }
	files=$(find $n -name '*.m' -not -path '*/Tests/*' -not -path '*/Pods/*' -not -path '*/Carthage/*' -not -path '*/test/*' -not -path '*/third-party/*' -not -path '*/ThirdParty/*' | head -300)
	total=0; ok=0; : > $W/$n.err
	for f in $files; do
		total=$((total+1))
		inc=""; d=$(dirname $f); while [ "$d" != "." ] && [ "$d" != "/" ]; do inc="$inc -I$d"; d=$(dirname $d); done
		if timeout 30 clang $FLAGS $inc $f >$W/one.err 2>&1; then ok=$((ok+1)); else grep "error:" $W/one.err >> $W/$n.err; fi
	done
	echo "== $r: $ok of $total Objective-C files compile unmodified"
	echo "-- missing headers:"; grep "file not found" $W/$n.err | sed 's/.*fatal error: //; s/.*error: //' | sort | uniq -c | sort -rn | head -12
	echo "-- most frequent other errors:"; grep -v "file not found" $W/$n.err | sed 's/^[^ ]* error: //; s/'"'"'[^'"'"']*'"'"'/X/g' | sort | uniq -c | sort -rn | head -12
done
