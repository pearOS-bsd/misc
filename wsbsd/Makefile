# Portable: works with BSD make and GNU make.
CC      ?= cc
CFLAGS  ?= -O2 -g
CFLAGS  += -std=c99 -D_DEFAULT_SOURCE -D_BSD_SOURCE -Wall -Wextra -Iinclude
LDLIBS   = -lm
CORE     = src/input.c src/keymap.c src/cursor.c src/fps.c src/compositor_sw.c src/blur.c src/server.c src/shadow.c src/region.c src/ipc.c src/evrec.c src/buffer.c
HDRS = include/ws_gl.h include/ws_buffer.h include/ws_evrec.h include/ws.h include/ws_client.h include/ws_backend.h include/ws_ipc.h include/ws_region.h include/mach_compat.h include/sls_wire.h include/sls_msgids.h src/wsd_priv.h src/sls_zero_ndr.h src/bplist.h
OUT          = window
# set by the `kms` target
EXTRA_SRC    =
FAMILIES     = src/sls_ext.c src/sls_session.c src/sls_sessctl.c src/sls_cursor.c src/sls_transition.c src/sls_batch2.c src/sls_window.c src/sls_tap.c src/sls_transaction.c src/sls_golden.c src/sls_blobs.c src/sls_display.c src/sls_display_tpl.c src/sls_harvest.c src/sls_generic.c src/sls_hotkey.c src/sls_hotkey_defaults.c src/sls_space.c src/bplist.c src/sandbox.c src/vnc.c
EXTRA_CFLAGS =
EXTRA_LIBS   =

all: wsd test_bplist test_window test_interactive test_robust test_compose test_region test_wire test_evrec test_buffer test_diff

wsd: $(CORE) $(EXTRA_SRC) $(FAMILIES) src/wsd.c $(HDRS)
	$(CC) $(CFLAGS) $(EXTRA_CFLAGS) -o $@ $(CORE) $(EXTRA_SRC) $(FAMILIES) src/wsd.c $(EXTRA_LIBS) $(LDLIBS) $$([ "$$(uname -s)" = Darwin ] || echo -lcrypto) -lz

test_interactive: src/client.c src/compositor_sw.c src/region.c src/ipc.c src/evrec.c src/buffer.c test/test_interactive.c $(HDRS)
	$(CC) $(CFLAGS) $(EXTRA_CFLAGS) -o $@ src/client.c src/compositor_sw.c src/region.c src/ipc.c src/evrec.c src/buffer.c test/test_interactive.c $(EXTRA_LIBS) $(LDLIBS)

test_generic: src/ipc.c test/test_generic.c $(HDRS)
	$(CC) $(CFLAGS) $(EXTRA_CFLAGS) -o $@ src/ipc.c test/test_generic.c $(LDLIBS)

test_input: $(CORE) test/test_input.c $(HDRS) include/ws_input.h
	$(CC) $(CFLAGS) -o $@ $(CORE) test/test_input.c $(LDLIBS)

test_fxcache: $(CORE) test/test_fxcache.c $(HDRS)
	$(CC) $(CFLAGS) -o $@ $(CORE) test/test_fxcache.c $(LDLIBS)

test_touchpad: $(CORE) src/touchpad.c test/test_touchpad.c include/ws_touchpad.h $(HDRS)
	$(CC) $(CFLAGS) -o $@ $(CORE) src/touchpad.c test/test_touchpad.c $(LDLIBS)

test_xkb: $(CORE) src/xkbmap.c test/test_xkb.c include/ws_xkb.h $(HDRS)
	$(CC) $(CFLAGS) $$(pkg-config --cflags xkbcommon) -o $@ $(CORE) src/xkbmap.c test/test_xkb.c $$(pkg-config --libs xkbcommon) $(LDLIBS)

soak: src/client.c src/compositor_sw.c src/region.c src/ipc.c src/evrec.c src/buffer.c test/soak.c $(HDRS)
	$(CC) $(CFLAGS) -o $@ src/client.c src/compositor_sw.c src/region.c src/ipc.c src/evrec.c src/buffer.c test/soak.c $(LDLIBS)

test_golden: src/ipc.c test/test_golden.c $(HDRS)
	$(CC) $(CFLAGS) $(EXTRA_CFLAGS) -o $@ src/ipc.c test/test_golden.c $(LDLIBS)

test_bplist: test/test_bplist.c src/bplist.c $(HDRS)
	$(CC) $(CFLAGS) $(EXTRA_CFLAGS) -Isrc -o $@ test/test_bplist.c src/bplist.c

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
	$(MAKE) wsd test_window EXTRA_SRC="src/backend_kms.c src/evdev.c src/touchpad.c src/vt_switch.c" EXTRA_CFLAGS="-DWS_KMS `pkg-config --cflags libdrm`" EXTRA_LIBS="`pkg-config --libs libdrm`"

# FreeBSD display without a GPU driver: the vt(4) framebuffer (EFI GOP / simplefb: a QEMU window, a UEFI machine without a KMS driver). Input: evdev. No libdrm needed.
fb: clean
	$(MAKE) wsd test_window EXTRA_SRC="src/backend_fb.c src/evdev.c src/touchpad.c src/vt_switch.c" EXTRA_CFLAGS="-DWS_KMS -DWS_FB"

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
	$(MAKE) wsd test_window EXTRA_SRC="src/backend_kms.c src/evdev.c src/touchpad.c src/vt_switch.c src/compositor_gl.c" EXTRA_CFLAGS="-DWS_KMS -DWS_GL -DWS_GBM -DWS_EGL `pkg-config --cflags libdrm egl gbm glesv2`" EXTRA_LIBS="`pkg-config --libs libdrm egl gbm glesv2`"

check: test_bplist test_input test_touchpad test_fxcache test_compose test_region test_evrec test_buffer test_diff wsd test_wire test_interactive test_robust test_golden test_generic test_props test_shim test_shim2 test_shim3 test_shim4 test_shim2
	$(MAKE) -C coreui check
	./test_input
	./test_touchpad
	./test_fxcache
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
	@if pkg-config --exists xkbcommon 2>/dev/null; then $(MAKE) test_xkb && ./test_xkb; else echo 'xkbcommon not found, skipping test_xkb'; fi
	./test_bplist
	sh test/run_one.sh test_props
	sh test/run_shim.sh test_shim shim_basic
	sh test/run_shim.sh test_shim2 shim_api2
	sh test/run_shim.sh test_shim3 shim_api3
	sh test/run_shim.sh test_shim4 shim_api4
	sh test/run_install.sh
	sh test/run_vnc.sh

PREFIX  ?= /usr/local
DESTDIR ?=
# install: the server, the tools, the client library and headers, the rc script, wsstart and the manual page
install: wsd tools_all
	install -d $(DESTDIR)$(PREFIX)/sbin $(DESTDIR)$(PREFIX)/bin $(DESTDIR)$(PREFIX)/include/wsbsd $(DESTDIR)$(PREFIX)/lib $(DESTDIR)$(PREFIX)/etc/rc.d $(DESTDIR)$(PREFIX)/share/man/man8
	install -m 0755 wsd $(DESTDIR)$(PREFIX)/sbin/wsd
	install -m 0755 wsspace wsshot wsclick wskey wsdrag wswins wsfps wsmove wscursor $(DESTDIR)$(PREFIX)/bin/
	sed 's|%%PREFIX%%|$(PREFIX)|g' dist/wsstart > $(DESTDIR)$(PREFIX)/bin/wsstart && chmod 0755 $(DESTDIR)$(PREFIX)/bin/wsstart
	sed 's|%%PREFIX%%|$(PREFIX)|g' dist/wsd.rc > $(DESTDIR)$(PREFIX)/etc/rc.d/wsd && chmod 0555 $(DESTDIR)$(PREFIX)/etc/rc.d/wsd
	install -d $(DESTDIR)$(PREFIX)/etc/xdg/fastfetch $(DESTDIR)$(PREFIX)/share/wsbsd $(DESTDIR)$(PREFIX)/etc/profile.d
	install -m 0644 dist/fastfetch.jsonc $(DESTDIR)$(PREFIX)/etc/xdg/fastfetch/config.jsonc
	install -m 0644 dist/neofetch.conf $(DESTDIR)$(PREFIX)/share/wsbsd/neofetch.conf
	install -m 0644 dist/wsd.sh $(DESTDIR)$(PREFIX)/etc/profile.d/wsd.sh
	sed 's|%%PREFIX%%|$(PREFIX)|g' man/wsd.8 > $(DESTDIR)$(PREFIX)/share/man/man8/wsd.8
	install -m 0644 include/ws.h include/ws_client.h include/ws_buffer.h include/ws_evrec.h include/ws_region.h include/ws_ipc.h include/sls_wire.h include/sls_msgids.h include/mach_compat.h include/SkyLight.h $(DESTDIR)$(PREFIX)/include/wsbsd/
	install -m 0644 libwsclient.a $(DESTDIR)$(PREFIX)/lib/libwsclient.a

VERSION ?= 0.1
# a relocatable tarball of the installed tree (stage with DESTDIR, tar with the prefix as root)
package:
	rm -rf stage && $(MAKE) install DESTDIR=$(CURDIR)/stage PREFIX=$(PREFIX)
	tar -czf wsbsd-$(VERSION)-$$(uname -s)-$$(uname -m).tar.gz -C stage .
	rm -rf stage

CLIENT_SRC = src/client.c src/compositor_sw.c src/region.c src/ipc.c src/evrec.c src/buffer.c
libwsclient.a: $(CLIENT_SRC) $(HDRS)
	for f in $(CLIENT_SRC); do $(CC) $(CFLAGS) -c -o $${f%.c}.client.o $$f || exit 1; done
	rm -f $@ && ar rcs $@ $(CLIENT_SRC:.c=.client.o)
wsshot: tools/wsshot.c libwsclient.a
	$(CC) $(CFLAGS) -o $@ tools/wsshot.c libwsclient.a $(LDLIBS)
wsclick: tools/wsclick.c libwsclient.a
	$(CC) $(CFLAGS) -o $@ tools/wsclick.c libwsclient.a $(LDLIBS)
wskey: tools/wskey.c libwsclient.a
	$(CC) $(CFLAGS) -o $@ tools/wskey.c libwsclient.a $(LDLIBS)
wsspace: tools/wsspace.c libwsclient.a
	$(CC) $(CFLAGS) -o $@ tools/wsspace.c libwsclient.a $(LDLIBS)
wsdrag: tools/wsdrag.c libwsclient.a
	$(CC) $(CFLAGS) -o $@ tools/wsdrag.c libwsclient.a $(LDLIBS)
wswins: tools/wswins.c libwsclient.a
	$(CC) $(CFLAGS) -o $@ tools/wswins.c libwsclient.a $(LDLIBS)
wsgrey: tools/wsgrey.c libwsclient.a
	$(CC) $(CFLAGS) -o $@ tools/wsgrey.c libwsclient.a $(LDLIBS)
wsfps: tools/wsfps.c libwsclient.a
	$(CC) $(CFLAGS) -o $@ tools/wsfps.c libwsclient.a $(LDLIBS)
wsmove: tools/wsmove.c libwsclient.a
	$(CC) $(CFLAGS) -o $@ tools/wsmove.c libwsclient.a $(LDLIBS)
wscursor: tools/wscursor.c libwsclient.a
	$(CC) $(CFLAGS) -o $@ tools/wscursor.c libwsclient.a $(LDLIBS)
tools_all: wsspace wsshot wsclick wskey wsdrag wswins wsfps wsmove wscursor

# start wsd, draw the test window through the protocol, save window.ppm (window.png on macOS), stop wsd
demo: wsd test_window
	OUT="$(OUT)" sh test/run_demo.sh

clean:
	rm -rf stage wsbsd-*.tar.gz; rm -f test_input test_touchpad test_fxcache libwsclient.a src/*.client.o wsshot wsclick wskey wsdrag test_generic wsd test_window test_interactive test_robust test_golden test_props test_shim test_compose test_region test_wire test_evrec test_buffer test_diff test_bplist out.ppm window.ppm window.png
