#!/bin/sh
# Regenerates the stub sources and headers of CoreWLAN and CoreWiFi from the inventory in docs/corewlan; the classes listed in the second argument of each call are hand-written (sdk/src/<Framework>/<Class>_impl.m)
cd "$(dirname "$0")/.." || exit 1
python3 tools/gen_objc_stubs.py docs/corewlan/CoreWLAN.objc.txt CoreWLAN sdk/include/CoreWLAN --skip-class CWChannel,CWNetwork >/dev/null
python3 tools/gen_objc_stubs.py docs/corewlan/CoreWiFi.objc.txt CoreWiFi sdk/include/CoreWiFi >/dev/null
mv sdk/include/CoreWLAN/CoreWLAN_Generated.m sdk/src/CoreWLAN/; mv sdk/include/CoreWiFi/CoreWiFi_Generated.m sdk/src/CoreWiFi/
