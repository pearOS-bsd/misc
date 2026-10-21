# TextMate port (work in progress)

Build: `sh ports/textmate/build.sh` in the dev VM (needs `wsbsd` synced to `/root/wsbsd` and the compat library built: `sh sdk/build-compat.sh /root/compat`).
The ninja build files come from TextMate's own `bin/rave`; `ports/textmate/xcrun` stands in for Apple's `xcrun` (clang with the SDK flags of this stack, `ibtool` copies the xib, `codesign` does nothing).
Precompiled headers work once the SDK shims below exist.

## Done
SDK shims added for it (all in `sdk/`): copyfile(3), uuid, CommonCrypto digests, AudioToolbox alert, os_log / os_activity, AddressBook, ExceptionHandling, WebKit classes (no engine), Gestalt, AppleEvents types,
F_GETPATH, Authorization sets, keychain declarations, NSURL / NSImage / NSColor / accessibility additions, typed NSBezelStyle / NSButtonType. libs-gui patches: NSImage `template` bit field (C++ keyword).
The prelude headers (`Shared/PCH/prelude.{c,cc,m,mm}`) compile; 83 of ~850 build steps still fail (state of 2026-10-21, after the SDK shims listed above).

## Blockers (by module; those listed in the first version of this file that are now done: io, TMFileReference types, network proxies, AppleEvents descriptors, CFPreferences, link flags)
What is left is mostly Mac-only components: the QuickLook generator plugin, the privileged helper (launchd, Authorization rights), the license module (keychain items, SecTransform, CSSM), the updater (NSURLSession), and AppKit details in OakAppKit / FileBrowser / Preferences / Find / HTMLOutput (accessibility rotors, `NSRelativeDateTimeFormatter`, instance variables declared in categories, `NSURLSession`). Leaving those targets out of the app is the cheaper way to a first link.

## Earlier list
- io: `exchangedata`, `crt_externs.h`, FSEventStream API (`FSEventStreamScheduleWithRunLoop`, `FSEventStreamFlushSync`, `FSEventsGetCurrentEventId`), `POSIX_SPAWN_CLOEXEC_DEFAULT`, `MNT_DONTBROWSE`,
  `CFUserNotification` constants, `LSOpenURLsWithRole`, `_CS_DARWIN_USER_TEMP_DIR`, the Resource Manager and Launch Services types of `resource.cc` (`LSItemInfoRecord`, `ResType`, `FSPathMakeRef`), `NSFileManager replaceItemAtURL:...`.
- TMFileReference: `IconRef` / Icon Services (`kGenericDocumentIcon`, `initWithIconRef:`), `NSURLFileResourceType`.
- document / OakAppKit / FileBrowser / Preferences / Find: `NSView fittingSize`, `NSData enumerateByteRangesUsingBlock:`, `NSTitlebarAccessoryViewController`, `NSColorSpace sRGBColorSpace`, `NSWorkspace activateFileViewerSelectingURLs:`,
  `updateTrackingAreas`, `NSImageBinding`, `NSAccessibilityFrameInView`, `WebFrameView documentView`, instance variables declared in categories (`_tableView`, `_actionButton`), `invalidateRestorableState`.
- license / SoftwareUpdate / updater: keychain items and `SecItemImport` / `SecTransform` (declared, answer "not available"): these modules need a real key store.
- link: the rave link rule passes `-dead_strip`, `-dead_strip_dylibs`, `-cache_path_lto` and `-framework X`: the `xcrun` shim has to translate them (not done).
- runtime: WebKit (command output windows, about page), QuickLook, Services.
