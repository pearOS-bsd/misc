# What the Dock of the Mac needs and offers (strings + load commands of Dock 26.7.2, and the lookups of the real Dock on the pearOS stack)

Source: `strings` of the x86_64 slice (REA/Ghidra for the symbols) + /tmp/launchd.log of the stack (tools/stack-dock-finder.sh = /root/run26.sh), where every
bootstrap look-up of the real Dock shows.  A kernel trace of the files is not possible (Mach-O syscalls go through darwinator; ktrace sees only the loader), so the files are
the static paths of the binary plus the frameworks it links.

## Mach services the Dock LOOKS UP (it is a client)
cfprefsd.daemon/agent, lsd.mapdb, lsd.modifydb, coreservices.launchservicesd, coreservices.appleevents, coreservices.sharedfilelistd.xpc, coreservices.lsbestappsuggestionmanager.xpc,
iconservicesagent, iconservices(.store), CARenderServer, windowserver.active, windowmanager(.server/.external/.app-service), wallpaper, runningboard, usernoted.dock, analyticsd, tccd.system,
DiskArbitration.diskarbitrationd, CoreServices.coreservicesd, carboncore.csnameddata, FSEvents, pasteboard.1, fonts, system.opendirectoryd.libinfo, system.notification_center, distributed_notifications,
containermanagerd, PowerManagement.control, SystemConfiguration.configd, metadata.mds(.legacy), bird(.token), pluginkit.pkd, extensionkit.pkd, quicklook.ThumbnailsAgent/QuickLookUIService,
uninstall.service, dmd.policy, backlightd, widget-observation, iohideventsystem, axserver, coredrag, notifyd.matching.

## Mach services the Dock PROVIDES (other programs look these up)
com.apple.dock.server (CoreDock API: tile size, magnification, orientation, hide, bounce, ...), dock.spaces, dock.fullscreen, dock.notificationcenter, dock.appstore, dock.spotlight,
dock.sidecar, dock.ppt, dock.remotedesktoppicture, com.apple.dock (the Dock's own).  Entitlements: com.apple.private.dock.{ppt,spaces,spotlight}.
Our Dock (GNUstep, wsd only) provides none of them.

## Strings that look like names (all com.apple.* in the binary; notifications / ids / services)
- com.apple.addressbook
- com.apple.appkit.disablemcexit
- com.apple.apps.launcher
- com.apple.appstoreagent.legacy
- com.apple.backup.launcher
- com.apple.chrono.controls
- com.apple.desktop.ready
- com.apple.display.reconfig
- com.apple.dock
- com.apple.Dock09
- com.apple.dock.add-item
- com.apple.dock.animation
- com.apple.dock.appstore
- com.apple.dock.autohide
- com.apple.dock.bounce-app-tile
- com.apple.dock.cas
- com.apple.dock.controls
- com.apple.dock.desktoppicture
- com.apple.dock.drag.ended
- com.apple.dock.drag.started
- com.apple.dock.ecap
- com.apple.dock.ecti
- com.apple.dock.external.extra.arm64
- com.apple.dock.external.extra.x86_64
- com.apple.dock.extra
- com.apple.dock.extra-background-task-item
- com.apple.dockfixup
- com.apple.dock.fullscreen
- com.apple.dock.helper
- com.apple.dock.hotcorner.updated
- com.apple.dock.iconcache
- com.apple.dock.launchpad
- com.apple.dock.m5
- com.apple.dock.notificationcenter
- com.apple.dock.ppt
- com.apple.DockPPT
- com.apple.dock.prefchanged
- com.apple.dock.remotedesktoppicture
- com.apple.dock.server
- com.apple.dock.sidecar
- com.apple.dock.spaces
- com.apple.dock.spotlight
- com.apple.dock.windowdrag.ended
- com.apple.dock.windowdrag.started
- com.apple.DownloadFileChanged
- com.apple.DownloadFileFinished
- com.apple.ec.appearance
- com.apple.ec.Application.open
- com.apple.ec.DesktopPicture.databaseFailure
- com.apple.ec.DesktopPicture.failure
- com.apple.ec.DesktopPicture.usage
- com.apple.ec.Dock.appExposeShown
- com.apple.ec.Dock.bindings
- com.apple.ec.Dock.commandTabShown
- com.apple.ec.Dock.desktopShown
- com.apple.ec.Dock.doubleClicked
- com.apple.ec.Dock.preferences
- com.apple.ec.Dock.stackOpened
- com.apple.ec.Dock.switchedDisplays
- com.apple.ec.Dock.windowMinimized
- com.apple.ec.Document.open
- com.apple.ec.Launchpad.appLaunched
- com.apple.ec.Launchpad.appsAdded
- com.apple.ec.Launchpad.databaseFailure
- com.apple.ec.Launchpad.groupMade
- com.apple.ec.Launchpad.initialImport
- com.apple.ec.Launchpad.reordered
- com.apple.ec.Launchpad.shown
- com.apple.ec.MissionControl.preferences
- com.apple.ec.MissionControl.shown
- com.apple.ec.TwoUpFullScreen.acceleratedAction
- com.apple.ec.TwoUpFullScreen.action
- com.apple.expose.awake
- com.apple.expose.front.awake
- com.apple.exposelauncher
- com.apple.finder
- com.apple.FinderInfo
- com.apple.HIToolbox.beginMenuTrackingNotification
- com.apple.HIToolbox.cancelMenuTrackingNotification
- com.apple.HIToolbox.endMenuTrackingNotification
- com.apple.ibooksx
- com.apple.ical
- com.apple.ichat
- com.apple.keychainaccess
- com.apple.launchpad.action
- com.apple.launchpad.changed
- com.apple.launchpad.launcher
- com.apple.launchpad.toggle
- com.apple.LaunchServices.applicationRegistered
- com.apple.loginwindow.logoutNoReturn
- com.apple.mac
- com.apple.pasteboard.promised-file-content-type
- com.apple.pasteboard.promised-file-url
- com.apple.print.printerproxy
- com.apple.private.dmd.policy
- com.apple.private.dock.ppt
- com.apple.private.dock.spaces
- com.apple.private.dock.spotlight
- com.apple.private.eyecandy.sysdiagnose
- com.apple.private.launchpad.list
- com.apple.private.notificationcenter
- com.apple.private.screen-time
- com.apple.private.tcc.allow0
- com.apple.private.wallpaper
- com.apple.private.windowmanager
- com.apple.progress.fractionCompleted
- com.apple.screenIsLocked
- com.apple.screenIsUnlocked
- com.apple.screensaver.action
- com.apple.shortcuts.droplet
- com.apple.showdesktop.awake
- com.apple.showdesktop.set
- com.apple.Siri
- com.apple.siri.launcher
- com.apple.spaces
- com.apple.SpacesTouchBarAgent
- com.apple.spotlight
- com.apple.springing.delay
- com.apple.springing.enabled
- com.apple.springing.prefchanged
- com.apple.system.loginwindow.logoutNoReturn
- com.apple.system.sessionagent.sessionstatechanged
- com.apple.systemuiserver
- com.apple.usernoted.dock
- com.apple.usernoted.isAlive
- com.apple.wallpaper
- com.apple.wallpaper.agent
- com.apple.window_proxies.startup
- com.apple.WindowServer.CGSWindow
- com.apple.workspaces.awake

## Preference keys it reads (com.apple.dock): tilesize, largesize, magnification, orientation, autohide (+ autohide-delay, autohide-time-modifier, autohide-immutable),
minimize-to-application, launchanim, show-process-indicators, mru-spaces, persistent-apps, persistent-others, recent-apps, mod-count, version, region, loc ... (the exact list: `strings Dock | grep -E '^(...)'`).
`version = 1` is required for the tiles to be built; the file is read through cfprefsd (root: /Library/Preferences).

## Paths in the binary
/System/Applications, /Applications, /Applications/Utilities, /System/Applications/Utilities, /Users/Shared, /Volumes, /System/Volumes/Data, /AppleInternal/Applications,
/System/Library/CoreServices/{Dock.app,Finder.app,SystemAppearance.bundle}, /System/Library/PreferencePanes/Expose.prefPane, /MissionControl/, debug: /tmp/DockLayerDump%f.caar.
Frameworks linked: SkyLight, QuartzCore, CoreUI, IconServices, IconFoundation, CoreServices, WindowManager(+ment), Wallpaper, DynamicDesktop, RunningBoardServices, TCC, DiskArbitration, IOKit,
MultitouchSupport, DFRFoundation, QuickLook, Sharing, Uninstall, UniversalControl, CoreAnalytics, ChronoServices, BackgroundTaskManagement, DesktopServicesPriv, SwiftUICore, Combine, RenderBox.

## What ours must do to be "the same" for the rest of the system (plan)
1. Honour the same preference keys and file (done for tilesize/persistent-apps; add largesize, magnification, orientation, autohide, show-process-indicators, minimize-to-application, launchanim, recent-apps, persistent-others).
2. The distributed notifications (com.apple.dock.* above: prefchanged, bounce-app-tile, add-item, drag.*, windowdrag.*, iconcache, launchpad ...): post and observe the same ones.
3. com.apple.dock.server: the CoreDock requests that programs make (the bridge: wsbridge-like service in the stack); minimal answers first (tile size, magnification, orientation, bounce, hide).
4. LaunchServices: running apps (the dot) from the same source (lsd / NSWorkspace notifications) and launching through `open`.
5. Icons: IconServices (the real stack) or the bundle icons (ours today).
