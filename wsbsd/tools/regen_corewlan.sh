#!/bin/sh
# Regenerates the stub sources and headers of CoreWLAN and CoreWiFi from the inventory in docs/corewlan; the classes listed in the second argument of each call are hand-written (sdk/src/<Framework>/<Class>_impl.m)
cd "$(dirname "$0")/.." || exit 1
python3 tools/impl_skips.py sdk/src/CoreWLAN/*_impl.m > /tmp/cwlan.skips
python3 tools/impl_skips.py sdk/src/CoreWiFi/*_impl.m > /tmp/cwifi.skips 2>/dev/null; touch /tmp/cwifi.skips
python3 tools/gen_objc_stubs.py docs/corewlan/CoreWLAN.objc.txt CoreWLAN sdk/include/CoreWLAN --skip-class CWChannel,CWNetwork --skip /tmp/cwlan.skips >/dev/null
python3 tools/gen_objc_stubs.py docs/corewlan/CoreWiFi.objc.txt CoreWiFi sdk/include/CoreWiFi --skip /tmp/cwifi.skips >/dev/null
mv sdk/include/CoreWLAN/CoreWLAN_Generated.m sdk/src/CoreWLAN/; mv sdk/include/CoreWiFi/CoreWiFi_Generated.m sdk/src/CoreWiFi/
