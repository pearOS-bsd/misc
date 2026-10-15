#!/bin/sh
# AppKit (GNUstep gui) on FreeBSD: build libs-back with a headless server first to see what the stack needs, then run a minimal AppKit program.
export IGNORE_OSVERSION=yes
pkg install -y gnustep-make gnustep-base gnustep-gui cairo freetype2 fontconfig git png jpeg-turbo tiff pkgconf gmake lcms2 bzip2 icu libffi dejavu autoconf libdispatch >/dev/null 2>&1 || true
cat > /usr/local/libdata/pkgconfig/bzip2.pc <<EOP
Name: bzip2
Description: bzip2
Version: 1.0.8
Libs: -lbz2
Cflags:
EOP
. /usr/local/GNUstep/System/Library/Makefiles/GNUstep.sh
mkdir -p /tmp/gs && cd /tmp/gs
git clone --depth 1 https://github.com/gnustep/libs-back back 2>&1 | tail -1
cd back
./configure --enable-server=headless --enable-graphics=headless 2>&1 | tail -4
gmake -j2 2>&1 | tail -6
gmake install 2>&1 | tail -3
ls /usr/local/GNUstep/System/Library/Bundles 2>&1 | head
cd "$GITHUB_WORKSPACE/wsbsd" 2>/dev/null || cd "$(dirname "$0")/.."
cc -o hello appkit/hello.m $(gnustep-config --objc-flags) $(gnustep-config --gui-libs) 2>&1 | tail -15
timeout 20 ./hello 2>&1 | tail -15
