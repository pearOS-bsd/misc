#!/bin/sh
# rebuild the wsd back bundle in the VM and install it (gmake install does not copy a rebuilt binary)
. /usr/local/GNUstep/System/Library/Makefiles/GNUstep.sh
cd /tmp/gs/back; cp /root/wsbsd/appkit/back-wsd/*.m Source/headless/
for f in client compositor_sw region ipc evrec buffer keymap xkbmap; do cp /root/wsbsd/src/$f.c Source/headless/wsc_$f.c; done
for f in car bvg bitmap; do cp /root/wsbsd/coreui/$f.c Source/headless/cu_$f.c; done
gmake 2>&1 | grep -E "rror" | head
cp Source/libgnustep-back-032.bundle/libgnustep-back-032 /usr/local/GNUstep/Local/Library/Bundles/libgnustep-back-032.bundle/libgnustep-back-032
