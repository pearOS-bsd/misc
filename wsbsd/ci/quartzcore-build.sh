#!/bin/sh
# Core Animation attempt: GNUstep QuartzCore (CALayer, 2012 GSoC) over corebase + Opal on FreeBSD. Exploratory: reports where the build stops.
export IGNORE_OSVERSION=yes
WS="${GITHUB_WORKSPACE:-$(cd "$(dirname "$0")/../.." && pwd)}/wsbsd"
[ -d "$WS" ] || WS="$(cd "$(dirname "$0")/.." && pwd)"
# corebase + Opal (and the packaged gnustep-gui) come from the Opal script; its demo is skipped by stopping after the libraries
sh "$WS/ci/opal-build.sh" >/tmp/opal-build.log 2>&1
tail -5 /tmp/opal-build.log
pkg install -y gnustep-gui mesa-libs libglvnd glew >/dev/null 2>&1
. /usr/local/GNUstep/System/Library/Makefiles/GNUstep.sh
cd /tmp/gs && git clone --depth 1 https://github.com/gnustep/libs-quartzcore qc 2>&1 | tail -1
cd qc
ls
gmake -j2 messages=yes 2>&1 | grep -E "error|Error|fatal|No such|undefined" | head -40
echo "== build done, libraries:"
ls Source/obj 2>/dev/null | head
find /tmp/gs/qc -name "libQuartzCore*" | head
