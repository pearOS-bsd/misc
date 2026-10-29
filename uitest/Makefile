# Control gallery: every standard AppKit control in a fixed layout, the same Objective-C source for Apple's AppKit (make mac) and GNUstep on wsd (make gnustep).
# GNUstep build: build-gnustep.sh (BSD make and GNU make both run it): with WS, the wsbsd tree, the notification sender is built in.
# The app prints "CTRL <name> x y w h" (window content coordinates, origin top-left) so a comparison tool can crop every control from the two screenshots.
mac: UITest-mac
UITest-mac: src/main.m
	$(CC) -fno-objc-arc -Wno-deprecated-declarations -o $@ src/main.m -framework Cocoa
gnustep: UITest-gnustep
UITest-gnustep: src/main.m
	sh ./build-gnustep.sh "$(WS)" "$(COMPAT)"
clean:
	rm -rf UITest-mac UITest-gnustep obj
