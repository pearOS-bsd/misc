# Portable: works with BSD make and GNU make.
CC      ?= cc
CFLAGS  ?= -O2 -g
CFLAGS  += -std=c99 -D_DEFAULT_SOURCE -D_BSD_SOURCE -Wall -Wextra -Iinclude
LDLIBS   = -lm
CORE     = src/compositor_sw.c src/blur.c src/server.c src/shadow.c src/region.c src/ipc.c src/evrec.c src/buffer.c
HDRS = include/ws_gl.h include/ws_buffer.h include/ws_evrec.h include/ws.h include/ws_client.h include/ws_backend.h include/ws_ipc.h include/ws_region.h include/mach_compat.h include/sls_wire.h include/sls_msgids.h src/wsd_priv.h src/sls_zero_ndr.h src/bplist.h
OUT          = window
# set by the `kms` target
EXTRA_SRC    =
FAMILIES     = src/sls_ext.c src/sls_session.c src/sls_window.c src/sls_transaction.c src/sls_golden.c src/sls_blobs.c src/sls_display.c src/sls_display_tpl.c src/sls_harvest.c src/sls_generic.c src/sls_hotkey.c src/sls_hotkey_defaults.c src/sls_space.c src/bplist.c
EXTRA_CFLAGS =
EXTRA_LIBS   =

all: wsd test_window test_interactive test_robust test_compose test_region test_wire test_evrec test_buffer test_diff

wsd: $(CORE) $(EXTRA_SRC) $(FAMILIES) src/wsd.c $(HDRS)
	$(CC) $(CFLAGS) $(EXTRA_CFLAGS) -o $@ $(CORE) $(EXTRA_SRC) $(FAMILIES) src/wsd.c $(EXTRA_LIBS) $(LDLIBS)

test_interactive: src/client.c src/compositor_sw.c src/region.c src/ipc.c src/evrec.c src/buffer.c test/test_interactive.c $(HDRS)
	$(CC) $(CFLAGS) $(EXTRA_CFLAGS) -o $@ src/client.c src/compositor_sw.c src/region.c src/ipc.c src/evrec.c src/buffer.c test/test_interactive.c $(EXTRA_LIBS) $(LDLIBS)

test_generic: src/ipc.c test/test_generic.c $(HDRS)
	$(CC) $(CFLAGS) $(EXTRA_CFLAGS) -o $@ src/ipc.c test/test_generic.c $(LDLIBS)

test_golden: src/ipc.c test/test_golden.c $(HDRS)
	$(CC) $(CFLAGS) $(EXTRA_CFLAGS) -o $@ src/ipc.c test/test_golden.c $(LDLIBS)

test_props: src/client.c src/compositor_sw.c src/region.c src/ipc.c src/evrec.c src/buffer.c test/test_props.c $(HDRS)
	$(CC) $(CFLAGS) $(EXTRA_CFLAGS) -o $@ src/client.c src/compositor_sw.c src/region.c src/ipc.c src/evrec.c src/buffer.c test/test_props.c $(EXTRA_LIBS) $(LDLIBS)

test_shim: shim/skylight.c src/client.c src/compositor_sw.c src/region.c src/ipc.c src/evrec.c src/buffer.c test/test_shim.c test/shim_api.inc include/SkyLight.h $(HDRS)
	$(CC) $(CFLAGS) $(EXTRA_CFLAGS) -o $@ shim/skylight.c src/client.c src/compositor_sw.c src/region.c src/ipc.c src/evrec.c src/buffer.c test/test_shim.c $(EXTRA_LIBS) $(LDLIBS)

test_shim2: shim/skylight.c src/client.c src/compositor_sw.c src/region.c src/ipc.c src/evrec.c src/buffer.c test/test_shim2.c test/shim_api2.inc include/SkyLight.h $(HDRS)
	$(CC) $(CFLAGS) $(EXTRA_CFLAGS) -o $@ shim/skylight.c src/client.c src/compositor_sw.c src/region.c src/ipc.c src/evrec.c src/buffer.c test/test_shim2.c $(EXTRA_LIBS) $(LDLIBS)

test_shim3: shim/skylight.c src/client.c src/compositor_sw.c src/region.c src/ipc.c src/evrec.c src/buffer.c test/test_shim3.c test/shim_api3.inc include/SkyLight.h $(HDRS)
	$(CC) $(CFLAGS) $(EXTRA_CFLAGS) -o $@ shim/skylight.c src/client.c src/compositor_sw.c src/region.c src/ipc.c src/evrec.c src/buffer.c test/test_shim3.c $(EXTRA_LIBS) $(LDLIBS)

test_shim4: shim/skylight.c src/client.c src/compositor_sw.c src/region.c src/ipc.c src/evrec.c src/buffer.c test/test_shim4.c test/shim_api4.inc include/SkyLight.h $(HDRS)
	$(CC) $(CFLAGS) $(EXTRA_CFLAGS) -o $@ shim/skylight.c src/client.c src/compositor_sw.c src/region.c src/ipc.c src/evrec.c src/buffer.c test/test_shim4.c $(EXTRA_LIBS) $(LDLIBS)

test_robust: src/client.c src/compositor_sw.c src/region.c src/ipc.c src/evrec.c src/buffer.c test/test_robust.c $(HDRS)
	$(CC) $(CFLAGS) $(EXTRA_CFLAGS) -o $@ src/client.c src/compositor_sw.c src/region.c src/ipc.c src/evrec.c src/buffer.c test/test_robust.c $(EXTRA_LIBS) $(LDLIBS)

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

test_diff: $(CORE) test/test_diff.c $(HDRS)
	$(CC) $(CFLAGS) -o $@ $(CORE) test/test_diff.c $(LDLIBS)

test_evrec: src/evrec.c test/test_evrec.c $(HDRS)
	$(CC) $(CFLAGS) -o $@ src/evrec.c test/test_evrec.c $(LDLIBS)

test_wire: src/compositor_sw.c src/region.c src/ipc.c src/evrec.c src/buffer.c test/test_wire.c $(HDRS)
	$(CC) $(CFLAGS) -o $@ src/compositor_sw.c src/region.c src/ipc.c src/evrec.c src/buffer.c test/test_wire.c $(LDLIBS)

# GPU compositor (OpenGL ES 2 on EGL/GBM, Mesa): needs the mesa-libs and libdrm packages. UNTESTED, see docs/FREEBSD.md.
gl: clean
	$(MAKE) wsd test_window test_interactive test_robust EXTRA_SRC=src/compositor_gl.c EXTRA_CFLAGS="-DWS_GL -DWS_GBM -DWS_EGL `pkg-config --cflags egl gbm glesv2`" EXTRA_LIBS="`pkg-config --libs egl gbm glesv2`"

# display, input and GPU compositor together
full: clean
	$(MAKE) wsd test_window EXTRA_SRC="src/backend_kms.c src/compositor_gl.c" EXTRA_CFLAGS="-DWS_KMS -DWS_GL -DWS_GBM -DWS_EGL `pkg-config --cflags libdrm egl gbm glesv2`" EXTRA_LIBS="`pkg-config --libs libdrm egl gbm glesv2`"

check: test_compose test_region test_evrec test_buffer test_diff wsd test_wire test_interactive test_robust test_golden test_generic test_props test_shim test_shim2 test_shim3 test_shim4 test_shim2
	./test_compose
	./test_region
	./test_evrec
	./test_buffer
	./test_diff
	sh test/run_wire.sh
	sh test/run_interactive.sh
	sh test/run_robust.sh
	sh test/run_golden.sh
	sh test/run_one.sh test_generic
	sh test/run_one.sh test_props
	sh test/run_shim.sh test_shim shim_basic
	sh test/run_shim.sh test_shim2 shim_api2
	sh test/run_shim.sh test_shim3 shim_api3
	sh test/run_shim.sh test_shim4 shim_api4

# start wsd, draw the test window through the protocol, save window.ppm (window.png on macOS), stop wsd
demo: wsd test_window
	OUT="$(OUT)" sh test/run_demo.sh

clean:
	rm -f test_generic wsd test_window test_interactive test_robust test_golden test_props test_shim test_compose test_region test_wire test_evrec test_buffer test_diff out.ppm window.ppm window.png
