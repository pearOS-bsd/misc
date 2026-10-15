# Gaps found by running Terminal on wsd (updated as we go)
- `UniChar` is a CoreFoundation typedef, not in GNUstep's Foundation: use `unichar` (fixed in TermView.m).

## First run on wsd (FreeBSD, GNUstep AppKit, software compositor) — 2026-10-15
Works: window creation and resize, a login shell on a pty, 80x24 grid drawing with colours (SGR 16 / 256 / bold), cursor, keyboard input through the display server (`wskey`), the emulator
(`make test`), the menu, close box. Screenshot: `terminal.png` in the `freebsd-appkit-screenshot` CI artifact.

Differences from the macOS look and behaviour that this run shows:
- The menu is GNUstep's floating menu at the top-left, not a menu bar across the top of the screen (no `NSMenu` bar integration with the display server yet).
- A horizontal strip at the bottom of the window (GNUstep window decoration / resize bar): the client-side decorations are GNUstep's, not the macOS title bar with traffic lights, shadow and rounded corners.
- Text is drawn by GNUstep + Cairo + fontconfig (DejaVu); macOS applications draw through CoreText and Core Graphics, which have no implementation here (Opal covers part of Core Graphics).
- Not exercised yet: Core Animation layers (`wantsLayer`), `NSVisualEffectView` (the display server has blur but nothing asks for it through AppKit), IME / dead keys (the display server sends key codes, not translated characters), pasteboard between applications, drag and drop, tabs (`NSWindow` tabbing), full screen, fonts with ligatures (CoreText).

## What the real Terminal.app needs that this clean-room version does not use
CoreText layout (not NSString drawing), Core Animation for scrolling and the blur / vibrancy materials, DataDetectors (links in the text), Security (secure keyboard entry), ncurses terminfo handling,
the Swift runtime, AudioToolbox (the bell), and XPC / launch services for the shell profile machinery. Each is a future item for the Quartz / AppKit layers of the stack.
