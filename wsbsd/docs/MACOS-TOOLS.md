# macOS command line tools: what applies to wsbsd
The list the project owner asked for (2026-10-29), sorted by what it takes. Each tool is a command of macOS that scripts, installers and applications call; ours must behave and print as on the Mac (the Mac is the oracle: compare outputs, as `defaults/test/compare.sh` does). Paths follow the path mirror (/usr/bin/<tool>, /usr/sbin/<tool>).
| Verdict | Meaning |
|---|---|
| DONE | in this repository |
| NEXT | applies and is needed soon (scripts, installers, apps or the settings panes depend on it) |
| LATER | applies, lower value or large |
| MAP | a thin layer over a FreeBSD tool or interface (the backend exists, the Darwin command line and output do not) |
| BSD | FreeBSD base already has a tool of the name (checked with `command -v` on the dev VM, 2026-10-29): behaviour is BSD's, wrappers only for the Darwin flags that something needs |
| DEV | toolchain for Mach-O files: LLVM under the Darwin names, not part of the running system |
| NA | Apple hardware / Mach / services with no equivalent: not implemented (a stub that says so when a script asks) |
Checked on the dev VM (FreeBSD 14, arm64) as already present: xattr, spctl (ours), xcrun, dtrace, audit / praudit / auditreduce / auditd, cupsfilter, lpstat, cupsenable / cupsdisable / cupsaccept / cupsreject, ippfind, banner, cal, sntp, ktrace, kdump, fstyp, top, mount_smbfs, nfsstat, showmount, pwd_mkdb, size, strings, strip, pagesize, route, pkill, pgrep, ipcrm, ipcs, getconf. Everything else of the list is absent.
Order of work (dependencies): defaults (done) -> cfprefsd + plutil -> notifyd -> pasteboard daemon (pbcopy, pbpaste) -> open + lsregister (LaunchServices) -> launchctl -> sw_vers, system_profiler, ioreg -> log / oslog -> screencapture, sips, caffeinate, pmset -> mdfind / mdls / mdutil (indexer) -> security, codesign -> actool / ibtool (building Cocoa apps) -> installer / pkgutil -> the MAP wrappers -> the DTrace scripts.

## User-space tools every script and application leans on

| Tool | Verdict | How, and what exists |
|---|---|---|
| `defaults` | DONE | `defaults/defaults.m`: read, read-type, write (all types), delete, rename, domains, find, import, export; output identical to macOS on `defaults/test/compare.sh`; installs as /usr/bin/defaults. Needs cfprefsd (change notifications) and the consumers of the keys (corner radius, sidebar) |
| `cfprefsd` | NEXT | daemon that watches ~/Library/Preferences and posts the change notification `com.apple.cfprefsd.domainChanged` (defaults already posts it); apps and the AppKit layer refresh from it |
| `plutil` | NEXT | -p, -convert xml1/binary1/json, -lint, -extract, -insert, -replace, -remove, -type; same plist code as defaults |
| `open` | NEXT | over LaunchServices: -a app, -b bundle id, -e, -t, -R reveal, -n, --args, URLs; asks the Dock/Finder (`com.wsbsd.dock.reopen` exists) and the launchd of the session |
| `pbcopy / pbpaste / pasteboard / pbtypes` | NEXT | a pasteboard daemon (NSPasteboard of GNUstep is per process): general, find, drag pasteboards; pbpaste -Prefer; the Finder and Terminal copy/paste go through it |
| `launchctl` | NEXT | over `launchd/launchd.m`: list, load/unload, start/stop, kickstart, bootstrap/bootout for the agents in /System/Library/LaunchAgents; print |
| `sw_vers` | NEXT | ProductName macOS-compatible, ProductVersion, BuildVersion from /System/Library/CoreServices/SystemVersion.plist (the image lacks it today) |
| `osascript` | LATER | AppleScript is a language of its own; JXA needs a JavaScript engine (JavaScriptCore is not here); start with `osascript -e 'tell application "X" to activate'` for the few commands that matter |
| `notifyutil / notifyd` | NEXT | notify(3) (notify_post, notify_register_*) over a local daemon; dozens of AppKit paths and shells use it |
| `lsregister / duti` | NEXT | tools of the LaunchServices database (`launchservices/`): register bundles, dump, set default handlers by UTI / extension |
| `xattr` | DONE | `iso/src/xattr.c` (quarantine and Finder info on the image); spctl is ours too (`iso/src/spctl.c`) |
| `spctl` | DONE | reports the assessments the image needs; no Gatekeeper behind it |
| `security` | NEXT | keychain command line over `Security` (sealed store): find-generic-password, add-generic-password, list-keychains, find-certificate, cms, verify-cert |
| `codesign` | LATER | -s - (ad hoc), -v, -d --entitlements, --remove-signature on ELF / bundles: a stamp and a verifier of our own format; real Apple signatures can be parsed (reading) but not trusted |
| `tccutil` | LATER | reset / list over a privacy database (apps ask for Camera, Microphone, Files); stub that records decisions |
| `csrutil` | LATER | `status` prints the state of SIP as the image defines it (the user asked to be told about SIP); enable/disable only edit a flag |
| `screencapture / screencaptureui` | NEXT | `wsshot` already grabs the screen: -x, -R x,y,w,h, -w (window), -c (to pasteboard), -t png/jpg/pdf, -i, -T delay; the UI part (Shift-Cmd-5) is an AppKit app |
| `say` | LATER | a wrapper over espeak-ng / flite (-v voice, -o file, -f file, -r rate); voices of the Mac are not available |
| `caffeinate` | NEXT | -d -i -m -s -u -t -w: holds an assertion (wsd screen saver / display sleep, acpi); pmset reads them |
| `pmset` | MAP | -g (battery: hw.acpi.battery.*, AC), -g assertions, displaysleep / sleep / disksleep settings kept in a plist, sleepnow = acpiconf -s 3, pmset -g batt |
| `sips` | NEXT | -g (get properties), -s format, -z height width, -Z, -r (rotate), -c, --out: images through ImageIO of the compat layer (Opal) with libpng / libjpeg / libtiff |
| `textutil` | LATER | -convert txt/html/rtf/rtfd/docx/odt/doc/webarchive, -cat, -info, -extract: over NSAttributedString (GNUstep has RTF and plain; HTML / docx need parsers) |
| `log` | NEXT | `log show / stream / collect / stats / config --predicate --last --style`: the unified log is syslog files on this system; a predicate evaluator over (process, subsystem, category, messageType, eventMessage) and a writer for os_log of the compat layer |
| `oslog` | NEXT | the same store (os_log API of the compat layer writes it) |
| `syslog / aslmanager` | MAP | syslog(1) of macOS (-w, -k queries) over FreeBSD's syslogd files; aslmanager prunes /var/log |
| `mdfind / mdls / mdutil` | NEXT | Spotlight command line over an indexer of our own (names, kind, dates, size, text of documents, kMDItem* attributes from file metadata); `topbar/Spotlight.m` searches names today. mdutil -s / -i on|off / -E; mdls prints kMDItem* from UTI, size, dates, xattrs |
| `qlmanage / qlcontroller` | MAP | -p (preview window), -t (thumbnail), -m: over `sdk/src/QuickLook.m` and the generators |
| `dscl / dsmemberutil / dscacheutil / odutil / scselect` | MAP | Directory Services over /etc/passwd, group and the master database (`dscl . -read /Users/root`, `-list /Users`, dsmemberutil checkmembership, dscacheutil -q user / group / host); nothing of Open Directory / LDAP |
| `system_profiler` | NEXT | SPHardwareDataType, SPSoftwareDataType, SPDisplaysDataType, SPStorageDataType, SPPowerDataType, SPNetworkDataType, SPUSBDataType, SPBluetoothDataType, -json / -xml / -detailLevel: sysctl, pciconf, usbconfig, devinfo, geom, acpiconf as sources; About This Mac and the Settings panes read it |
| `ioreg` | NEXT | the IORegistry as a tree from devinfo / pciconf / usbconfig / acpi: -l, -p IOService, -c class, -n name, -r, -w0; classes named as on the Mac (IOPlatformExpertDevice with model, serial from smbios, IOUSBHostDevice, IOPCIDevice, AppleSmartBattery) |
| `diskutil / hdiutil / drutil / diskarbitrationd` | MAP | diskutil list / info / mount / unmount / eject / eraseDisk / partitionDisk over geom, gpart, newfs, mount (plist output -plist); hdiutil attach / detach / create / verify / info for ISO and raw images (mdconfig) and for dmg (udif read-only via a decoder); drutil over cdcontrol; DiskArbitration shim exists in the compat layer |
| `scutil / networksetup` | MAP | scutil --dns, --proxy, --get/--set ComputerName / HostName / LocalHostName, -r reachability; networksetup -listallnetworkservices, -getinfo, -setairportnetwork, -setdnsservers, -setproxy...: ifconfig, wpa_supplicant, rc.conf, resolv.conf and our airportd as backends |
| `airport / wdutil / wifi-diagnostics` | NEXT | `airport -s / -I / -z / -c` and `wdutil info`: after CoreWLAN/airportd (the required project) they are a few hundred lines |
| `dns-sd` | MAP | FreeBSD's mDNSResponder package ships dns-sd; the Bonjour browsing of the Finder (Network) and AirDrop need the daemon anyway |
| `smbutil / mount_smbfs / mount_afp / afp_client / check_afp / smbdiagnose / nfsstat / showmount` | MAP | mount_smbfs and nfsstat / showmount exist in FreeBSD base (flags differ slightly); smbutil view / lookup / statshares over samba's smbclient; AFP is legacy: no |
| `softwareupdate` | LATER | -l / -i / --history: a stub that says the system is up to date until the image has an update channel |
| `nvram / bless / booter` | MAP | nvram -p / name=value over efivar (UEFI variables) and a file for the rest; bless --info / --setBoot / --mount over efibootmgr and the ESP of the image (`iso/`) |
| `kextstat / kmutil / kextload / kextunload / kextfind / kextcache / kextutil` | MAP | kldstat / kldload / kldunload under Darwin names (kextstat prints the loaded modules; kmutil showloaded); there are no .kext bundles |
| `hidutil` | MAP | `hidutil property --set` (key remapping: Caps Lock to Control) over the evdev layer of wsd (`src/input.c` keymap); list over usbconfig / devinfo |
| `vm_stat / hostinfo / memory_pressure / purge / pagesize / arch / machine` | MAP | vm_stat from vm.stats.*, hostinfo from sysctl, memory_pressure from vm.stats and the pager, purge = sync + drop caches, pagesize exists; `arch` and `machine` print arm64 / x86_64 and the Darwin-style names (FreeBSD's `machine` prints amd64 / arm64: wrapper) |
| `getconf / route / pkill / pgrep / ipcs / ipcrm / banner / cal / sntp / strings / size / strip / top / fstyp / ktrace / kdump / audit / praudit / auditreduce / auditd / pwd_mkdb / ippfind / cupsfilter / lpstat / cupsenable / cupsdisable / cupsaccept / cupsreject` | BSD | present in FreeBSD base or its cups package (checked on the dev VM): behaviour is BSD's; Darwin-specific flags and keys (getconf DARWIN_USER_DIR, `top` with Mach task columns, `cal` Darwin options, pgrep/pkill on Mach ports) go into wrappers when something needs them |

## Building and installing Cocoa software

| Tool | Verdict | How, and what exists |
|---|---|---|
| `actool` | NEXT | compile an .xcassets / .appiconset into Assets.car: the writer of the catalogue format (`coreui/` reads it); needed to build unmodified GitHub Cocoa apps (the stated goal) |
| `ibtool` | NEXT | compile .xib / .storyboard into .nib; `tools/nib2plist.py` reads compiled nibs, GNUstep loads nib plists: a compiler from the XML xib to what NSNib loads; also --print-hierarchy / --errors |
| `momc / mapc` | LATER | Core Data model compiler (.xcdatamodeld to .momd), mapping models: needs the model plist format of Core Data |
| `xcode-select / xcrun` | MAP | xcode-select -p / --install print a developer dir; a minimal `xcrun` exists on the dev VM (/usr/local/bin/xcrun: it only runs the command it is given; `--find`, `--sdk macosx --show-sdk-path` and `--show-sdk-version` fail): it must find clang and the sdk of this repository (`sdk/`) |
| `otool / lipo / vtool / dyld_info / atos / pagestuff / lookupsymbols / nmedit / segedit` | DEV | for Mach-O files (the Mac binaries we analyse with REA): LLVM's llvm-otool / objdump -macho, llvm-lipo, llvm-nm, llvm-strip under the Darwin names; nothing on the image runs Mach-O |
| `installer / pkgutil / xar / bom / mkbom / lsbom / ditto` | NEXT | `.pkg` files: xar (libxar), Bom (the file tree), payload (pbzx / cpio): `pkgutil --expand / --payload-files / --pkgs`, `installer -pkg X -target /` unpacking into the path-mirror layout; ditto (copy with resource forks / xattrs, -x -k zip) is small |
| `assetutil` | LATER | `assetutil -I Assets.car` = what `coreui/cardump` prints (JSON of renditions) |
| `stringdups / footprint / heap / leaks / vmmap / malloc_history / sample / spindump / tailspin / sysdiagnose / stackshot / procexp / zprint / ktrace(Darwin) / kdebug / fs_usage / sc_usage / latency` | LATER | introspection of a process: approximations over procstat -v, gdb / lldb, libmalloc statistics of the compat layer and DTrace (FreeBSD has dtrace and ktrace of its own; the Darwin tools are not wrappers of them); sample / spindump / fs_usage are the ones worth having |
| `dtrace / dtruss / opensnoop / iosnoop / execsnoop / bitesize.d / hotspot.d / filebyproc.d / procsystime` | MAP | dtrace is in FreeBSD base; the scripts are D programs over the syscall provider: port their probe names (`syscall::open*:entry`) once, they then run as on the Mac |
| `srm` | LATER | overwrite and remove (the Mac dropped it in 10.12): a small wrapper over `rm -P` |

## Hardware, security and management of Apple machines: nothing to implement here (or a stub that says so)

| Tool | Verdict | How, and what exists |
|---|---|---|
| `tmutil` | NA | Time Machine: no backup service, no APFS snapshots |
| `fdesetup / bioutil / bputil / firmwarepasswd / profiles / mdmclient / checkprivacy / authopen` | NA | FileVault, Touch ID, boot policy of Apple silicon, firmware password, MDM: no equivalent; `authopen` is trivial (opens a file for a client that lacks the right) and goes with `security` if something asks |
| `thermal / smc / powertrics / corecaptured / wdutil(logs) / mach_portal / launchproxy / warmd / taskgated / taskinfo / macerror` | NA | SMC and thermal pressure of Apple hardware, Mach ports, kernel daemons of macOS; `macerror` is a table of error codes (cheap) |
| `apfs / apfs_hfs_convert / mount_apfs / diskmanagementd / corestoraged / asr / vsdbutil` | NA | APFS, CoreStorage, Apple Software Restore: the image is UFS; read-only access to APFS volumes would be a project of its own |
| `sharing / sharingd` | LATER | AirDrop project (after CoreWLAN); `sharing -l` lists shares |
| `networkQuality` | LATER | needs Apple's responsiveness servers and protocol: only with a documented server |
| `podcast / pcast / shortcuts / bluetoothcmd / blueutil / filebyproc.d` | LATER | apps' command lines (Podcasts, Shortcuts) and third-party Bluetooth tools: with the apps; Bluetooth control needs the Bluetooth stack (hcidump / hccontrol on FreeBSD) |
| `locate.updatedb / launchpath / nvramdump` | LATER | trivial wrappers |

## The rest of the list

| Tool | Verdict | How, and what exists |
|---|---|---|
| `vifs` | LATER | edits /etc/fstab under a lock (`vipw` / `vi` + checks); FreeBSD's `vipw` is the model |
| `ioalloccount` | NA | counts IOKit object allocations of the Mac kernel |
| `gpt` | MAP | FreeBSD has `gpart`; the Darwin `gpt` (create, add, show, remove, label) is a thin wrapper over it |
| `nettop` | MAP | per-process network usage: `netstat` / `procstat` / `sockstat` are the sources; the curses UI is ours |
| `pstopdf` | MAP | over ghostscript (`ps2pdf`) or the PDF code of the compat layer |
| `fsevents` | LATER | FSEvents (the API the Finder lacks: it polls once a second): kqueue per directory under a daemon, `fseventsd`; the command line `fsevents` is a debugging aid |
| `digest` | BSD | FreeBSD has `sha256`, `md5`, `sha1`...; `digest -a md5` of Darwin is a wrapper |
