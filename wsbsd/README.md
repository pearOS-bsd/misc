# wsbsd

A window server and compositor for FreeBSD (no X11, no Wayland) that speaks the **message layout of macOS's WindowServer (SkyLight)**, so that
clients written against that contract can be ported. Written in C99; the headless build runs on FreeBSD and macOS.

    gmake            # wsd, test_window and the tests  (make on macOS)
    gmake check      # compositor, region, event-record, buffer and wire-conformance tests
    gmake demo       # starts wsd, draws a test window through the protocol, writes window.ppm (+ window.png)
    gmake kms        # FreeBSD: DRM/KMS display and evdev input (libdrm)          UNTESTED
    gmake gl         # FreeBSD: OpenGL ES 2 compositor on EGL/GBM (Mesa)          UNTESTED on real hardware
    ./wsd -r gl      # use the GL compositor, falling back to software when EGL is unavailable

## Goal
Compile **unmodified open source macOS (Cocoa / AppKit) applications from GitHub** on FreeBSD and run them on this window server, looking like they do on a Mac.
Running prebuilt Apple binaries is not a goal. UIKit is out of scope; SwiftUI is a later target (on macOS it renders through AppKit).
The stack: `wsd` (this repo: window server and compositor speaking the SkyLight wire protocol) + GNUstep base / gui / back (a `wsd` backend, `appkit/back-wsd`)
+ Opal (Core Graphics) + a macOS-looking theme (`appkit/back-wsd/WsdMacTheme.m`, measured against a Mac, see `docs/UI-MAC.md`).

## Status
- **Window server:** the wire protocol for about 270 of the 728 SkyLight routines known from the macOS 27 decompile has real handlers with state (windows, spaces,
  displays, event taps including active key taps, hotkeys, menu bar, ...); most of the rest answer with replies recorded on a real WindowServer. Byte-exact layouts are
  checked against golden vectors from a live system. A software compositor does shadows, blur / vibrancy, rounded and shaped windows, resize.
- **Input:** evdev to macOS key codes and `CGEventFlags`, keyboard layouts through xkbcommon, pointer acceleration, wheel, tablets.
- **Written but not verified on real hardware:** DRM/KMS and evdev backends, GBM/dma-buf, the OpenGL ES compositor (CI has no GPU).
- **UI parity with macOS** (the same Objective-C gallery rendered on both, mean absolute pixel difference per control, 0 to 255): dark appearance, most controls 4 to 12, the
  date picker 23; light appearance 4 to 16, the date picker 24. Much of what is left is the font (Inter, not San Francisco, which is not redistributable).

### Applications that run today (CI, FreeBSD x86_64, software compositor)
| Application | What it exercises |
|---|---|
| `appkit/hello.m` | window, buttons, text |
| GNUstep Sudoku (`pkg`) | a stock GNUstep app: menus, document window, mouse |
| Gorm (built from source) | the GNUstep interface builder: palettes, inspectors, drag |
| `terminal/` (Terminal) | pty, text rendering, neofetch showing the Aqua desktop |
| `ksa/` (Keyboard Setup Assistant clone) | AppKit panes compared side by side with the Mac |
| `uitest/` (UI gallery) | 33 controls, alert, menu, vibrancy, light / dark |
| [Hex Fiend](https://github.com/HexFiend/HexFiend) (built by `tools/xcb`, unmodified but 4 Swift files in `ports/hexfiend/overlay`) | document windows, hex and ASCII columns, themes, dark appearance, resize cursors |
| [GrandPerspective](https://github.com/mfcarroll/grandperspective) (2026 sources, 138 of 138 files, unmodified) | starts: menu bar, welcome window, alerts, drive picker |
| [Pashua](https://github.com/BlueM/Pashua) (41 of 41 files, unmodified) | starts and builds its dialog (window size still wrong) |

The repository root `README.md` has the overview with screenshots; `ci/build-app.sh` builds any Xcode project this way.

### Unmodified open source Mac apps (survey, `ci/oss-probe.sh`)
Each repository is cloned as is and every Objective-C file is syntax-checked against the GNUstep headers with ARC (project headers are resolved by directory name, which is
not the same as a real Xcode build). Last run: 2026-10-17.

| Application | Files that compile as is | What stops the rest |
|---|---|---|
| [Hex Fiend](https://github.com/HexFiend/HexFiend) | 7 of 106 | in-project framework headers that an Xcode "copy headers" phase exposes (`<HexFiend/...>`); CoreFoundation types (`CFStringRef`, `CFArrayRef`, `kCFAllocatorDefault`); FSEvents; `NSAppleScript`; `NSClickGestureRecognizer`; `NSAlert.accessoryView`; `NSColor.linkColor` |
| [MacDown](https://github.com/MacDownApp/macdown) | 8 of 35 | CocoaPods dependencies (MASPreferences, HBHandlebars, GBCli, ...); WebKit; CFPreferences constants; `NSTextView insertText:replacementRange:`; `NSBezelStyle*`; attributed-string enumeration with blocks; `NSData base64Encoding`; `NSPasteboard canReadItemWithDataConformingToTypes:` |
| [Transmission](https://github.com/transmission/transmission) (macosx/) | 0 of 85 | `CoreFoundation/CFPlugInCOM.h` missing (no CoreFoundation in the stack) |

What the survey says is missing, most frequent first:
1. **CoreFoundation** (CFString / CFArray / CFPreferences / CFRunLoop types): GNUstep CoreBase is not part of the stack yet.
2. **Xcode project support:** the projects cannot be built as they are; a driver that reads `.xcodeproj` (header copy phases, targets, dependencies) is needed (candidate: xcbuild).
3. **AppKit APIs newer than OpenStep:** gesture recognizers, `NSTextInputClient` methods, `NSBezelStyle` names, `NSAlert.accessoryView`, system colours, `NSPasteboard` queries.
4. **System frameworks:** WebKit, FSEvents, AppleScript, XCTest (tests only).
5. **Dependencies:** CocoaPods / Carthage packages have to be fetched and built too.

### Performance
Same benchmark (`test/run_bench.sh`: cheap request round trip, resident size, one composed 1080p frame with 8 windows, shadows and blur) on three systems.
The FreeBSD numbers come from a GitHub Actions virtual machine, the Mac numbers from an Apple M1 that is not virtualised, so only the shape is comparable.

| | wsd on FreeBSD x86_64 (CI VM) | wsd on Apple M1 | macOS WindowServer (M1) |
|---|---|---|---|
| Round trip of a cheap request | 5.0 us (199,000 / s) | 6.6 us (151,000 / s) | 12.0 us (83,000 / s) |
| Resident size, idle | 7.1 MB | 1.9 MB | 63 MB (about 1 GB with graphics memory) |
| Resident size after 1000 connect / window / disconnect rounds | about 19.8 MB, flat | about 19 MB, flat | n/a |
| One composed 1080p frame (8 windows, shadows, blur) | 21.1 ms (software, one core) | 16.8 ms (software, one core) | on the GPU |
| CPU, idle | none measured in 3 s | none measured in 3 s | 49 to 67 % of a core |

The WindowServer transport is Mach IPC with audit checks, wsd uses Unix sockets, so the latency comparison says little about the architecture. The cost that matters is software
compositing: about 21 ms per 1080p frame on the CI VM is below 60 frames a second on one core; GPU composition (`gmake gl`, KMS) has not been verified on real hardware.

See `docs/DESIGN.md` (architecture and status), `docs/STATUS.md` and `docs/SPEC-SLS-WIRE.md` (the protocol facts, each tagged as decompiled, observed or inferred).

## Provenance
The protocol facts were obtained by analysing a macOS installation the author owns (decompilation with Ghidra through REA, and black-box probing
of public and private APIs on the running system) for the purpose of interoperability. No Apple code is included; the implementation is original.
The raw tables of Apple routine names and addresses are not published. Anyone redistributing or building on this should check the licence terms
that apply to them.


## Install and run

```
gmake                      # or: gmake kms / gmake gl / gmake full on FreeBSD with libdrm / Mesa
gmake check                # the whole test suite, including an install smoke test
doas gmake install         # PREFIX=/usr/local: wsd, wsshot/wsclick/wskey/wsdrag, wsstart, libwsclient.a + headers, rc.d script, wsd(8)
wsstart -- your-client     # a private server for this user, stopped when the client exits
```

As a service: `sysrc wsd_enable=YES wsd_user=alice wsd_flags="-b kms -r gl -S"` then `service wsd start`; clients find the socket through
`XDG_RUNTIME_DIR` (`/var/run/wsd/wsd.sock` with the rc script's defaults) or `WS_SOCKET`. See `man wsd` and `docs/FREEBSD.md`.

## Core Animation

`quartzcore/` is an implementation of QuartzCore that is checked value by value against Apple's own on a Mac (animations, implicit actions, rendering of scenes), with layer-backed `NSView`s, `NSAnimationContext` and `CAFilter` blur / colour filters. See [quartzcore/README.md](quartzcore/README.md).
