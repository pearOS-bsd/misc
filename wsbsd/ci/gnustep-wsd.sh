#!/bin/sh
# AppKit (GNUstep gui) on wsd: builds libs-back with the "wsd" display server (appkit/back-wsd) in place of the headless one, then runs
# an AppKit program against a live wsd and takes a screenshot of the screen.
export IGNORE_OSVERSION=yes
pkg install -y gnustep-sudoku gnustep-back gnustep-make gnustep-base gnustep-gui cairo freetype2 fontconfig git png jpeg-turbo tiff pkgconf gmake lcms2 bzip2 icu libffi dejavu autoconf libdispatch python3 >/dev/null 2>&1 || true
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
# libs-gui from source: the packaged one is older than the libs-back it is paired with (window ordering never reached the server)
pkg install -y giflib >/dev/null 2>&1 || true
git clone --depth 1 https://github.com/gnustep/libs-gui gui 2>&1 | tail -1
(cd gui && ./configure CPPFLAGS="-I/usr/local/include" LDFLAGS="-L/usr/local/lib" 2>&1 | tail -3 && gmake -j2 GNUSTEP_INSTALLATION_DOMAIN=SYSTEM 2>&1 | grep -E "error|Error" | head -10; gmake install GNUSTEP_INSTALLATION_DOMAIN=SYSTEM 2>&1 | tail -2)
git clone --depth 1 https://github.com/gnustep/libs-back back 2>&1 | tail -1
cd back
mkdir -p Headers/wsd
cp "$WS"/appkit/back-wsd/*.h "$WS"/include/ws.h "$WS"/include/ws_client.h "$WS"/include/ws_buffer.h Headers/wsd/
cp "$WS"/appkit/back-wsd/*.m Source/headless/
# the wsd client library is compiled straight into the headless subproject (a static archive is not picked up by the bundle link)
for f in client compositor_sw region ipc evrec buffer; do cp "$WS/src/$f.c" Source/headless/wsc_$f.c; done
printf 'ADDITIONAL_INCLUDE_DIRS += -I%s/include\nADDITIONAL_CFLAGS += -std=gnu99 -D_DEFAULT_SOURCE\nheadless_C_FILES += wsc_client.c wsc_compositor_sw.c wsc_region.c wsc_ipc.c wsc_evrec.c wsc_buffer.c\n' "$WS" >> Source/headless/GNUmakefile.preamble
# headless server -> wsd server
sed -i '' 's/^HeadlessServer.m \\/HeadlessServer.m WsdServer.m WsdCairoSurface.m \\/' Source/headless/GNUmakefile
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
# the cairo makefile adds the Win32 surfaces for any server that is not x11 or wayland
sed -i '' 's/cairo_OBJC_FILES += Win32CairoSurface.m Win32CairoGState.m/cairo_OBJC_FILES += /' Source/cairo/GNUmakefile
./configure --enable-server=headless --enable-graphics=cairo 2>&1 | tail -5
gmake -j2 2>&1 | grep -E "error|Error|warning: implicit|undefined" | head -30
gmake install 2>&1 | tail -3
echo DIAG; pkg info gnustep-gui gnustep-base gnustep-make | grep -i '^Name\|^Version'; grep -n 'NSWindowAbove\|NSWindowBelow\|NSWindowOut' /usr/local/GNUstep/System/Library/Headers/AppKit/NSWindow.h /usr/local/GNUstep/System/Library/Headers/AppKit/AppKitDefines.h /usr/local/GNUstep/System/Library/Headers/AppKit/NSGraphics.h 2>/dev/null | head -5; ls Source/headless/obj/*/ 2>&1 | head -20; nm -D /usr/local/GNUstep/Local/Library/Bundles/libgnustep-back-032.bundle/libgnustep-back-032 | grep -c ws_; grep -n wsc_ Source/headless/GNUmakefile.preamble | cut -c1-150; echo ENDDIAG

cd "$WS"
cc -o hello appkit/hello.m $(gnustep-config --objc-flags) $(gnustep-config --gui-libs) 2>&1 | tail -15
cc -O1 -std=c99 -D_DEFAULT_SOURCE -Iinclude -o wsshot tools/wsshot.c /tmp/wsc/libwsclient.a -lm
cc -O1 -std=c99 -D_DEFAULT_SOURCE -Iinclude -o wsclick tools/wsclick.c /tmp/wsc/libwsclient.a -lm
cc -O1 -std=c99 -D_DEFAULT_SOURCE -Iinclude -o wskey tools/wskey.c /tmp/wsc/libwsclient.a -lm
gmake wsd 2>&1 | tail -2
export WS_SOCKET=/tmp/wsd-appkit.sock
./wsd -t -g 1280x800 >/tmp/wsd.log 2>&1 &
WP=$!
sleep 1
(WSD_DEBUG=1 timeout 60 lldb -b -o 'run -HelloSeconds 12' -o 'bt' -o 'quit' -- ./hello >/tmp/hello.log 2>&1) &
HP=$!
sleep 4
./wsshot appkit.ppm; python3 tools/ppm2png.py appkit.ppm appkit.png
./wsclick 180 554
sleep 1
./wsshot appkit-click.ppm; python3 tools/ppm2png.py appkit-click.ppm appkit-click.png
./wsclick 220 608
./wskey 0 11 8
sleep 1
./wsshot appkit-key.ppm; python3 tools/ppm2png.py appkit-key.ppm appkit-key.png
i=0; until grep -q 'frame after resize' /tmp/hello.log || [ $i -ge 30 ]; do sleep 1; i=$((i+1)); done; sleep 1
./wsshot appkit-resize.ppm; python3 tools/ppm2png.py appkit-resize.ppm appkit-resize.png
wait $HP
# a real, unmodified GNUstep application from the package repository
APP=$(find /usr/local/GNUstep -maxdepth 4 -name 'Sudoku.app' 2>/dev/null | head -1)
echo "sudoku app: $APP"
if [ -n "$APP" ]; then
	BIN="$APP/Sudoku"
	(WSD_DEBUG=1 timeout 40 lldb -b -o 'run' -o 'bt' -o 'quit' -- "$BIN" >/tmp/sudoku.log 2>&1) &
	SP=$!
	sleep 12
	./wsshot sudoku.ppm; python3 tools/ppm2png.py sudoku.ppm sudoku.png
	./wsclick 640 400; ./wsclick 20 700; sleep 1
	./wsshot sudoku-cell.ppm; python3 tools/ppm2png.py sudoku-cell.ppm sudoku-cell.png
	./wsclick 38 71; sleep 1
	./wsshot sudoku-menu.ppm; python3 tools/ppm2png.py sudoku-menu.ppm sudoku-menu.png
	kill $SP 2>/dev/null; pkill -f Sudoku 2>/dev/null
	grep -v '^(lldb)\|warning\|wsd-back: \(titlewindow\|setinput\|flush\|commit\|order\|ws_win\)' /tmp/sudoku.log | tail -30
fi
# a larger application built from source: Gorm, GNUstep's interface builder (panels, palettes, inspectors)
(cd /tmp/gs && git clone --depth 1 https://github.com/gnustep/apps-gorm gorm 2>&1 | tail -1 && cd gorm && grep -rl 6Formatters --include=GNUmakefile . | head -3 | xargs -I{} sed -i '' 's/6Formatters//' {}; gmake -j2 2>&1 | grep -E "error|Error " | head -8; gmake install 2>&1 | tail -2)
GAPP=$(find /usr/local/GNUstep /tmp/gs/gorm -maxdepth 5 -name 'Gorm.app' -type d 2>/dev/null | head -1)
echo "gorm app: $GAPP"
if [ -n "$GAPP" ]; then
	(WSD_DEBUG=1 timeout 60 lldb -b -o 'run' -o 'bt' -o 'quit' -- "$GAPP/Gorm" >/tmp/gorm.log 2>&1) &
	GP=$!
	sleep 25
	./wsshot gorm.ppm; python3 tools/ppm2png.py gorm.ppm gorm.png
	./wsclick 38 51; sleep 1
	./wsshot gorm-menu.ppm; python3 tools/ppm2png.py gorm-menu.ppm gorm-menu.png
	./wsclick 150 72; sleep 5
	./wsshot gorm-doc.ppm; python3 tools/ppm2png.py gorm-doc.ppm gorm-doc.png
	kill $GP 2>/dev/null; pkill -f Gorm 2>/dev/null
	grep -v '^(lldb)\|warning\|wsd-back: ' /tmp/gorm.log | tail -25
fi
kill $WP 2>/dev/null
grep -v '^(lldb)\|warning\|wsd-back: \(titlewindow\|setinput\|flush\|commit\|order\|ws_win\)' /tmp/hello.log | tail -40; tail -5 /tmp/wsd.log
ls -l appkit.png
