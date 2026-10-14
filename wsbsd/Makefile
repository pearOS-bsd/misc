# Portable: works with BSD make and GNU make.
CC      ?= cc
CFLAGS  ?= -O2 -g
CFLAGS  += -std=c99 -D_DEFAULT_SOURCE -D_BSD_SOURCE -Wall -Wextra -Iinclude
LDLIBS   = -lm
CORE     = src/compositor_sw.c src/server.c src/shadow.c src/region.c src/ipc.c src/evrec.c src/buffer.c
HDRS     = include/ws_gl.h include/ws_buffer.h include/ws_evrec.h include/ws.h include/ws_client.h include/ws_backend.h include/ws_ipc.h include/ws_region.h include/mach_compat.h include/sls_wire.h include/sls_msgids.h
OUT          = window
# set by the `kms` target
EXTRA_SRC    =
EXTRA_CFLAGS =
EXTRA_LIBS   =

all: wsd test_window test_compose test_region test_wire test_evrec test_buffer

wsd: $(CORE) $(EXTRA_SRC) src/wsd.c $(HDRS)
	$(CC) $(CFLAGS) $(EXTRA_CFLAGS) -o $@ $(CORE) $(EXTRA_SRC) src/wsd.c $(EXTRA_LIBS) $(LDLIBS)

test_window: src/client.c src/compositor_sw.c src/region.c src/ipc.c src/evrec.c src/buffer.c test/test_window.c $(HDRS)
	$(CC) $(CFLAGS) $(EXTRA_CFLAGS) -o $@ src/client.c src/compositor_sw.c src/region.c src/ipc.c src/evrec.c src/buffer.c test/test_window.c $(EXTRA_LIBS) $(LDLIBS)

test_compose: $(CORE) test/test_compose.c $(HDRS)
	$(CC) $(CFLAGS) -o $@ $(CORE) test/test_compose.c $(LDLIBS)

# FreeBSD display (DRM/KMS) and input (evdev): needs the libdrm package. UNTESTED, see docs/FREEBSD.md.
kms: clean
	$(MAKE) wsd test_window EXTRA_SRC=src/backend_kms.c EXTRA_CFLAGS="-DWS_KMS `pkg-config --cflags libdrm`" EXTRA_LIBS="`pkg-config --libs libdrm`"

test_region: $(CORE) test/test_region.c $(HDRS)
	$(CC) $(CFLAGS) -o $@ $(CORE) test/test_region.c $(LDLIBS)

test_buffer: src/buffer.c src/compositor_sw.c test/test_buffer.c $(HDRS)
	$(CC) $(CFLAGS) -o $@ src/buffer.c src/compositor_sw.c test/test_buffer.c $(LDLIBS)

test_evrec: src/evrec.c test/test_evrec.c $(HDRS)
	$(CC) $(CFLAGS) -o $@ src/evrec.c test/test_evrec.c $(LDLIBS)

test_wire: src/compositor_sw.c src/region.c src/ipc.c src/evrec.c src/buffer.c test/test_wire.c $(HDRS)
	$(CC) $(CFLAGS) -o $@ src/compositor_sw.c src/region.c src/ipc.c src/evrec.c src/buffer.c test/test_wire.c $(LDLIBS)

# GPU compositor (OpenGL ES 2 on EGL/GBM, Mesa): needs the mesa-libs and libdrm packages. UNTESTED, see docs/FREEBSD.md.
gl: clean
	$(MAKE) wsd test_window EXTRA_SRC=src/compositor_gl.c EXTRA_CFLAGS="-DWS_GL -DWS_GBM -DWS_EGL `pkg-config --cflags egl gbm glesv2`" EXTRA_LIBS="`pkg-config --libs egl gbm glesv2`"

# display, input and GPU compositor together
full: clean
	$(MAKE) wsd test_window EXTRA_SRC="src/backend_kms.c src/compositor_gl.c" EXTRA_CFLAGS="-DWS_KMS -DWS_GL -DWS_GBM -DWS_EGL `pkg-config --cflags libdrm egl gbm glesv2`" EXTRA_LIBS="`pkg-config --libs libdrm egl gbm glesv2`"

check: test_compose test_region test_evrec test_buffer wsd test_wire
	./test_compose
	./test_region
	./test_evrec
	./test_buffer
	sh test/run_wire.sh

# start wsd, draw the test window through the protocol, save window.ppm (window.png on macOS), stop wsd
demo: wsd test_window
	OUT="$(OUT)" sh test/run_demo.sh

clean:
	rm -f wsd test_window test_compose test_region test_wire test_evrec test_buffer out.ppm window.ppm window.png
