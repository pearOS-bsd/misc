# Keyboard Setup Assistant (behaviour recovered from Apple's app with REA; the code is new Objective-C written against the public Cocoa API only):
# the same sources build against Apple's AppKit (make mac) and GNUstep (make gnustep, on wsd).
SRC = src/main.m
CFLAGS_MAC = -fno-objc-arc -fobjc-exceptions -Wno-deprecated-declarations
mac: KeyboardSetupAssistant-mac
KeyboardSetupAssistant-mac: $(SRC) src/ksa.h
	$(CC) $(CFLAGS_MAC) -o $@ $(SRC) -framework Cocoa

gnustep: KeyboardSetupAssistant-gnustep
KeyboardSetupAssistant-gnustep: $(SRC) src/ksa.h
	$(CC) -o $@ $(SRC) `gnustep-config --objc-flags` `gnustep-config --gui-libs`

clean:
	rm -f KeyboardSetupAssistant-mac KeyboardSetupAssistant-gnustep
