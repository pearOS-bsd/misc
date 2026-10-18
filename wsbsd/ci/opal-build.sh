#!/bin/sh
# Builds GNUstep corebase and Opal, then runs a CoreGraphics demo into a wsd window.
sh "$(dirname "$0")/opal-libs.sh"
# the demo: CoreGraphics (Opal) into a wsd window
cd "$GITHUB_WORKSPACE/wsbsd" 2>/dev/null || cd "$(dirname "$0")/.."
gmake wsd 2>&1 | tail -3
OBJC_FLAGS="$(gnustep-config --objc-flags 2>/dev/null)"
OBJC_LIBS="$(gnustep-config --base-libs 2>/dev/null)"
cc -O1 -g -Iinclude $OBJC_FLAGS -I/usr/local/GNUstep/System/Library/Headers -o opal_demo demo/opal_demo.m src/client.c src/compositor_sw.c src/region.c src/ipc.c src/evrec.c src/buffer.c -lopal -lgnustep-corebase $OBJC_LIBS -lcairo -lm 2>&1 | tail -30
SOCK=/tmp/wsd-opal.sock; export WS_SOCKET=$SOCK
./wsd -t -g 1280x800 >/dev/null 2>&1 &
sleep 1
find / -name "libopal*" -o -name "libgnustep-corebase*" 2>/dev/null | head -5
LD_LIBRARY_PATH=/tmp/gs/opal/Source/obj:/tmp/gs/corebase/Source/obj:/usr/local/GNUstep/System/Library/Libraries:/usr/local/lib ./opal_demo opal.ppm 2>&1 | tail -5
python3 tools/ppm2png.py opal.ppm opal.png 2>&1 | tail -1 || true
python3 tools/ppm2png.py opal.ppm-click.ppm opal-click.png 2>&1 | tail -1 || true
ls -l opal.png opal-click.png 2>&1

# Opal probe: do successive contexts over one buffer all draw?
cc -O1 -g $OBJC_FLAGS -I/usr/local/GNUstep/System/Library/Headers -o opal_probe demo/opal_probe.m -lopal -lgnustep-corebase $OBJC_LIBS -lcairo -lm 2>&1 | tail -5
LD_LIBRARY_PATH=/tmp/gs/opal/Source/obj:/tmp/gs/corebase/Source/obj:/usr/local/GNUstep/System/Library/Libraries:/usr/local/lib ./opal_probe 2>&1 | tail -6
