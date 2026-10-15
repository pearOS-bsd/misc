#!/bin/sh
# Builds GNUstep corebase (CoreFoundation) and Opal (CoreGraphics over Cairo) from source inside FreeBSD: the layer above SkyLight/wsd that a CoreGraphics demo needs.
set -x
export IGNORE_OSVERSION=yes
pkg install -y gnustep-make gnustep-base cairo freetype2 fontconfig git png jpeg-turbo tiff pkgconf gmake lcms2 bzip2 icu libffi >/dev/null 2>&1 || true
. /usr/local/GNUstep/System/Library/Makefiles/GNUstep.sh
mkdir -p /tmp/gs && cd /tmp/gs
git clone --depth 1 https://github.com/gnustep/libs-corebase corebase 2>&1 | tail -1
(cd corebase && ./configure 2>&1 | tail -5 && gmake -j2 2>&1 | tail -15 && gmake install 2>&1 | tail -3)
git clone --depth 1 https://github.com/gnustep/libs-opal opal 2>&1 | tail -1
(cd opal && gmake -j2 messages=yes 2>&1 | tail -40 && gmake install 2>&1 | tail -3)
ls /usr/local/GNUstep/System/Library/Libraries 2>&1 | head -30
