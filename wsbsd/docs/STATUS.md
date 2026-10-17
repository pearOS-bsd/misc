# wsbsd status (2026-10-15)

What it is: `wsd`, a window server and compositor for FreeBSD that speaks the macOS WindowServer (SkyLight) wire protocol, plus a client library, test suites and the packaging around it.

## Numbers (approximate, from the repository)
- SkyLight server routines known from the macOS 27 decompile: 728. With a dedicated handler holding real state: 242 (33%). Answered from replies recorded on a real macOS 26 WindowServer: ~280.
  The rest are generated acceptors with the right sizes and a success reply.
- Differential runs against the real server (macOS 26 runner, `lab/state*.scen`, `lab/spaces*.scen`, `lab/wq*.scen`): state2 146/175 replies equal, state3a 100/111, state4 55/67; the differences are mostly macOS 26 vs 27
  (request sizes, ids the 26 server lacks) and routines the real server serves on another port.
- Tests: `make check` (wire conformance, golden replies from the real server, property / window / space / input suites, shim tests, install and VNC tests), a sanitizer fuzz job (random, size-exact, mutated requests), soak (`test/soak.c`).

## Works
Windows (create, move, resize, shapes, levels, ordering, groups, properties), spaces (basic), window rights and grants, tracking areas, event routing (mouse, keys, scroll, flags), input translation from evdev,
software and GL compositors with shadows, rounded corners, alpha and background blur, capture, cursor (images, scale, hide, lock, decouple), WindowQuery with names / displays, hot keys, shared memory regions.
Real applications on it: GNUstep AppKit programs (Sudoku, Gorm, the Terminal in `../terminal`), through the GNUstep back-end in `appkit/back-wsd`.

Hardening: Capsicum sandbox (`-S`), per-connection limits, peer credential check, 0600 socket, VT switching with input discarded on other consoles.
Product: `make install` / `make package`, rc.d script, `wsstart`, `wsd(8)`.

## Not done
- Routines needing more of the system: menu bar, display wall / HMD, selective sharing, capture streams, session management beyond the single session.
- Event taps: the registry is real (PlaceTap, PlaceTapOnConnection, Release, Enable, IsEnabled, GetEventTapList, timeout, option; `src/sls_tap.c`), but events are not handed to the tapping process (no tap reply port).
- Window transforms are rendered (software and GL, affine about the centre), CIColorInvert too; screen zoom only by the software compositor; other CIFilters are stored, not rendered; the cursor scale is.
- KMS / GPU paths compile and run in a VM (software and Mesa llvmpipe) but have never run on real hardware. The CI VM (FreeBSD 14.2 under QEMU) has a Virtio 1.0 GPU (VGA class) but no DRM driver for it: drm-kmod installs, `virtio_gpu` is not a loadable module and `/dev/dri` does not exist (checked in the freebsd-gl job), FreeBSD 15.0 under the same QEMU is the same (no virtio GPU DRM module either), so `-b kms` can only be exercised on real hardware.
- No Quartz (CoreGraphics / Core Animation) and no AppKit of Apple: no Cocoa application has run on it; the Terminal probe shows what is missing (`../terminal/docs/GAPS.md`).
- Version drift: ids and request sizes follow macOS 27, the recorded behaviour comes from macOS 26 (no macOS 27 runner exists yet).

## How to verify
`gmake && gmake check` (FreeBSD or macOS), CI in `.github/workflows/wsbsd.yml`, recordings in `docs/golden/`, scenarios in `lab/`.

## Core Animation over Opal (FreeBSD)
GNUstep QuartzCore (CALayer tree, implicit and explicit animations) renders into a wsd window through Opal (`demo/ca_demo.m`, CI job freebsd-quartzcore, screenshots ca-a/ca-b).
Pitfall found: Opal's CGBitmapContext assumes rows `width*4` bytes apart and ignores a padded bytesPerRow, while wsd buffers are padded to 128 bytes; draw into a tight buffer and copy the rows (the GNUstep back-end uses Cairo with the real stride and is not affected).
