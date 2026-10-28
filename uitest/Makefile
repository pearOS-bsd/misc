# Control gallery: every standard AppKit control in a fixed layout, the same Objective-C source for Apple's AppKit (make mac) and GNUstep on wsd (make gnustep).
# The app prints "CTRL <name> x y w h" (window content coordinates, origin top-left) so a comparison tool can crop every control from the two screenshots.
mac: UITest-mac
UITest-mac: src/main.m
	$(CC) -fno-objc-arc -Wno-deprecated-declarations -o $@ src/main.m -framework Cocoa
gnustep: UITest-gnustep
UITest-gnustep: src/main.m
	$(CC) -o $@ src/main.m `gnustep-config --objc-flags` `gnustep-config --gui-libs` $(if $(COMPAT),-DUI_TB_BUILD -fblocks -I$(WS)/sdk/include -L$(COMPAT) -lwsbsdcompat -Wl$(comma)-rpath$(comma)$(COMPAT),)
comma:=,
clean:
	rm -f UITest-mac UITest-gnustep
