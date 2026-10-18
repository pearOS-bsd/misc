#!/bin/sh
# Builds GNUstep corebase (CoreFoundation) and Opal (CoreGraphics over Cairo) from source inside FreeBSD (the libraries only; opal-build.sh adds the demo).
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

