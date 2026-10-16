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

## Controls (measured on the real controls, dark appearance, colours are over the window colour W; `onBG(a)` = W lightened by a)
- Push button: capsule 24 pt high centred in a 32 pt frame, fill onBG(0.08) (pressed 0.21); default button accent (0,122,255), pressed (30,138,255). Light appearance: onBG with black, 0.075.
- Check box / radio: 16 pt, fill onBG(0.10) off; accent with white check / white 6 pt dot on; check box corner radius 4.
- Text field: 1 px border onBG(0.05), fill (23,24,25) (white in light), radius 6; the real field draws 1 px outside its frame (not reproducible inside the view).
- Search field: capsule, magnifier 14 pt at 8 pt from the left, clear button (grey 160 circle) 8 pt from the right.
- Slider: 6 pt capsule track onBG(0.12), accent before the knob, 20 pt knob (218,220,222) with a soft shadow.
- Progress bar: 8 pt capsule, track onBG(0.10), accent bar. Stepper: 20 x 24, radius 6, chevrons 5.3 pt from the middle round a hairline.
- Segmented control: container onBG(0.08), radius 6, the selected segment accent. Pop-up button: capsule onBG(0.08), title 12 pt from the left, two chevrons at the right.
- Tab view: capsule of tabs (selected onBG(0.20)) centred above a rounded content box (border onBG(0.12), fill onBG(0.035)). Group box: rounded panel onBG(0.035), title above it at the left.
- Scrollers: only a slim 7 pt knob (no arrows, no track), on the right. Table header: left aligned title and a 1 px hairline.
- Menu bar: GNUstep's Macintosh interface style (NSMenuInterfaceStyle) puts the menu in a bar across the top of the screen.
- Window colour: macOS tints the dark window colour with the wallpaper ((27,36,43) on the measured machine, (30,30,30) neutral); the light window colour is white (255).

## How the parity is checked
`uitest/` renders every control above in a fixed layout; `uitest/tools/compare.py` crops each control from the macOS and the wsd screenshot and prints the mean absolute difference per control plus a side-by-side sheet (left macOS, middle wsd, right difference). The floor is ~8 (font rendering: Inter instead of San Francisco, no ClearType-like smoothing match). `ksa/` does the same for a whole application (the Keyboard Setup Assistant panes).
