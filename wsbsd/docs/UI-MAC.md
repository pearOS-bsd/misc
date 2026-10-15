# macOS window look on wsd

Measured on a real macOS 27 (Darwin 27) machine with AppKit's own `NSWindow` (probe program, not decompiled code). Dark appearance.

## AppKit (client side, drawn in the app)
- NSThemeFrame → NSTitlebarContainerView (32 pt) → NSTitlebarView. `_cornerRadius` = 16, `_titlebarHeight` = 32.
- Traffic lights: 14 × 14 pt at x = 9, 32, 55 from the left, y = 9 from the title bar's bottom (centred). Close, minimise, zoom.
- Title: NSTextField 16 pt high at x = 82 (leading aligned after the buttons), font `.AppleSystemUIFaceHeadline` 13 pt (semibold), colour windowFrameTextColor.
- Title bar fill (dark, key window) (35,35,36); inactive (34,34,34). Content starts at y = 32 below the top. Button gradients (top, middle, bottom): close (247,94,85) (244,83,70) (239,104,97);
  minimise (251,180,1) (253,193,1) (254,207,48); zoom (51,194,1) (0,188,0) (78,194,58); inactive grey (76) (71) (67) with a lighter rim.
- Implemented in `appkit/back-wsd/WsdMacTheme.m` (a GSTheme + decoration view; `WSD_NO_MACTHEME=1` turns it off, `WSD_APPEARANCE=light` selects a typical light palette which was NOT measured).

## WindowServer (server side, drawn by wsd)
- Rounded corners radius 16.
- Shadow = gaussian of the window shape shifted down, fitted to captures: key window sigma 19, density 0.72, offset 19; non-key window sigma 19, density 0.41, offset 18.
- 1 px inner rim, white at 10 %.

## Not done
- Side/top edge resizing (only the bottom edge and corners resize, as GNUstep does), hover glyphs on the traffic lights, vibrancy of the title bar (a plain colour is used), San Francisco font (not redistributable: DejaVu / any free sans is used), toolbars and unified title bars, full-screen.
- The light appearance and app-inactive shadow (smaller than the non-key one) were not measured precisely.
