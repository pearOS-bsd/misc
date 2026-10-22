#!/bin/sh
# The private frameworks of the desktop as ELF libraries laid out as on the Mac: sh sdk/build-frameworks.sh OUTDIR
#   OUTDIR/System/Library/PrivateFrameworks/<Name>.framework/Versions/A/<Name>   (+ Versions/Current, <Name> links)
# Stubs are generated from the inventories in docs/desktop/frameworks (tools/gen_objc_stubs.py); hand-written parts are sdk/src/<Name>/*_impl.m.
OUT="${1:?output directory}"; D="$(cd "$(dirname "$0")" && pwd)"
FW="${FRAMEWORKS:-IconFoundation IconServices DesktopServicesPriv DesktopServicesUI StorageKit DiskManagement SystemPolicy PlugInKit ViewBridge}"
INC=""; for n in $FW; do INC="$INC -I$D/include/$n"; done
F="-fPIC -fblocks -w -fno-objc-arc -I$D/include -I$D/../quartzcore/include $INC $(gnustep-config --objc-flags)"
mkdir -p "$OUT/obj"
for n in $FW; do
	V="$OUT/System/Library/PrivateFrameworks/$n.framework/Versions/A"; mkdir -p "$V"
	for f in "$D"/src/$n/*.m; do clang $F -c "$f" -o "$OUT/obj/${n}_$(basename "$f" .m).o" 2>&1 | grep -E "error" | head -3; done
	clang -shared -o "$V/$n" "$OUT"/obj/${n}_*.o -Wl,--unresolved-symbols=ignore-all $(gnustep-config --gui-libs) 2>&1 | head -3
	ln -sfn A "$OUT/System/Library/PrivateFrameworks/$n.framework/Versions/Current"; ln -sfn Versions/Current/$n "$OUT/System/Library/PrivateFrameworks/$n.framework/$n"
	ls -l "$V/$n" | awk '{print "built", $9, $5, "bytes"}'
done
