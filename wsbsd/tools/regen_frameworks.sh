#!/bin/sh
# Regenerates the stub headers/sources of the private frameworks of the desktop from docs/desktop/frameworks/*.objc.txt (see sdk/build-frameworks.sh). Imports: the AppKit based ones and the cross-framework superclasses.
cd "$(dirname "$0")/.." || exit 1
gen() { n=$1; shift; mkdir -p sdk/include/$n sdk/src/$n; python3 tools/impl_skips.py sdk/src/$n/*_impl.m > /tmp/$n.skips 2>/dev/null; touch /tmp/$n.skips; python3 tools/gen_objc_stubs.py docs/desktop/frameworks/$n.objc.txt $n sdk/include/$n --skip /tmp/$n.skips "$@" > /dev/null && mv sdk/include/$n/${n}_Generated.m sdk/src/$n/; }
gen IconFoundation
gen IconServices --imports IconFoundation/IconFoundation_Generated.h --known-from docs/desktop/frameworks/IconFoundation.objc.txt
gen DesktopServicesPriv --imports AppKit/AppKit.h
gen DesktopServicesUI --imports AppKit/AppKit.h
gen StorageKit --imports AppKit/AppKit.h
gen DiskManagement
gen SystemPolicy
gen PlugInKit
gen ViewBridge --imports AppKit/AppKit.h
