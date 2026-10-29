# System components still to decompile from the owner's Mac (macOS 27)

Method: REA (Ghidra) / the Objective-C runtime on this Mac, reimplement 1:1 (same classes, selectors, behaviours), measure the UI on the Mac, never copy binaries. Status 2026-10-29.

| Component | What is known | What is missing | Next step |
|---|---|---|---|
| WindowServer / SkyLight | wire protocol, ~270 of 728 routines with handlers (docs/SPEC-SLS-WIRE.md, skylight-*.txt) | the rest of the routines (192 generic acceptors), session switching as the Mac does it (CGSession) | continue the remaining-routines list |
| loginwindow + LoginUIKit | class inventory, control specs, view metrics (docs/loginwindow/); fast user switching modelled on the Mac's sessions | logic of `LUI2UIController` (wrong-password shake, hint, battery, Wi-Fi menu), `LFSMSession` state machine, FileVault users, Platform SSO, absolute positions of the real views | instantiate LUI2 view controllers offscreen in one test process and read their frames; decompile LUI2UIController with REA |
| CoreWLAN / airportd | docs/corewlan/ | scan / join paths on real cards, hotspot | after hardware test of the Wi-Fi image |
| AirDrop / sharingd | docs/airdrop/ | transport on FreeBSD, `NSSharingService` | decompile sharingd, then reimplement |
| Finder | docs/desktop/Finder.*.txt (classes, menus, actions, AX measurements) | smart folder editor (+/−), Customize Folder, Folder Actions Setup, Share rows, drag to other apps | `~/finder-decomp/out`: port the logic of the decompiled methods |
| Dock | measured geometry, genie 0.30 s | the real Dock's preferences / tile logic, Mission Control, Spaces strip | decompile Dock |
| SystemUIServer, Control Center, Notification Center | docs/desktop/ControlCenter.dyld_info-objc.txt, NotificationCenter..., SystemUIServer... | the decompiled logic of modules (Wi-Fi, Bluetooth, Focus, Fast User Switching module, Keyboard Brightness) | decompile ControlCenter modules one by one |
| Spotlight (spotlightd, Spotlight.app UI) | UI measured | the index and query engine | decompile SpotlightUI, reimplement over a FreeBSD index |
| usernoted / UserNotifications | service end to end | the real banner / list layouts | measure on the Mac |
| launchd | a launchd-compatible job runner for the LaunchAgents | the `gui/<uid>` domain model, `launchctl` | compare with `launchctl print` output |
| Menu Extras / Fast User Switching menu | the Mac shows the account in the menu bar when enabled | the module itself | decompile the UserSwitcher control center module |
| Spaces / Mission Control | full-screen spaces in wsd (green button) | Mission Control, ⌃← / ⌃→, desktops (Spaces) bar, slide animation | decompile the Dock's Mission Control and SkyLight space routines |
