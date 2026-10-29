#!/bin/sh
# Builds the ISO. Run as root on FreeBSD (CI: vmactions/freebsd-vm), from the repository:  sh wsbsd/iso/build.sh
#   OUT=dir               where the ISO goes (default wsbsd/iso-out)
#   PLOADER_DIR=dir       the Ploader build (ploader_x64.efi, theme/, drivers_x64/): from the `ploader` job of .github/workflows/iso.yml
#   SKIP_SOFTWARE=1       the software (GNUstep stack, wsd, apps) is already built and installed under /usr/local
# The result: macbsd-<arch>.iso, UEFI, Ploader first, FreeBSD's loader without screens, then the window server.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"; WS="$(cd "$HERE/.." && pwd)"
ARCH="$(uname -p)"; case "$ARCH" in amd64) EFINAME=BOOTX64.EFI; PLNAME=ploader_x64.efi; RELDIR=amd64 ;; aarch64) EFINAME=BOOTAA64.EFI; PLNAME=ploader_aa64.efi; RELDIR=arm64/aarch64 ;; *) echo "unsupported $ARCH"; exit 1 ;; esac
# the base of the image: a newer 14.x than the build machine is fine (what is built here runs on later 14.x); override with FREEBSD_RELEASE
REL="${FREEBSD_RELEASE:-14.5-RELEASE}"
WORK="${WORK:-/tmp/isowork}"; ROOT="$WORK/root"; OUT="${OUT:-$WS/iso-out}"
export IGNORE_OSVERSION=yes GITHUB_WORKSPACE="${GITHUB_WORKSPACE:-$(dirname "$WS")}"
mkdir -p "$WORK" "$OUT"; [ -d "$ROOT" ] && chflags -R noschg,nouchg "$ROOT" 2>/dev/null; rm -rf "$ROOT"; mkdir -p "$ROOT"

echo "== 1. the software"
pkg info -e zsh >/dev/null 2>&1 || pkg install -y zsh >/dev/null 2>&1 || true
pkg info -e sudo >/dev/null 2>&1 || pkg install -y sudo >/dev/null 2>&1 || true
pkg info -e zsh-autosuggestions >/dev/null 2>&1 || pkg install -y zsh-autosuggestions >/dev/null 2>&1 || true
if [ -z "$SKIP_SOFTWARE" ]; then
	pkg install -y python3 gmake pkgconf git >/dev/null 2>&1 || true
	sh "$WS/ci/gnustep-setup.sh" > "$WORK/gnustep.log" 2>&1 || { tail -30 "$WORK/gnustep.log"; exit 1; }
	sh "$WS/ci/opal-build.sh" > "$WORK/opal.log" 2>&1 || true      # the script ends with a demo that is not needed here; the libraries are checked below
fi
. /usr/local/GNUstep/System/Library/Makefiles/GNUstep.sh
for need in /usr/local/GNUstep/System/Library/Libraries/libgnustep-gui.so.0.32 /usr/local/GNUstep/System/Library/Libraries/libgnustep-base.so.1.31 /usr/local/GNUstep/Local/Library/Libraries/libgnustep-corebase.so.0 /usr/local/GNUstep/Local/Library/Libraries/libopal.so.0; do
	[ -f "$need" ] || { echo "missing after the software build: $need"; ls /usr/local/GNUstep/System/Library/Libraries /usr/local/GNUstep/Local/Library/Libraries 2>&1 | head -20; tail -20 "$WORK/gnustep.log" "$WORK/opal.log" 2>/dev/null; exit 1; }
done
(cd "$WS" && gmake fb >/dev/null && install -d /usr/local/sbin && install -m 755 wsd /usr/local/sbin/wsd && gmake wsshot wsclick wskey wsdrag wswins wsfps wsmove wscursor >/dev/null && install -d /usr/local/bin && install -m 755 wsshot wsclick wskey wsdrag wswins wsfps wsmove wscursor /usr/local/bin/)
(cd "$WS/src" && for f in client compositor_sw region ipc evrec buffer; do cc -O2 -fPIC -std=c99 -D_DEFAULT_SOURCE -I"$WS/include" -c $f.c -o "$WORK/ws_$f.o"; done; cc -shared -o /usr/local/lib/libwsclient.so "$WORK"/ws_*.o -lm)
sh "$WS/sdk/build-compat.sh" "$WORK/compat" > "$WORK/compat.log" 2>&1; install -m 755 "$WORK/compat/libwsbsdcompat.so" /usr/local/lib/libwsbsdcompat.so; install -m 755 "$WORK/compat/libQuartzCore.so" /usr/local/lib/libQuartzCore.so
# Wi-Fi: CoreWLAN, CoreWiFi and airportd, laid out as on the Mac (installed below under /System and /usr/libexec)
sh "$WS/sdk/build-corewlan.sh" "$WORK/cw" > "$WORK/corewlan.log" 2>&1; sh "$WS/sdk/build-airportd.sh" "$WORK/cw" >> "$WORK/corewlan.log" 2>&1; [ -x "$WORK/cw/usr/libexec/airportd" ] || { echo "airportd did not build"; tail -20 "$WORK/corewlan.log"; exit 1; }
# notifications: usernoted (the daemon) and wsnotify (a command line client), laid out like airportd; this build must not stop the image
sh "$WS/sdk/build-usernoted.sh" "$WORK/cw" "$WORK/compat" > "$WORK/usernoted.log" 2>&1 || tail -5 "$WORK/usernoted.log"
# launchd and the launch agents of the desktop (Dock, SystemUIServer, Finder, Terminal): without them the rc script starts the programs by hand
sh "$WS/launchd/build.sh" "$WORK/cw" > "$WORK/launchd.log" 2>&1 || tail -5 "$WORK/launchd.log"
install -d /usr/local/bin /usr/local/libexec
install -d /usr/local/share/wsbsd/icons && install -m 644 "$HERE"/icons/*.icns /usr/local/share/wsbsd/icons/
# the asset catalogues of the Mac that the file panels read (coreui): the small ones are in the repository, the big ones (SF Symbols 117 MB, CoreTypes 20 MB) are copied into coreui/assets before the build or are already in place
install -d /usr/local/share/wsbsd/coreui && install -m 644 "$WS"/coreui/assets/DesktopServicesPriv.car "$WS"/coreui/assets/CoreTypes-Info.plist "$WS"/coreui/assets/name_aliases.strings /usr/local/share/wsbsd/coreui/
for c in CoreGlyphs CoreTypes; do [ -f "$WS/coreui/assets/$c.car" ] && install -m 644 "$WS/coreui/assets/$c.car" /usr/local/share/wsbsd/coreui/$c.car; [ -f /usr/local/share/wsbsd/coreui/$c.car ] || echo "NOTE: $c.car missing, the file panels draw without it"; done
# the Dock and the status area of the menu bar (they talk to wsd through the client library: a static archive of the objects above)
ar rcs "$WORK/libwsclient.a" "$WORK"/ws_*.o
COMPAT="$WORK/compat" WSCLIENT="$WORK/libwsclient.a" sh "$WS/dock/build.sh" "$WORK/dock" > "$WORK/dock.log" 2>&1; install -m 755 "$WORK/dock/Dock" /usr/local/bin/Dock-gnustep || { cat "$WORK/dock.log"; exit 1; }
COMPAT="$WORK/compat" sh "$WS/topbar/build.sh" "$WORK/topbar" > "$WORK/topbar.log" 2>&1; install -m 755 "$WORK/topbar/TopBar" /usr/local/bin/TopBar-gnustep || { cat "$WORK/topbar.log"; exit 1; }
COMPAT="$WORK/compat" sh "$WS/loginwindow/build.sh" "$WORK/loginwindow" > "$WORK/loginwindow.log" 2>&1; install -m 755 "$WORK/loginwindow/loginwindow" /usr/local/bin/loginwindow-gnustep || { cat "$WORK/loginwindow.log"; exit 1; }
# the Finder: built from finder/, with the resources of the reference Mac's Finder imported when they are at hand (FINDER_APP=path of Finder.app, or finder/Resources copied in before the build); it lands as /System/Library/CoreServices/Finder.app
echo "== the Finder"; COMPAT="$WORK/compat" sh "$WS/finder/build.sh" "$WORK/finder" > "$WORK/finder.log" 2>&1 || true; tail -5 "$WORK/finder.log"; FA="$WORK/finder/System/Library/CoreServices/Finder.app"; [ -x "$FA/Contents/MacOS/Finder" ] || { cat "$WORK/finder.log"; exit 1; }
if [ -n "$FINDER_APP" ] && [ -d "$FINDER_APP" ]; then sh "$WS/finder/import-resources.sh" "$FINDER_APP" "$FA" >> "$WORK/finder.log" 2>&1 || true; fi
rm -rf /usr/local/share/wsbsd/Finder.app; install -d /usr/local/share/wsbsd/Finder.app; (cd "$FA" && tar cf - .) | (cd /usr/local/share/wsbsd/Finder.app && tar xf -); install -m 755 "$FA/Contents/MacOS/Finder" /usr/local/bin/Finder-gnustep; echo "== the Finder installed"
for a in terminal:Terminal-gnustep uitest:UITest-gnustep ksa:KeyboardSetupAssistant-gnustep; do d="${a%%:*}"; b="${a##*:}"; (cd "$WS/../$d" && make gnustep $( [ "$d" = uitest ] || echo COMPAT="$WORK/compat" ) WS="$WS" > "$WORK/$d.log" 2>&1 && install -m 755 "$b" /usr/local/bin/"$b") || { echo "== $d did not build"; grep -m12 "error" "$WORK/$d.log"; [ "$d" = uitest ] || exit 1; }; done
cc -O2 -o /usr/local/libexec/dyld "$HERE/src/dyld.c"
cc -O2 -I"$WS/sdk/include" -o /usr/local/bin/xattr "$HERE/src/xattr.c" "$WS/sdk/src/xattr.c"
install -d /usr/local/sbin; cc -O2 -I"$WS/sdk/include" -o /usr/local/sbin/spctl "$HERE/src/spctl.c" "$WS/sdk/src/xattr.c"

echo "== 2. FreeBSD $REL base and kernel"
for s in base kernel; do
	[ -f "$WORK/$s.txz" ] || fetch -q -o "$WORK/$s.txz" "https://download.freebsd.org/releases/$RELDIR/$REL/$s.txz" || fetch -q -o "$WORK/$s.txz" "https://ftp-archive.freebsd.org/pub/FreeBSD-Archive/old-releases/$RELDIR/$REL/$s.txz"
	tar -xpf "$WORK/$s.txz" --no-fflags -C "$ROOT"
done
rm -rf "$ROOT/usr/lib32" "$ROOT/usr/tests" "$ROOT/usr/share/doc" "$ROOT/usr/share/examples" "$ROOT/usr/share/games" "$ROOT/usr/share/man" "$ROOT/usr/share/info" "$ROOT/usr/include" "$ROOT/usr/lib/clang" "$ROOT/usr/share/dtrace" "$ROOT/usr/share/sendmail" "$ROOT/usr/share/openssl"
rm -f "$ROOT"/usr/lib/*.a "$ROOT"/usr/lib/*_p.a "$ROOT"/usr/bin/clang* "$ROOT"/usr/bin/ld.lld "$ROOT"/usr/bin/lld* "$ROOT"/usr/bin/lldb* "$ROOT"/usr/bin/llvm-* "$ROOT"/usr/bin/c++ "$ROOT"/usr/bin/cc "$ROOT"/usr/bin/c89 "$ROOT"/usr/bin/c99 "$ROOT"/usr/bin/cpp "$ROOT"/usr/bin/CC "$ROOT"/usr/bin/ld "$ROOT"/usr/bin/ld.bfd "$ROOT"/usr/bin/ar "$ROOT"/usr/bin/ranlib

echo "== 3. what we built, with the libraries it needs"
mkdir -p "$ROOT/usr/local"
PDFLIBS="$(cd / && ls usr/local/lib/libpoppler-glib.so* 2>/dev/null)"   # dlopen'ed by PDFImage.m: the dependency scan below follows them
tar -C / -cf - $PDFLIBS usr/local/GNUstep usr/local/sbin/wsd usr/local/sbin/spctl usr/local/bin usr/local/libexec/dyld usr/local/lib/libwsclient.so usr/local/lib/libwsbsdcompat.so usr/local/lib/libQuartzCore.so usr/local/share/fonts usr/local/etc/fonts usr/local/share/wsbsd usr/local/bin/zsh usr/local/bin/sudo usr/local/libexec/sudo usr/local/lib/sudo usr/local/share/zsh usr/local/share/zsh-autosuggestions usr/local/lib/zsh usr/local/share/icu usr/local/lib/libicudata.so usr/local/lib/libicudata.so.76 usr/local/lib/libicudata.so.76.1 2>/dev/null | tar -C "$ROOT" -xpf -
# guest tools of VMware and VirtualBox (before the library scan, which then follows their dependencies)
sh "$HERE/tools/guesttools.sh" "$ROOT" || echo "NOTE: guest tools failed"
# every shared library below /usr/local that these programs need (ldd closure)
find "$ROOT/usr/local" -type f \( -name '*.so*' -o -perm -u+x \) 2>/dev/null | sed "s|^$ROOT||" > "$WORK/elf.list"
: > "$WORK/needed.list"
for round in 1 2 3 4 5 6; do
	cat "$WORK/elf.list" "$WORK/needed.list" | sort -u | while read -r f; do [ -f "$f" ] && ldd "$f" 2>/dev/null | awk '/=>/ {print $3}'; done | grep '^/usr/local/' | sort -u > "$WORK/n2.list" || true
	cmp -s "$WORK/n2.list" "$WORK/needed.list" && break
	cp "$WORK/n2.list" "$WORK/needed.list"
done
while read -r l; do [ -f "$l" ] && { mkdir -p "$ROOT$(dirname "$l")"; cp -L "$l" "$ROOT$l"; }; done < "$WORK/needed.list"
mkdir -p "$ROOT/usr/local/etc"; [ -d /usr/local/etc/fonts ] && cp -R /usr/local/etc/fonts "$ROOT/usr/local/etc/" 2>/dev/null || true

echo "== 4. the macOS layout"
python3 "$HERE/tools/macfs.py" desymlink "$ROOT"
python3 "$HERE/tools/macfs.py" skeleton "$ROOT" "$HERE/manifest"
python3 "$HERE/tools/macfs.py" install "$ROOT" "$HERE/manifest" "$HERE/components.json"
# the demo account: a few folders and files on the Desktop and a folder with many mixed files (the rc script copies this into the home of the session)
rm -rf "$ROOT/Library/User Template"; python3 "$HERE/tools/mkdemo.py" "$ROOT/Library/User Template" || echo "NOTE: the demo content was not made"
# /private/{etc,var,tmp} next to /etc /var /tmp (the Mac has the first as the real places and the others as links; here both are real)
mkdir -p "$ROOT/private/etc" "$ROOT/private/var" "$ROOT/private/tmp" "$ROOT/Users/Shared" "$ROOT/Users/root"
cp -R "$ROOT/etc/." "$ROOT/private/etc/"

echo "== 5. configuration: silent boot, desktop on start"
cp "$HERE/overlay/boot/loader.conf" "$ROOT/boot/loader.conf"
for d in etc private/etc; do
	mkdir -p "$ROOT/$d/rc.d"
	cp "$HERE/overlay/etc-rc.conf" "$ROOT/$d/rc.conf"; cp "$HERE/overlay/etc-fstab" "$ROOT/$d/fstab"; cp "$HERE/overlay/etc-syslog.conf" "$ROOT/$d/syslog.conf"
	install -m 755 "$HERE/overlay/etc-rc.d-macdesktop" "$ROOT/$d/rc.d/macdesktop"
	# the home of root is /Users/root (the session's home, with the Desktop): GNUstep's NSHomeDirectory() takes the home from the password database, not from $HOME, and looked in /root
	if [ -f "$ROOT/$d/master.passwd" ]; then sed -i '' 's|:/root:|:/Users/root:|' "$ROOT/$d/master.passwd"; pwd_mkdb -p -d "$ROOT/$d" "$ROOT/$d/master.passwd" 2>/dev/null || echo "NOTE: pwd_mkdb failed in $d"; fi
done
mkdir -p "$ROOT/System/Library/LaunchDaemons"
(cd "$WORK/cw" && find System usr -type l -name Current 2>/dev/null | while read -r l; do rm -rf "$ROOT/$l"; done)       # the desymlinked copies give way to the links
(cd "$WORK/cw" && tar -cf - System usr 2>/dev/null) | tar -C "$ROOT" -xpf - || true
install -d "$ROOT/System/Library/Desktop Pictures" && install -m 644 "$WS/desktop-pictures/dark-mode.jpg" "$WS/desktop-pictures/light-mode.jpg" "$ROOT/System/Library/Desktop Pictures/"; cp "$WS/desktop-pictures/README.md" "$ROOT/System/Library/Desktop Pictures/README.md"
install -d "$ROOT/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources" && install -m 644 "$WS/launchservices/uti_table.json" "$ROOT/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/uti_table.json"
for d in etc private/etc; do install -m 755 "$HERE/overlay/etc-rc.d-wsbsd_kbdlight" "$ROOT/$d/rc.d/wsbsd_kbdlight"; done
# the keyboard backlight driver (needs the kernel sources of the build machine; without them the image simply has no such module)
if [ -d /usr/src/sys/dev/acpica ]; then (cd "$WS/kmod/clevo_wmi" && make clean >/dev/null 2>&1; make >"$WORK/clevo_wmi.log" 2>&1 && install -d "$ROOT/boot/modules" && install -m 555 clevo_wmi.ko "$ROOT/boot/modules/clevo_wmi.ko") || echo "NOTE: clevo_wmi did not build (see $WORK/clevo_wmi.log)"; else echo "NOTE: no /usr/src/sys: no keyboard backlight module in this image"; fi
for d in etc private/etc; do install -m 755 "$HERE/overlay/etc-rc.d-wsbsd_wifi" "$ROOT/$d/rc.d/wsbsd_wifi"; done
for d in etc private/etc; do install -m 755 "$HERE/overlay/etc-rc.d-airportd" "$ROOT/$d/rc.d/airportd"; install -m 755 "$HERE/overlay/etc-rc.d-usernoted" "$ROOT/$d/rc.d/usernoted"; done
# no text login on the screen: the window server owns it (the serial console keeps its login)
for d in etc private/etc; do sed -i '' -E 's/^(ttyv[0-9a-f]+[[:space:]].*[[:space:]])(onifexists|on)([[:space:]]|$)/\1off\3/' "$ROOT/$d/ttys"; done
# the shell of root and of the Terminal: zsh, the default shell of macOS (/bin/zsh), with /etc/zprofile and /etc/zshrc taken from the author's Mac configuration, minus what is Mac-only
[ -x "$ROOT/usr/local/bin/zsh" ] || { echo "image check failed: zsh is not in the image"; exit 1; }
install -m 755 "$ROOT/usr/local/bin/zsh" "$ROOT/bin/zsh"
for d in etc private/etc usr/local/etc; do          # FreeBSD's zsh reads its global files from /usr/local/etc, the Mac's from /etc: both
	mkdir -p "$ROOT/$d"; [ $d = usr/local/etc ] || { grep -qx /bin/zsh "$ROOT/$d/shells" 2>/dev/null || echo /bin/zsh >> "$ROOT/$d/shells"; }
	cp "$HERE/overlay/etc-zprofile" "$ROOT/$d/zprofile"; cp "$HERE/overlay/etc-zshrc" "$ROOT/$d/zshrc"
done
pw -R "$ROOT" usermod root -s /bin/zsh
# the account of the image: alex, password "pear", administrator (wheel, sudo / doas without asking again is not given: the password is asked)
pw -R "$ROOT" groupshow alex >/dev/null 2>&1 || pw -R "$ROOT" groupadd alex -g 501
pw -R "$ROOT" usershow alex >/dev/null 2>&1 || { echo pear | pw -R "$ROOT" useradd alex -u 501 -g alex -G wheel,operator,video -c "Alex" -d /Users/alex -s /bin/zsh -h 0; }
mkdir -p "$ROOT/Users/alex"
for d in usr/local/etc etc; do mkdir -p "$ROOT/$d"; done
if [ -x "$ROOT/usr/local/bin/sudo" ] || pkg info -e sudo >/dev/null 2>&1; then printf '%%wheel ALL=(ALL:ALL) ALL\n' > "$ROOT/usr/local/etc/sudoers"; chmod 440 "$ROOT/usr/local/etc/sudoers"; fi
printf 'permit persist :wheel\npermit nopass root\n' > "$ROOT/usr/local/etc/doas.conf"; cp "$ROOT/usr/local/etc/doas.conf" "$ROOT/etc/doas.conf" 2>/dev/null
# pkg is real and usable: the static pkg of the build machine is /usr/local/sbin/pkg (/usr/sbin/pkg, the bootstrapper, hands over to it), /usr/local is made writable at boot (wsbsd_overlay: a unionfs
# over the read-only medium), the repository is FreeBSD's own (/etc/pkg/FreeBSD.conf), the database lives in /var/db/pkg (a memory file system on the live image)
if [ -x /usr/local/sbin/pkg-static ]; then install -d "$ROOT/usr/local/sbin" "$ROOT/usr/local/etc"; install -m 755 /usr/local/sbin/pkg-static "$ROOT/usr/local/sbin/pkg"; cp /usr/local/etc/pkg.conf.sample "$ROOT/usr/local/etc/pkg.conf.sample" 2>/dev/null; else echo "NOTE: pkg-static is not on the build machine: pkg stays the bootstrapper"; fi
for d in etc private/etc; do install -m 755 "$HERE/overlay/etc-rc.d-wsbsd_overlay" "$ROOT/$d/rc.d/wsbsd_overlay"; done
# the local time zone (GNUstep's NSTimeZone and ICU's date formats need one; the image has no /etc/localtime of its own)
for d in etc private/etc; do cp "$ROOT/usr/share/zoneinfo/UTC" "$ROOT/$d/localtime" 2>/dev/null || true; done
# what the desktop needs at run time and that earlier images lacked: ICU's data (NSDateFormatter crashed without it), a time zone, no getty on the screen's console
for need in "$ROOT/usr/local/share/icu" "$ROOT/etc/localtime" "$ROOT/usr/local/lib/libicudata.so.76"; do [ -e "$need" ] || { echo "image check failed, missing: $need"; exit 1; }; done
grep -E '^ttyv0' "$ROOT/etc/ttys" | grep -qE '[[:space:]]off([[:space:]]|$)' || { echo "image check failed: ttyv0 still has a getty"; grep -E '^ttyv0' "$ROOT/etc/ttys"; exit 1; }
python3 "$HERE/tools/macfs.py" desymlink "$ROOT"
python3 "$HERE/tools/macfs.py" verify "$ROOT" "$HERE/manifest" || { echo "layout check failed"; [ -n "$LAYOUT_STRICT" ] && exit 1; }

echo "== 6. the EFI system partition: Ploader first, FreeBSD's loader behind it"
ESP="$WORK/esp"; rm -rf "$ESP"; mkdir -p "$ESP/EFI/BOOT" "$ESP/EFI/freebsd" "$ESP/EFI/ploader"
if [ -n "$PLOADER_DIR" ] && [ -f "$PLOADER_DIR/$PLNAME" ]; then
	cp "$PLOADER_DIR/$PLNAME" "$ESP/EFI/BOOT/$EFINAME"; cp "$PLOADER_DIR/$PLNAME" "$ESP/EFI/ploader/$PLNAME"
	[ -d "$PLOADER_DIR/theme" ] && cp -R "$PLOADER_DIR/theme" "$ESP/EFI/BOOT/theme" && cp -R "$PLOADER_DIR/theme" "$ESP/EFI/ploader/theme"
	[ -d "$PLOADER_DIR/drivers" ] && cp -R "$PLOADER_DIR/drivers" "$ESP/EFI/BOOT/drivers_$([ "$ARCH" = amd64 ] && echo x64 || echo aa64)"
	cp "$HERE/esp/ploader.conf" "$ESP/EFI/BOOT/ploader.conf"; cp "$HERE/esp/ploader.conf" "$ESP/EFI/ploader/ploader.conf"
	cp "$ROOT/boot/loader.efi" "$ESP/EFI/freebsd/loader.efi"
else
	echo "no Ploader build for $ARCH ($PLNAME): the image boots through FreeBSD's loader directly"
	cp "$ROOT/boot/loader.efi" "$ESP/EFI/BOOT/$EFINAME"
fi
makefs -t msdos -o fat_type=16 -o volume_label=EFISYS -s 64m "$WORK/efiboot.img" "$ESP"

echo "== 7. the ISO"
ISO="$OUT/macbsd-$ARCH.iso"
makefs -t cd9660 -o rockridge -o label=PEAROS -o publisher="wsbsd" -o bootimage="i386;$WORK/efiboot.img" -o no-emul-boot -o platformid=efi "$ISO" "$ROOT"
# the ISO is also a disk image: a GPT over the EFI image inside it, so that a plain write to a USB stick (dd, Etcher) boots on a PC (iso/tools/hybrid.py)
python3 "$HERE/tools/hybrid.py" "$ISO" "$(stat -f %z "$WORK/efiboot.img" 2>/dev/null || stat -c %s "$WORK/efiboot.img")"
ls -l "$ISO"; sha256 "$ISO" > "$ISO.sha256"; cat "$ISO.sha256"

