#!/bin/sh
# Builds GNUstep corebase (CoreFoundation) and Opal (CoreGraphics over Cairo) from source inside FreeBSD: the layer above SkyLight/wsd that a CoreGraphics demo needs.
export IGNORE_OSVERSION=yes
pkg search -o dispatch | head -5
pkg install -y libdispatch gnustep-make gnustep-base cairo freetype2 fontconfig git png jpeg-turbo tiff pkgconf gmake lcms2 bzip2 icu libffi dejavu >/dev/null 2>&1 || true
cat > /usr/local/libdata/pkgconfig/bzip2.pc <<EOP
Name: bzip2
Description: bzip2
Version: 1.0.8
Libs: -lbz2
Cflags:
EOP
. /usr/local/GNUstep/System/Library/Makefiles/GNUstep.sh
mkdir -p /tmp/gs && cd /tmp/gs
git clone --depth 1 https://github.com/gnustep/libs-corebase corebase 2>&1 | tail -1
(cd corebase && ls /usr/local/include/dispatch 2>&1 | head -3; ./configure CPPFLAGS="-I/usr/local/include" LDFLAGS="-L/usr/local/lib" 2>&1 | tail -8 && gmake -j2 2>&1 | tail -15 && gmake install 2>&1 | tail -3)
git clone --depth 1 https://github.com/gnustep/libs-opal opal 2>&1 | tail -1
(cd opal && gmake -j2 messages=yes 2>&1 | tail -40 && gmake install 2>&1 | tail -3)
ls /usr/local/GNUstep/System/Library/Libraries 2>&1 | head -30

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
