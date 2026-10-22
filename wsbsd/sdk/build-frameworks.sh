#!/bin/sh
# The private frameworks of the desktop as ELF libraries laid out as on the Mac: sh sdk/build-frameworks.sh OUTDIR
#   OUTDIR/System/Library/PrivateFrameworks/<Name>.framework/Versions/A/<Name>   (+ Versions/Current, <Name> links)
# Stubs are generated from the inventories in docs/desktop/frameworks (tools/regen_frameworks.sh, the list is sdk/frameworks.list); hand-written parts are sdk/src/<Name>/*_impl.m.
# Public frameworks (CloudKit, Accounts, ...) go to /System/Library/Frameworks, the others to /System/Library/PrivateFrameworks.
OUT="${1:?output directory}"; D="$(cd "$(dirname "$0")" && pwd)"
FW="${FRAMEWORKS:-$(cat "$D/frameworks.list")}"
PUBLIC=" CloudKit Accounts ContactsUI SharedWithYou SafariServices FileProviderUI FileProvider Collaboration ImageCaptureCore "
INC=""; for n in $FW; do INC="$INC -I$D/include/$n"; done
F="-fPIC -fblocks -w -fno-objc-arc -I$D/../quartzcore/include -I$D/include $INC $(gnustep-config --objc-flags)"
mkdir -p "$OUT/obj"
for n in $FW; do
	case "$PUBLIC" in *" $n "*) BASE="$OUT/System/Library/Frameworks" ;; *) BASE="$OUT/System/Library/PrivateFrameworks" ;; esac
	V="$BASE/$n.framework/Versions/A"; mkdir -p "$V"
	for f in "$D"/src/$n/*.m; do clang $F -c "$f" -o "$OUT/obj/${n}_$(basename "$f" .m).o" 2>&1 | grep -E "error" | head -2; done
	clang -shared -o "$V/$n" "$OUT"/obj/${n}_*.o -Wl,--unresolved-symbols=ignore-all $(gnustep-config --gui-libs) 2>&1 | head -2
	ln -sfn A "$BASE/$n.framework/Versions/Current"; ln -sfn Versions/Current/$n "$BASE/$n.framework/$n"
	[ -f "$V/$n" ] && ls -l "$V/$n" | awk '{print "built", $9, $5, "bytes"}' || echo "NOT BUILT: $n"
done
