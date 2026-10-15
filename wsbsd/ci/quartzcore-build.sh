#!/bin/sh
# Core Animation attempt: GNUstep QuartzCore (CALayer, 2012 GSoC) over corebase + Opal on FreeBSD. Exploratory: reports where the build stops.
export IGNORE_OSVERSION=yes
WS="${GITHUB_WORKSPACE:-$(cd "$(dirname "$0")/../.." && pwd)}/wsbsd"
[ -d "$WS" ] || WS="$(cd "$(dirname "$0")/.." && pwd)"
# corebase + Opal (and the packaged gnustep-gui) come from the Opal script; its demo is skipped by stopping after the libraries
sh "$WS/ci/opal-build.sh" >/tmp/opal-build.log 2>&1
tail -5 /tmp/opal-build.log
echo '== opal demo lines:'; grep -n 'opal_demo\|ctx data\|ld-elf\|error' /tmp/opal-build.log | cut -c1-200 | head -12
pkg install -y gnustep-gui mesa-libs libglvnd glew python3 >/dev/null 2>&1
. /usr/local/GNUstep/System/Library/Makefiles/GNUstep.sh
cd /tmp/gs && git clone --depth 1 https://github.com/gnustep/libs-quartzcore qc 2>&1 | tail -1
cd qc
ls
gmake -j2 messages=yes 2>&1 | grep -E "error|Error|fatal|No such|undefined" | head -40
echo "== build done, libraries:"
ls Source/obj 2>/dev/null | head
find /tmp/gs/qc -name "libQuartzCore*" | head

# the smallest Opal drawing, with and without libQuartzCore / GL on the link line
cd "$WS"
gmake wsd 2>&1 | tail -1
OBJC_FLAGS="$(gnustep-config --objc-flags 2>/dev/null)"
OBJC_LIBS="$(gnustep-config --base-libs 2>/dev/null)"
LDP=/tmp/gs/qc/Source/QuartzCore.framework/Versions/0:/tmp/gs/qc/Source/QuartzCore.framework:/tmp/gs/opal/Source/obj:/tmp/gs/corebase/Source/obj:/usr/local/GNUstep/System/Library/Libraries:/usr/local/lib
CSRC="src/client.c src/compositor_sw.c src/region.c src/ipc.c src/evrec.c src/buffer.c"
cc -O1 -Iinclude $OBJC_FLAGS -I/usr/local/GNUstep/System/Library/Headers -o opal_min_plain demo/opal_min.m $CSRC -lopal -lgnustep-corebase $OBJC_LIBS -lcairo -lm 2>&1 | grep -E "error" | head -5
cc -O1 -Iinclude $OBJC_FLAGS -I/usr/local/GNUstep/System/Library/Headers -o opal_min_qc demo/opal_min.m $CSRC -L/tmp/gs/qc/Source/QuartzCore.framework -lQuartzCore -lGL -lopal -lgnustep-corebase $OBJC_LIBS -lcairo -lm 2>&1 | grep -E "error" | head -5
export WS_SOCKET=/tmp/wsd-min.sock
./wsd -t -g 1024x700 >/tmp/wsd-min.log 2>&1 &
MP=$!
sleep 1
echo "== opal_min plain variants:"; for v in 10; do LD_LIBRARY_PATH=$LDP ./opal_min_plain $v 2>&1 | tail -4; done
cc -O1 -g -Iinclude $OBJC_FLAGS -I/usr/local/GNUstep/System/Library/Headers -o opal_demo_here demo/opal_demo.m $CSRC -lopal -lgnustep-corebase $OBJC_LIBS -lcairo -lm 2>&1 | grep -E "error" | head -3
echo "== opal_demo in this job (it works in the opal job):"; LD_LIBRARY_PATH=$LDP ./opal_demo_here /tmp/opal-here.ppm 2>&1 | grep -E "ctx data|wrote" | head -3
echo "== LD path used: $LDP"; ldd ./opal_min_plain 2>/dev/null | grep -E "opal|corebase|cairo|base" | head -6
echo "== opal_min with QuartzCore+GL:"; LD_LIBRARY_PATH=$LDP ./opal_min_qc 2>&1 | tail -3
kill $MP 2>/dev/null
# the demo: a CALayer tree with animations drawn into a wsd window
gmake install 2>&1 | tail -2
cd "$WS"
gmake wsd 2>&1 | tail -1
OBJC_FLAGS="$(gnustep-config --objc-flags 2>/dev/null)"
OBJC_LIBS="$(gnustep-config --base-libs 2>/dev/null)"
cc -O1 -g -Iinclude $OBJC_FLAGS -I/usr/local/GNUstep/System/Library/Headers -o ca_demo demo/ca_demo.m src/client.c src/compositor_sw.c src/region.c src/ipc.c src/evrec.c src/buffer.c -L/tmp/gs/qc/Source/QuartzCore.framework -lQuartzCore -lGL -lopal -lgnustep-corebase $OBJC_LIBS -lcairo -lm 2>&1 | tail -25
export WS_SOCKET=/tmp/wsd-ca.sock
./wsd -t -g 1024x700 >/tmp/wsd-ca.log 2>&1 &
WP=$!
sleep 1
LD_LIBRARY_PATH=/tmp/gs/qc/Source/QuartzCore.framework/Versions/0:/tmp/gs/qc/Source/QuartzCore.framework:/tmp/gs/opal/Source/obj:/tmp/gs/corebase/Source/obj:/usr/local/GNUstep/System/Library/Libraries:/usr/local/lib ./ca_demo ca 2>&1 | tail -15
kill $WP 2>/dev/null
for f in ca-a ca-b; do python3 tools/ppm2png.py $f.ppm $f.png 2>&1 | tail -1; done
ls -l ca-*.png 2>&1
