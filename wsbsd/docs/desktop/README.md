# Finder and the desktop: inventory (2026-10-22)

Source: `/System/Library/CoreServices/Finder.app` of the reference Mac (macOS 27 beta, arm64e). Files here: `Finder.otool-ov.txt` (full Objective-C metadata dump), `Finder.classes.txt` (871 classes with superclass and method count), `Finder.linked-libraries.txt` (125 images), `Finder.Info.plist`, `Finder.entitlements.txt`.

Rule: Apple code rewritten by us is allowed, original Apple code and binaries are not. Finder installs at `/System/Library/CoreServices/Finder.app` like on the Mac.

## What the binary is
- 13 MB arm64e executable, `com.apple.finder`, document types for folders, volumes, saved searches, internet locations.
- 871 Objective-C classes, mostly Objective-C++: **791 start with `T`** (the old Finder core: `TBrowser*`, `TColumn*`, `TList*`, `TIcon*`, `TGallery*`, `TDesktop*`, `TInfo*` (Get Info), `TProperty*` (122, the property/attribute system behind columns and info panes), `TTag*`/`TTagging*`, `TPrivs*` (permissions), `TSidebar*`, `TQuick*`/`QL*`, `TPath*`, `TSearch*`, `TAir*` (AirDrop UI, 32), `TTouch*` (Touch Bar, 13), `TCloud*`, `TBackup*`), 30 `FI*` (newer Objective-C: `FIFinderView`, `FIContainerController`, `FILocationPopUp`, FinderSync host, tag editor), 28 `FE*`.
- Swift and SwiftUI parts (libswift* linked, AppIntents): Swift cannot be compiled on FreeBSD here, so these pieces are rewritten in Objective-C.
- Resources: 64 files, 5 nibs (the interface is mostly built in code), `FileSearch.appex`, LaunchAgent `com.apple.Finder.plist`.

## The 125 linked images by role
**Core (must be real):** AppKit, Foundation, CoreServices (LaunchServices, FSEvents, Metadata, FileMetadata), `DesktopServicesPriv` / `DesktopServicesUI` (the shared brain: `.DS_Store`, view options, icon positions, folder properties), `IconServices`, `CoreUI`, `QuickLook*`, `UniformTypeIdentifiers`, `DiskArbitration`, `DiskImages`, `DiskManagement`, `StorageKit`, `NetFS`, `Security*`, `SystemPolicy`, `SkyLight`, `ViewBridge`, `Sharing` / `SharingUI` (without AirDrop), `FinderSyncPriv` (Finder Sync extensions), `PlugInKit`, `FileProvider*`, `UserNotifications`, `UserManagement`, `SystemAdministration`, `SystemConfiguration`.

**Placeholders (must exist, answer OK or empty):** `CloudDocs`, `CloudKit`, `CloudSharing(UI)`, `iCloudQuota(UI)`, `AppleAccount`, `AOSAccounts`, `TimeMachine`, `Backup`, `SystemMigration`, `SidecarUI`, `DeviceDiscoveryUI`, `BiomeLibrary`, `BiomeStreams`, `Synapse`, `Suggestions`, `SmartNameSuggestions`, `CoreAnalytics`, `PerformanceAnalysis`, `FeedbackService`, `Ecosystem`, `VoiceShortcutClient`, `WidgetObservation`, `TimelineUI`, `UserActivity`, `SharedWithYou`, `Collaboration`, `ImageCaptureCore`, `SafariServices`, `CoreSpotlight`/`NaturalLanguage` (as far as Finder only asks).

**Already in our stack:** Core Graphics/Text (Opal, corebase), QuartzCore, Metal-free paths, Security, XPC.

## Order of work (bottom-up, each step testable against the Mac)
1. `FSEvents` + file metadata (`kMDItem*`, xattrs, quarantine) .
2. Launch Services: default application, Open With, document types, UTIs.
3. `IconServices` + `CoreUI`: icons for files, folders, volumes, badges.
4. `DesktopServicesPriv`: `.DS_Store` reader/writer, view options, folder properties, `FINode`-style model.
5. QuickLook (we have a part), Sharing without AirDrop, FinderSync.
6. Finder itself: windows, icon/list/column/gallery views, sidebar, toolbar, desktop, Trash, Get Info, search.

Method per step: REA inventory and decompilation, rewrite in our own code, differential probes against the real Mac, golden tests in CI.
