# Control gallery: every standard AppKit control in a fixed layout, the same Objective-C source for Apple's AppKit (make mac) and GNUstep on wsd (make gnustep).
# On GNUstep with WS (the wsbsd tree) the notification sender is built in: the SDK's UserNotifications.m and XPC.m are compiled into the app (the whole compat library crashes the gallery at start, so it is not linked).
# The app prints "CTRL <name> x y w h" (window content coordinates, origin top-left) so a comparison tool can crop every control from the two screenshots.
mac: UITest-mac
UITest-mac: src/main.m
	$(CC) -fno-objc-arc -Wno-deprecated-declarations -o $@ src/main.m -framework Cocoa
gnustep: UITest-gnustep
UITest-gnustep: src/main.m
	$(if $(and $(WS),$(if $(COMPAT),,1)),mkdir -p obj && $(CC) -x objective-c -fobjc-arc -w -fblocks -I$(WS)/sdk/include -I/usr/local/include `gnustep-config --objc-flags` -c $(WS)/sdk/src/UserNotifications.m -o obj/un.o && $(CC) -x objective-c -fobjc-arc -w -fblocks -I$(WS)/sdk/include -I/usr/local/include `gnustep-config --objc-flags` -c $(WS)/sdk/src/XPC.m -o obj/xpc.o && $(CC) -x objective-c -fblocks -I$(WS)/sdk/include `gnustep-config --objc-flags` -c src/main.m -o obj/main.o && $(CC) -o $@ obj/main.o obj/un.o obj/xpc.o `gnustep-config --gui-libs` -L/usr/local/lib -ldispatch -lffi,$(CC) -o $@ src/main.m `gnustep-config --objc-flags` `gnustep-config --gui-libs` $(if $(COMPAT),-DUI_TB_BUILD -fblocks -I$(WS)/sdk/include -L$(COMPAT) -lwsbsdcompat -Wl$(comma)-rpath$(comma)$(COMPAT),))
comma:=,
clean:
	rm -rf UITest-mac UITest-gnustep obj
