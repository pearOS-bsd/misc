# Terminal

A terminal emulator application written from scratch against the **public** Cocoa API, as a probe for the wsbsd stack: build it with GNUstep on FreeBSD, run it on `wsd`, and see what the
display server, AppKit and the graphics layers are missing for a real macOS application.

It is not a copy of Apple's Terminal.app: no Apple code or decompiled code is used. What was taken from the real application is its list of dependencies (below).

## Layout
- `src/vt.[ch]`: the VT100 / xterm emulator (cells, UTF-8, CSI / ESC / OSC, SGR with 256 and true colour, scroll regions, alternate screen, scrollback, resize) with no UI. `make test` runs `test/test_vt.c`.
- `src/pty.[ch]`: `forkpty` wrapper (login shell, `TERM=xterm-256color`).
- `src/TermView.[hm]`: the AppKit view: draws the cell grid, key handling (arrows, function keys, option as meta), mouse selection, copy / paste (bracketed), scroll wheel, resize.
- `src/main.m`: application, menu, window.
- `make mac` builds against Cocoa on macOS, `make gnustep` against GNUstep.

## What the real Terminal.app links against (`otool -L`, macOS 27)
Cocoa, AppKit, CoreText, CoreGraphics, QuartzCore (Core Animation), ColorSync, Carbon, ApplicationServices, CoreServices, CoreFoundation, Foundation, Security, AudioToolbox, CoreAudio,
DataDetectorsCore (private), CoreAnalytics (private), libncurses, libicucore, libScreenReader, the Swift runtime and several Swift overlays. Rendering goes through CoreText and Core Graphics
into layers; the window server sees layer-backed windows.

## What this exercise showed is missing
See `docs/GAPS.md`, updated as the application is run on wsd.
