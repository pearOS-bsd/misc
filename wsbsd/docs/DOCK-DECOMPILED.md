# Dock of macOS 26.7.2 — numbers from the decompile (x86_64 slice, Ghidra via REA)

Goal: wsbsd/dock (our Dock) 1:1 with the Dock of the Mac.  Method: the slice is cut from /System/Library/CoreServices/Dock.app/Contents/MacOS/Dock
(python: fat header -> x86_64 slice), opened in REA (Ghidra; needs a thin slice), symbols are kept (DockBar::, DOCKTileLayer::, DOCKIndicatorLayer::...).
Apple files stay in the session's temp folder, never in the repo; only the numbers below are written down.

Big classes: `DockBar` (322 methods; layout/magnification/floor), `DOCKTileLayer` (tile art, glass chicklet, labels), `DOCKLabelLayer`,
`DOCKIndicatorLayer`, `DockGlassMaterial{Environment,LayerController,LayoutConfiguration}` (the Liquid Glass shelf and chicklets), `DockBarMouseEventHandler`.

## Done
- Running-app indicator (`DOCKIndicatorLayer::updateIndicatorForSize:` 0x100011d43): tile size >= 33 -> bounds 4 x 4, corner radius 2.0; below 33 -> 3 x 3, radius 1.5.  (Ours: a 4 px dot: ok for the default size.)
- Tile layout frame (`DOCKTileLayer::_computeLayoutFrameFromBounds:` 0x10011c472): the image layer is the tile bounds inset by `tileInset` on every side (size - 2 * tileInset);
  by bar orientation (`barOrientation` 0 = bottom, 1 = left, 2 = right) the origin gets extra tileInset on the sides and, when the 'floor' flag (FUN_100165863) is set, 5 pt (right side)
  or -5 pt (bottom / left) on the axis towards the screen edge.

## To read next (one per tick)
1. `DockBar::setTileInset:` callers: the value of tileInset per tile size.  2. barWidth / destinationBarWidth / barLeft / barRight: bar geometry, shelf height, margins.
3. Magnification curve (`DockBar::updateWithContext:...` 0x100108ab2 is 2349 lines of pseudo code: filter it with python for the constants).  4. DOCKLabelLayer (font, padding, radius, offset above the tile).
5. DockGlassMaterialLayoutConfiguration / LayerController: the glass of the shelf and of the chicklets (what wsd's glass modes must reproduce).  6. Trash tile (empty / full art), separator, recents.
