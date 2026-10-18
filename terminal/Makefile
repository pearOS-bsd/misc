# Terminal: make test (the emulator, no UI), make mac (Cocoa on macOS), make gnustep (GNUstep AppKit, e.g. on FreeBSD with the wsd display server)
CC ?= cc
SRC = src/vt.c src/pty.c

test: test/test_vt.c src/vt.c src/vt.h
	$(CC) -std=c99 -Wall -Wextra -o test_vt test/test_vt.c src/vt.c
	./test_vt

mac: Terminal-mac
Terminal-mac: $(SRC) src/TermView.m src/TermWindow.m src/TermProfile.m src/TermSettings.m src/TermInspector.m src/main.m src/TermView.h src/TermWindow.h src/TermProfile.h src/TermSettings.h src/TermInspector.h src/Profiles.inc
	$(CC) -fobjc-arc-weak -fno-objc-arc -o $@ $(SRC) src/TermView.m src/TermWindow.m src/TermProfile.m src/TermSettings.m src/TermInspector.m src/main.m -framework Cocoa -lutil 2>/dev/null || $(CC) -fno-objc-arc -o $@ $(SRC) src/TermView.m src/TermWindow.m src/TermProfile.m src/TermSettings.m src/TermInspector.m src/main.m -framework Cocoa

gnustep: Terminal-gnustep
Terminal-gnustep: $(SRC) src/TermView.m src/TermWindow.m src/TermProfile.m src/TermSettings.m src/TermInspector.m src/main.m src/TermView.h src/TermWindow.h src/TermProfile.h src/TermSettings.h src/TermInspector.h src/Profiles.inc
	$(CC) -o $@ $(SRC) src/TermView.m src/TermWindow.m src/TermProfile.m src/TermSettings.m src/TermInspector.m src/main.m `gnustep-config --objc-flags` `gnustep-config --gui-libs` -lopal -lgnustep-corebase -ldispatch -lutil

clean:
	rm -f test_vt Terminal-mac Terminal-gnustep
