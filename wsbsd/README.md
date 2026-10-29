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
- **Input:** evdev to macOS key codes and `CGEventFlags`, keyboard layouts through xkbcommon, pointer acceleration, wheel, tablets. **Touchpads** (an evdev device with absolute axes and `BTN_TOOL_FINGER`, `src/touchpad.c`): relative pointer motion, tap = left click, two-finger tap = right click, two-finger natural scroll, the pad's button as left (right with two fingers); a tablet or touch screen without `BTN_TOOL_FINGER` stays absolute. Unit-tested with synthetic events (`test/test_touchpad.c`); not yet tried on a real pad after the fix. Not done: tap-and-drag, three-finger gestures, palm rejection, pad speed setting.
- **Written but not verified on real hardware:** DRM/KMS and evdev backends, GBM/dma-buf, the OpenGL ES compositor (CI has no GPU).
- **UI parity with macOS** (the same Objective-C gallery rendered on both, mean absolute pixel difference per control, 0 to 255): dark appearance, most controls 4 to 12, the
  date picker 23; light appearance 4 to 16, the date picker 24. Much of what is left is the font (Inter, not San Francisco, which is not redistributable).

### Estimated coverage (updated 2026-10-29; a rough estimate, not a measurement; fidelity to the real thing is not measured per routine)
| Part | Estimate | Notes |
|---|---|---|
| SkyLight server routines (744) | ~74 % have a handler of their own, 192 only a generic acceptor | the handlers include replays of recorded replies; the share that is decompiled and verified is smaller (probably under half) |
| Quartz Compositor (window server composition) | ~35 to 40 % | windows, shadows, blur, warp are solid; colour management / HDR, general Core Image filters, Spaces / Mission Control / multi-display and real-GPU verification are mostly missing |
| AppKit (GNUstep with the wsd back-end and the macOS theme) | ~35 to 45 % for running real applications; 72.1 % of the SDK's selectors answered by the runtime with an implementation that does something (measured with `tools/appkit_probe.m`; the 142 methods that only answer (`WsdAppKitPlaceholder` categories) are not counted). Real since the last measurement: tracking areas, NSMenuItem (hidden, view, badge, section headers), NSGlassEffectView, SF Symbols as NSImage, NSWorkspace lookup / open configuration, NSTextView constructors and smart quotes, NSDocument duplicate / lock / move, NSViewController hierarchy and presentation, NSEvent local monitors, click / pan / press gesture recognizers, NSControl / NSMenu additions, each with a test in CI | looks and behaves like a Mac only in places (menus, Open / Save panels); SwiftUI and UIKit are out of scope for now |
| Core Animation (QuartzCore, own implementation) | ~50 % | layers, animations, timing curves, presentation tree, differential tests against a Mac; GPU-backed rendering, filters and many layer subclasses missing |
| Security / Keychain / Authorization | ~40 % | sealed AES-GCM store, SecItem, keys, certificates, SecTransform verify, Authorization; no Secure Enclave, no iCloud keychain, no trust evaluation against system roots (Pico 2 token planned) |
| QuickLook / CFPlugIn | ~55 % | generators, thumbnails, preview panel; no third-party generator ecosystem tested |
| Foundation networking (NSURLSession over libcurl) | ~45 % | data / download / upload tasks, delegates; no background sessions, no HTTP/3 |
| TextMate port (unmodified source) | ~55 % | builds, starts, real menus, gutter and layout, key input reaches the editor; the text of the editor is not drawn yet, no bundles shipped, WebKit is a stub |
| **CoreWLAN / airportd** | **~55 % (required, in progress)** | see "Required next" below |
| Finder (desktop and windows) | ~82 % | window, views (icon, list, columns, gallery), preview pane, menus, Get Info, Share, search, tags; missing: smart folder editor, drag to other applications, full move to NS* classes, ported logic from the decompiled methods |
| Dock | ~72 % | tiles, magnification, menus (NSMenu), Fan / Grid / List stacks measured on the Mac, hot corners, autohide; magnification curve re-checked (within 4 pt); missing: Spaces / Mission Control, list scrolling |
| Menu glass / materials | ~88 % | menu liquid glass fitted (blur, tone, per-edge lens, shadow, corner radius about 10 px as on the Mac); NSVisualEffectView materials measured (tint per material, blur sigma about 17); missing: specular at the corners compared like for like, adaptive brightness, GL shader run |
| Top bar, Control Center, Notification Center | ~58 % | Wi-Fi / Bluetooth / Sound / Display panels, notifications service end to end; missing: decompiled logic, Focus / Keyboard panels, real Bluetooth, notification actions |
| Bootable images (amd64, arm64) | ~82 % | one hybrid `.iso` per architecture (boots as a CD and, written with dd / Etcher, from a USB stick: tested as a USB disk in QEMU aarch64); Ploader vendored (`ploader/`) with the pear, boots without a menu; boot screen = the pear on black; desktop with demo content, launchd, guest tools (VMware, VirtualBox amd64); a real laptop boots it (the user's report of 2026-10-28: smooth), touchpad / Control Center effects / sound untested after the fixes |
| **Whole project, release target (Dock + glass + two images)** | **~82 %** | the rest (Spaces, decompiled Control Center, smart folders) is after the first release |

- **Pointer and window buttons (2026-10-29):** the arrow and the hand / cross / open / closed hand pointers are the Mac's pictures (measured), the traffic lights are the Mac's own renditions from `Aqua.car` (`WindowControlButtons`, with hover glyphs, a pressed state that swells and stretches slightly while dragged); keyboard shortcuts show the Mac's symbols and work (menu key equivalents validated against the key window, control-letter characters, caps lock).
- **Designer assets:** `tools/accept_assets.py` checks a delivery of replacement asset catalogues (`assets-designer/mod`) against the originals rendition by rendition (names, attributes, formats and, since 2026-10-28, the content). The first delivery (67 catalogues) passes the structure check but its pictures are byte-identical to the originals, so nothing is installed yet.

### Required next (decided by the project owner)
- **macOS command line tools** (`defaults`, `plutil`, `open`, `pbcopy`, `launchctl`, `log`, `mdfind`, `system_profiler`, `diskutil`, `screencapture`, `security`, ... about 250 names): the full list sorted by what applies, what FreeBSD already has and what makes no sense here is in `docs/MACOS-TOOLS.md`. Done: `defaults` (output identical to macOS on a comparison script, `defaults/`), `xattr`, `spctl`. Next: cfprefsd, plutil, notifyd, the pasteboard daemon, open / lsregister, launchctl, sw_vers, system_profiler, ioreg.
- **Touch Bar on real hardware** (backlog, not started): a MacBook Pro's bar is driven by the T1/T2 chip and appears to the OS as USB devices (display plus HID); Linux has drivers (t2linux), FreeBSD has none, and T2 Macs also control booting. Today `NSTouchBar` is drawn in an on-screen panel (emulation). The test laptops (Clevo, Yoga) have no Touch Bar.
- **CoreWLAN.framework** (`CWWiFiClient`, `CWInterface`, `CWNetwork`, `CWConfiguration`, `CWNetworkProfile`, events) and **airportd** (the daemon behind it): scanning, seamless joining of known
  networks, hotspot (Instant Hotspot / Personal Hotspot) detection. Method: decompile the real framework and daemon on this Mac with REA, reimplement them 1:1 (same classes, selectors, XPC
  protocol, error codes, notification names), differential tests against the real Mac, on FreeBSD over wpa_supplicant / `ifconfig wlan` / net80211. Status: 0 %.
  Plan: (1) REA inventory of CoreWLAN classes, airportd XPC interface and entitlements; (2) wire protocol and header set; (3) airportd on FreeBSD (wpa_supplicant control socket, scan cache, join, known networks, keychain-backed passwords); (4) framework with the exact API; (5) tests; (6) hotspot detection.
- **AirDrop** (sharingd, `NSSharingService` AirDrop, `com.apple.sharing.*`, AWDL-less transport on FreeBSD): after CoreWLAN, also by decompilation with REA and reimplemented as on the Mac. Reference to study (not to copy blindly): github.com/BenItBuhner/AirDrop-for-Everything. Status: 0 %.
- **Filesystem mirror rule:** the file layout of this Mac is the layout of the BSD system. Whatever exists under `/System`, `/Library`, `/usr/libexec`, `/Applications`... on the Mac (frameworks, daemons, launchd plists, resources) must be found at the same path on wsbsd, with the same names. New components are installed at the Mac paths (for example `/System/Library/Frameworks/CoreWLAN.framework`, `/usr/libexec/airportd`, `/System/Library/CoreServices/...`) and the ISO builder (`iso/build.sh`) places them there.

### Bug and feature checklist (owner's report from the arm64 image in QEMU and on real laptops, 2026-10-29)
Source: `buglist.txt`. `[ ]` = open, `[x]` = done and verified. Items marked *(partial)* have work in the tree that is not verified on an image yet.

**Desktop, menus and the top bar**
- [x] Right-click on a path bar item shows the Mac's menu (Open in New Tab / New Window, Show in Enclosing Folder, Get Info, Copy “name” as Pathname; read from the real Finder with AX).
- [x] Context menu of a desktop item flips to the left of the pointer at the right edge (verified in the dev VM).
- [x] Context submenus open beside their parent row (first row level with it), flip left at the screen edge and stay on screen (`WsdMenuBar.m`; verified in the dev VM).
- [x] The top bar never disappears: GNUstep ordered the main menu window out when the application deactivated (after choosing an item of a pop-up menu, or a click on the Dock, the bar was empty); the main menu window no longer hides on deactivate (`WsdMenuBar.m`). Verified in the dev VM; to confirm on the next image.
- [x] Command-Space opens Spotlight from any application (the back-end posts a notification, the top bar toggles the window). *(the window itself is the earlier measured one; the real Spotlight of this Mac (macOS 27: "Search or Ask" pill, inline completion, result panel) is not rebuilt yet)*
- [x] Spotlight: a click opens a result, the wheel scrolls, Return opens a directory (NSWorkspace asks the running Finder, or starts it on the folder).
- [x] The Dock has the "Apps" tile (second, as on the Mac); it opens the Applications window of macOS 27 (the Launchpad replacement), laid out from the real window's accessibility tree: search field, category chips, a grid of the installed applications, Command-1 from Spotlight opens it, its Back button returns to Spotlight (`topbar/Applications.m`). *(the real one also lists recents / sections and drag-to-Dock; the icons come from the bundles; Command-Space itself opens Spotlight as on this Mac)*
- [x] About This Mac is the real window's layout (accessibility tree of the Mac's: 280 x 503, picture, name, firmware product name, rows Processor / Memory / Startup disk / Serial number / system with this machine's values, More Info…, copyright); standard NSTextField / NSButton. *(the picture is a drawn laptop, not the Mac's artwork; the Regulatory Certification link is left out; "More Info…" opens System Information / System Settings when they exist)*
- [x] Force Quit Applications (Apple menu item and Command-Option-Escape): the window is laid out from the real one (accessibility tree of the Mac's dialog: 370 x 320, hint, list of running applications, note, default button "Force Quit" / "Relaunch" for the Finder), with a confirmation alert; standard NSTableView / NSButton (`topbar/ForceQuit.m`).
- [x] Icons are no longer upside down (the symbol fallback of images without `CoreGlyphs.car` did not mirror its paths in flipped views).
- [x] Control Center icons: the fallback has the symbols of every tile now (Wi-Fi, Bluetooth, Dark Mode, brightness, display, Focus, volume, media, battery, …). *(drawn from paths because the image has no SF Symbols catalogue; the shapes are approximations)*
- [x] Control Center: the Dark Mode tile (circle.lefthalf.filled) was invisible on images without the symbol catalogue; it shows now. *(confirm on an image)*
- [ ] Control Center: Wi-Fi has no real function. *(partial: the image now brings up every Wi-Fi card by itself, `iso/overlay/etc-rc.d-wsbsd_wifi`: drivers, a wlan per card, wpa_supplicant with the control socket, dhclient once associated; the Wi-Fi panel already joins through CoreWLAN / airportd; untested on hardware, firmware packages for Intel cards are not in the image)* The image must come configured to bring up any Wi-Fi card by default, and our menu must join networks, so nobody has to run `dhclient` and friends by hand. *(CoreWLAN / airportd work is in "Required next")*

**Windows, Dock and animations**
- [x] Closing the last window of the Terminal no longer quits it (Command-Q does). *(other applications: their own delegates; GNUstep apps that quit on the last window need the same check)*
- [x] Finder browser windows use the system decorations: a titled, full-size-content window whose buttons are drawn by the theme (`WsdTrafficOverlay` in `WsdMacTheme.m`: Aqua.car renditions, hover glyphs, rubber band, green-button popover) instead of the Finder's own copy. *(Get Info, Settings, copy and other Finder panels still carry the Finder's own trim)*
- [ ] The rubber-band (stretch) effect and the hover glyphs on close / minimize / maximize. *(partial: hover glyphs and the pressed state from `Aqua.car` exist; the stretch needs a finer capture on the Mac)*
- [ ] The green button must move the window to its own full-screen Space (workspace), as on the Mac; only snapping to the top edge maximizes the window. *(partial: the green button now takes the window to full screen (the area below the menu bar) and back; there are no Spaces: the other windows stay where they are, the Dock stays)*
- [x] Resting the pointer on the green button shows the tiling popover laid out from a capture of the real one: "Move & Resize" (left, right, top, bottom halves), "Fill & Arrange" (fill, two dimmed multi-window arrangements, quarters), "Full Screen"; the panel starts 27 pt left of the button. *(no arrow notch, no hover highlight; the quarters glyph tiles the top-left quarter; the arrangements of several windows are not implemented; the "Move to Display" row is left out on one screen)*
- [x] Window tiling by dragging a title bar to the screen edges (halves, quarters at the corners, top edge fills), with a translucent preview; a tiled window dragged away gets its old size back. Geometry measured on the Mac with Window > Move & Resize (below the 30 pt menu bar, above an 84 pt Dock, no margins). *(Option-drag, the Move & Resize menu and the hover popover of the green button are not done)*
- [x] Windows resize from every edge and corner, live, with plain events (`WsdResize.m`: no nested tracking loop; Finder and Terminal verified in the dev VM).
- [x] Resizing is live (the window is resized at every pointer event through `WsdResize.m`; no outline, no nested loop).
- [x] A lost button release can no longer leave a window stuck in a resize or a move: the next pointer motion without the button ends it (`WsdResize.m`). *(confirm on hardware)*
- [ ] Moving windows lacks vsync (a faint tearing effect, almost imperceptible). *(the images draw on the EFI / vt framebuffer, which has no vertical blank to wait for; vsync needs the KMS backend with a DRM driver (`gmake kms`: page flips are implemented, not verified on hardware))*
- [x] The Genie minimize / restore takes 0.30 s, measured on the Mac (a 60 fps capture of TextEdit minimizing: the mesh moves between 1.52 s and 1.82 s of the capture); a warped window gets no blur / glass at its unwarped rectangle (the blur spot). *(the easing curve is not measured: ours is linear in the mesh progress; not seen on an image)*
- [x] Clicking Downloads in the Dock no longer flickers: the Dock showed one frame with the new window size and the old picture (the bar's glass wider than its tiles); the new content is now drawn in the same turn as the new frame. *(seen in a capture sequence in the dev VM)*
- [x] The Dock resizes by dragging its separator up or down (the "tilesize" preference, 16 to 128, saved when the button is released). *(the factor between pointer travel and size is 1:1, not measured on the Mac)*
- [ ] Liquid Glass has an extra vertical offset: the lens samples the image too far away for the distortion.

**Quick Look, files and archives**
- [x] Quick Look closes with its X button (the title strip no longer swallows the press as a window drag). *(the panel is still drawn by the Finder; the window looks inactive behind it because the panel takes the key)*
- [x] Space starts Quick Look on a desktop item (the desktop's view is not in its icons' responder chain); a menu key equivalent that threw NSRangeException for the space bar swallowed the key in every application (`WsdMacTheme.m`).
- [x] With Quick Look open, selecting another item updates the panel (Finder windows and the desktop).
- [x] Double-clicking an archive (zip, tar, tgz, tar.gz / bz2 / xz) in a Finder window or on the desktop expands it as Archive Utility does: one top-level item expands to itself, anything else to a folder named after the archive, an existing name gets " 2" (`TFileOps.mm`, `tar` underneath).
- [x] Compress and expanding run on a background thread with the Finder's progress window (appears after 0.8 s, percentage, Stop). *(the window is the Finder's own drawing, not an NS progress indicator)*
- [ ] Finder window is incomplete (missing features; see the Finder row of the coverage table).
- [ ] `pkg` does nothing; it must be active and working so BSD utilities can be installed. *(partial: the image carries the real pkg-static as /usr/local/sbin/pkg, /usr/local gets a writable unionfs layer at boot (`wsbsd_overlay`), the repository is FreeBSD's; needs a network and has not been run on an image yet)*

**Terminal and shell**
- [x] The Terminal grid follows a resize at once (the title shows the new size; the shell gets SIGWINCH).
- [x] The Terminal title is "folder — process — columns×rows" and follows the shell's directory (OSC 7, else asked from the system); represented file set. The title bar shows the proxy icon of the shell's folder.
- [x] zsh is the login shell the Terminal starts (the user's passwd shell; root's is /bin/zsh in the image).
- [x] The zsh profile is pearOS's (`iso/overlay/etc-zshrc`, from Pear-Project/dpkg pearos-zshconfig: prompt, history, bindings, aliases, autosuggestions), plus an OSC 7 hook for the Terminal.

**Boot, installer and hardware**
- [ ] Boot logo: a real boot logo with a progress bar, exactly as on this Mac. *(partial: the window server now shows the pear on black with a rounded progress bar under it that fills with the time since it started (never full), until the desktop picture's window exists; the real boot of this Mac cannot be captured, so the size and position of the bar are estimates: measure them on a Mac boot with a camera / capture card; the pointer is still drawn on this screen)*
- [ ] Ploader shows rEFInd's default UI with missing icons instead of our Ploader interface, and still does not boot directly without Alt-M. *(partial: `ploader.conf` now scans only external / optical disks and prefers `EFISYS`; not confirmed on hardware)*
- [ ] Keyboard backlight driver for the NS50_70MU (Clevo) ported to BSD and working. *(partial: `kmod/clevo_wmi` is a FreeBSD ACPI-WMI driver after the Linux clevo-wmi / tuxedo-keyboard behaviour (`dev.clevo_wmi.0.kb_brightness`, Fn keys as events), loaded by `wsbsd_kbdlight` when the image has it; NOT run on the laptop: the command numbers need checking on the real machine with a DSDT dump; the build needs /usr/src/sys on the build machine; the Control Center Keyboard slider writes the sysctl)*
- [x] The Touch Bar emulation can be turned off (`WsbsdTouchBarEnabled` = NO in the global preferences, UITest's checkbox; `WSBSD_TOUCHBAR=0` as before). *(a switch in System Settings / the Control Center does not exist yet)*

**Login and users**
- [x] Login window with real accounts (`loginwindow/`: chooser of accounts, password checked with crypt(3), wrong password message, Restart / Shut Down) before the first unlock; Lock Screen (menu, ⌃⌘Q) puts it over the running session ("after the first unlock", the same account's password unlocks); Log Out ends the session and the login window returns; the rc script runs the desktop as the chosen account (CI runs sign alex in by themselves). *(the layout is not measured on a Mac: the real login window cannot be captured without signing out; dimming stands in for the blur; no fast user switching; unlocking is not enforced at the window server, the lock is a window at level 2000)*
- [x] The image has the account `alex` (password `pear`, groups wheel / operator / video, zsh, home /Users/alex) with sudo (`%wheel ALL=(ALL:ALL) ALL`) and doas configured. *(not built into an image yet)*

**Missing pieces**
- [ ] System components that still have to be decompiled from this Mac (list to be kept in `docs/`).
- [x] TextEdit (`../textedit`): window and formatting bar laid out from the real one (603 x 505, bar 36 high), the menu bar generated from the Mac's accessibility dump (`tools/gen_menu.py`; items without an action yet are disabled), new / open / save / save as for .txt and .rtf, Edit and Format actions that AppKit provides, plain / rich text, quit semantics as on the Mac. *(the ruler, lists, tables, find panel, versions, tabs and the Share items are not done; installed as /System/Applications/TextEdit.app by the image build, not yet run on an image)*
- [x] UITest: the combo box has items (First, Second, Third) and drops down. The image builds UITest without the Touch Bar stand-ins (the build with them crashed at start in a libobjc `objc_msgSend_stret` call from `-[NSView addSubview:positioned:relativeTo:]`: not investigated, the Touch Bar pages are for the dev build).
- [x] UITest: a second window "UI Test: System" with a Liquid Glass intensity slider (`/var/tmp/wsd-glass-intensity`, read by wsd once a second: scales the lens displacement), a Touch Bar emulation checkbox (`WsbsdTouchBarEnabled` in the global preferences, read by the Touch Bar host) and a Light / Dark switch (`AppleInterfaceStyle`).

**Resolved**
- [x] RAM use is stable at about 2 GB.
- [x] No more lag when using Control Center.

### Ported application work (TextMate, Chess, Hex Fiend, GrandPerspective, Pashua)
Goal: compile unmodified open source Cocoa applications on FreeBSD. What the TextMate port needed, all in `sdk/`, `ci/patch-*.py` and `ports/textmate/`:
- **Build:** ninja + rave build with an `xcrun` shim, ninja/rave bash-ism fixers, GNUstep-layout bundle assembly (`ports/textmate/`), libc++ hardening off, C++ `main` through a `gnustep_base_user_main` trampoline.
- **Auto Layout (libs-gui patches):** constraints kept for views without a window, VFL predicate connections, vertical axis as in Cocoa, `invalidateIntrinsicContentSize`, `view.constraints` = constraints the view owns, solver rebuilt after removals, scrollers without intrinsic size (this one gave the gutter 327 of 428 points), `menuNeedsUpdate:` re-entry guard. Tests: `sdk/tests/vfl_tests.m`.
- **Runtime:** libdispatch main queue and `CFRunLoopPerformBlock` run on the GNUstep run loop (`DispatchMain.m`), `CGEventRef` is a CF object, `NSTextInputContext handleEvent:` (typing), CF/CoreText/CoreGraphics header wrappers, CFString / CFAttributedString / CFURL bridges, `os_log`, process arguments, Apple-event classes, touch bar and accessibility shims, `NSURLSession` over libcurl, QuickLook + CFPlugIn, Security / Keychain / Authorization.
- **Debug aids:** `WSBSD_VIEWDUMP`, `WSBSD_LOGEVENTS`, `WSBSD_SNAPVIEW=Class`, `WSBSD_ALDEBUG`, `WSBSD_LOGEXC`.
- **State of TextMate:** builds, links, starts, shows its real menus, dialogs and window layout (gutter, text area, status bar), keys reach the editor and the buffer. Open: the text of the editor is not drawn yet (the layout is not told about buffer changes), no bundles shipped by `assemble.sh`, WebKit is a stub, bindings and `.tmplugin` loading.
- **ISO:** built from CI (`iso.yml`, manual run) and published as the `iso-latest` release; last build 2026-10-22, not tested by the author (a colleague tests it).
- **Backlog (not a priority):** research how an iOS session is started on macOS with the Xcode command line tools and whether a QEMU VM could boot iOS (reference: github.com/dipa-studio/ios-sweet).

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
| [GrandPerspective](https://github.com/mfcarroll/grandperspective) (2026 sources, 138 of 138 files, unmodified) | scans a folder and draws its treemap; menu bar, welcome window, folder picker, toolbar |
| [Pashua](https://github.com/BlueM/Pashua) (41 of 41 files, unmodified) | starts and builds its dialog (window size still wrong) |
| [Sloth](https://github.com/sveinbjornt/Sloth) (17 of 17 files, unmodified; built with `-Dproperties=wsbsd_properties`) | builds and links; exits at start: its views use Cocoa bindings (`NSTreeController`), which GNUstep lacks |

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
**Glass and blur cache (2026-10-28):** wsd keeps the result of every glass / blur region together with a hash of the backdrop pixels under it; when the backdrop is unchanged the result is copied back instead of recomputed (`src/blur.c`, `test/test_fxcache.c`: glass 6.05 ms to 0.32 ms, blur 1.1 ms to 0.13 ms on an M-class Mac). Before, every frame recomputed the lens and blur of the whole panel (the 360 x 660 Control Center dropped the frame rate below 9 fps on a real laptop). The Dock now redraws only when its tiles, hover or bar change (it asked for 60 frames a second forever), and the top bar only when the battery or the clock text changes. On the dev VM wsd idles at 0.2 % CPU; a tester's old image showed wsd at 75 %. Still open: `ps` is forked every 1.5 s by the Dock, the first frame after a backdrop change is as slow as before, no measurement on the real laptops yet.

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
