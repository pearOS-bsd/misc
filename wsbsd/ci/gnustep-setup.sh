#!/bin/sh
# (sourced) the GNUstep + wsd back-end build shared by gnustep-wsd.sh and vnc-session.sh
# AppKit (GNUstep gui) on wsd: builds libs-back with the "wsd" display server (appkit/back-wsd) in place of the headless one, then runs
# an AppKit program against a live wsd and takes a screenshot of the screen.
export IGNORE_OSVERSION=yes
pkg install -y neofetch gnustep-sudoku gnustep-back gnustep-make gnustep-base gnustep-gui cairo freetype2 fontconfig git png jpeg-turbo tiff pkgconf gmake lcms2 bzip2 icu libffi dejavu autoconf libdispatch python3 >/dev/null 2>&1 || true
cat > /usr/local/libdata/pkgconfig/bzip2.pc <<EOP
Name: bzip2
Description: bzip2
Version: 1.0.8
Libs: -lbz2
Cflags:
EOP
. /usr/local/GNUstep/System/Library/Makefiles/GNUstep.sh
WS="${GITHUB_WORKSPACE:-$(cd "$(dirname "$0")/../.." && pwd)}/wsbsd"
[ -d "$WS" ] || WS="$(cd "$(dirname "$0")/.." && pwd)"

# the wsd client library, position independent so the back bundle can link it
mkdir -p /tmp/wsc && cd /tmp/wsc
for f in client compositor_sw region ipc evrec buffer; do
	cc -O2 -fPIC -std=c99 -D_DEFAULT_SOURCE -I"$WS/include" -c "$WS/src/$f.c" -o $f.o || exit 1
done
ar rcs libwsclient.a *.o

mkdir -p /tmp/gs && cd /tmp/gs
# Inter (SIL OFL, rsms/inter): the free face closest to San Francisco, used as the GNUstep default font by the macOS-style theme
mkdir -p /usr/local/share/fonts/inter /tmp/inter
(fetch -qo /tmp/inter.zip https://github.com/rsms/inter/releases/download/v4.0/Inter-4.0.zip && tar -xf /tmp/inter.zip -C /tmp/inter && cp /tmp/inter/extras/ttf/Inter-Regular.ttf /tmp/inter/extras/ttf/Inter-Medium.ttf /tmp/inter/extras/ttf/Inter-SemiBold.ttf /tmp/inter/extras/ttf/Inter-Bold.ttf /usr/local/share/fonts/inter/ 2>/dev/null && fc-cache -f >/dev/null 2>&1) || echo 'Inter font download failed'
fc-list | grep -ci inter | sed 's/^/FONT: inter faces installed: /'
# libs-gui from source: the packaged one is older than the libs-back it is paired with (window ordering never reached the server)
pkg install -y libxkbcommon xkeyboard-config >/dev/null 2>&1 || pkg install -y libxkbcommon >/dev/null 2>&1 || true
echo "xkb: $(pkg info -e libxkbcommon && echo installed || echo MISSING) $(pkg-config --cflags xkbcommon 2>&1)"
pkg install -y giflib >/dev/null 2>&1 || true
git clone --depth 1 https://github.com/gnustep/libs-gui gui 2>&1 | tail -1
(cd gui && ./configure CPPFLAGS="-I/usr/local/include" LDFLAGS="-L/usr/local/lib" 2>&1 | tail -3 && gmake -j2 GNUSTEP_INSTALLATION_DOMAIN=SYSTEM 2>&1 | grep -E "error|Error" | head -10; gmake install GNUSTEP_INSTALLATION_DOMAIN=SYSTEM 2>&1 | tail -2)
git clone --depth 1 https://github.com/gnustep/libs-back back 2>&1 | tail -1
cd back
mkdir -p Headers/wsd
cp "$WS"/include/ws_xkb.h "$WS"/include/ws_input.h Headers/wsd/ 2>/dev/null; cp "$WS"/appkit/back-wsd/*.h "$WS"/include/ws.h "$WS"/include/ws_client.h "$WS"/include/ws_buffer.h Headers/wsd/
cp "$WS"/appkit/back-wsd/*.m Source/headless/
# the wsd client library is compiled straight into the headless subproject (a static archive is not picked up by the bundle link)
for f in client compositor_sw region ipc evrec buffer keymap xkbmap; do cp "$WS/src/$f.c" Source/headless/wsc_$f.c; done
printf 'ADDITIONAL_INCLUDE_DIRS += -I%s/include\nADDITIONAL_CFLAGS += -std=gnu99 -D_DEFAULT_SOURCE\nheadless_C_FILES += wsc_client.c wsc_compositor_sw.c wsc_region.c wsc_ipc.c wsc_evrec.c wsc_buffer.c wsc_keymap.c wsc_xkbmap.c\nADDITIONAL_CFLAGS += -DWSD_XKB -I/usr/local/include $(shell pkg-config --cflags xkbcommon)\nADDITIONAL_LDFLAGS += -L/usr/local/lib -lxkbcommon\n' "$WS" >> Source/headless/GNUmakefile.preamble
# the asset catalogue reader (SF Symbols' vector glyphs for the file panels): coreui/car.c, bvg.c and the LZFSE decoder it uses, compiled into the same subproject
mkdir -p Source/headless/lzfse; cp "$WS"/coreui/lzfse/*.h Source/headless/lzfse/; cp "$WS"/coreui/lzfse/*.h Source/headless/; cp "$WS"/coreui/car.h "$WS"/coreui/bvg.h Source/headless/
cp "$WS"/coreui/car.c Source/headless/cu_car.c; cp "$WS"/coreui/bvg.c Source/headless/cu_bvg.c; cp "$WS"/coreui/bitmap.c Source/headless/cu_bitmap.c
for f in lzfse_decode lzfse_decode_base lzfse_fse lzvn_decode_base; do cp "$WS/coreui/lzfse/$f.c" Source/headless/cu_$f.c; done
printf 'headless_C_FILES += cu_car.c cu_bvg.c cu_bitmap.c cu_lzfse_decode.c cu_lzfse_decode_base.c cu_lzfse_fse.c cu_lzvn_decode_base.c\nADDITIONAL_LDFLAGS += -lm\n' >> Source/headless/GNUmakefile.preamble
# headless server -> wsd server
sed -i '' 's/^HeadlessServer.m \\/HeadlessServer.m WsdServer.m WsdCairoSurface.m WsdMacTheme.m WsdCGBridge.m WsdFilePanel.m \\/' Source/headless/GNUmakefile
printf '\nWsdFilePanel.m_FILE_FLAGS = -fobjc-arc\n' >> Source/headless/GNUmakefile                  # the file panel is written for ARC
sed -i '' 's/HeadlessServer/WsdServer/g; s#<headless/WsdServer.h>#<wsd/WsdServer.h>#' Source/GSBackend.m
python3 - <<PY
p='Source/cairo/CairoContext.m'
s=open(p).read()
s=s.replace('#else\n#  error Invalid server for Cairo backend','#elif BUILD_SERVER == SERVER_headless\n#  include "wsd/WsdServer.h"\n#  include "cairo/CairoGState.h"\n#  include "wsd/WsdCairoSurface.h"\n#  define _CAIRO_GSTATE_CLASSNAME CairoGState\n#  define _CAIRO_SURFACE_CLASSNAME WsdCairoSurface\n#else\n#  error Invalid server for Cairo backend',1)
open(p,'w').write(s)
p='Source/GNUmakefile.preamble'
s=open(p).read()
s+='\nADDITIONAL_INCLUDE_DIRS += -I$WS/include\n'
open(p,'w').write(s)
PY
# a bitmap of 3 samples in 32 bits per pixel (RGB and an unused byte: what GrandPerspective's tree image is) has no alpha: the unused byte must not become transparency
python3 - <<PY2
p='Source/cairo/CairoGState.m'
s=open(p).read()
old="                                        | (*dataPixel & 0xFF00FF00);        // A_G_ -> A_G_\n"
new="                                        | (*dataPixel & 0xFF00FF00);        // A_G_ -> A_G_\n              if (!hasAlpha) reformattedDataPixel[-1] |= 0xFF000000;   // the fourth byte is padding, not alpha\n"
assert old in s
s=s.replace(old,new,1)
open(p,'w').write(s)
PY2
# the cairo makefile adds the Win32 surfaces for any server that is not x11 or wayland
sed -i '' 's/cairo_OBJC_FILES += Win32CairoSurface.m Win32CairoGState.m/cairo_OBJC_FILES += /' Source/cairo/GNUmakefile
./configure --enable-server=headless --enable-graphics=cairo 2>&1 | tail -5
gmake -j2 > /tmp/back-build.log 2>&1; grep -E "error|Error|warning: implicit|undefined" /tmp/back-build.log | head -30; grep -B1 -A4 "error:" /tmp/back-build.log | head -40
gmake install 2>&1 | tail -3
echo DIAG; pkg info gnustep-gui gnustep-base gnustep-make | grep -i '^Name\|^Version'; grep -n 'NSWindowAbove\|NSWindowBelow\|NSWindowOut' /usr/local/GNUstep/System/Library/Headers/AppKit/NSWindow.h /usr/local/GNUstep/System/Library/Headers/AppKit/AppKitDefines.h /usr/local/GNUstep/System/Library/Headers/AppKit/NSGraphics.h 2>/dev/null | head -5; ls Source/headless/obj/*/ 2>&1 | head -20; nm -D /usr/local/GNUstep/Local/Library/Bundles/libgnustep-back-032.bundle/libgnustep-back-032 | grep -c ws_; grep -n wsc_ Source/headless/GNUmakefile.preamble | cut -c1-150; echo ENDDIAG

