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
if [ -z "$SKIP_SOFTWARE" ]; then
	pkg install -y python3 gmake pkgconf git >/dev/null 2>&1 || true
	sh "$WS/ci/gnustep-setup.sh" > "$WORK/gnustep.log" 2>&1 || { tail -30 "$WORK/gnustep.log"; exit 1; }
	sh "$WS/ci/opal-build.sh" > "$WORK/opal.log" 2>&1 || { tail -30 "$WORK/opal.log"; exit 1; }
fi
. /usr/local/GNUstep/System/Library/Makefiles/GNUstep.sh
for need in /usr/local/GNUstep/System/Library/Libraries/libgnustep-gui.so.0.32 /usr/local/GNUstep/System/Library/Libraries/libgnustep-base.so.1.31 /usr/local/GNUstep/Local/Library/Libraries/libgnustep-corebase.so.0 /usr/local/GNUstep/Local/Library/Libraries/libopal.so.0; do
	[ -f "$need" ] || { echo "missing after the software build: $need"; ls /usr/local/GNUstep/System/Library/Libraries /usr/local/GNUstep/Local/Library/Libraries 2>&1 | head -20; tail -20 "$WORK/gnustep.log" "$WORK/opal.log" 2>/dev/null; exit 1; }
done
(cd "$WS" && gmake fb >/dev/null && install -d /usr/local/sbin && install -m 755 wsd /usr/local/sbin/wsd && gmake wsshot wsclick wskey wsdrag wswins wsfps wsmove wscursor >/dev/null && install -d /usr/local/bin && install -m 755 wsshot wsclick wskey wsdrag wswins wsfps wsmove wscursor /usr/local/bin/)
(cd "$WS/src" && for f in client compositor_sw region ipc evrec buffer; do cc -O2 -fPIC -std=c99 -D_DEFAULT_SOURCE -I"$WS/include" -c $f.c -o "$WORK/ws_$f.o"; done; cc -shared -o /usr/local/lib/libwsclient.so "$WORK"/ws_*.o -lm)
sh "$WS/sdk/build-compat.sh" "$WORK/compat" > "$WORK/compat.log" 2>&1; install -m 755 "$WORK/compat/libwsbsdcompat.so" /usr/local/lib/libwsbsdcompat.so; install -m 755 "$WORK/compat/libQuartzCore.so" /usr/local/lib/libQuartzCore.so
install -d /usr/local/bin /usr/local/libexec
install -d /usr/local/share/wsbsd/icons && install -m 644 "$HERE"/icons/*.icns /usr/local/share/wsbsd/icons/
# the Dock and the status area of the menu bar (they talk to wsd through the client library: a static archive of the objects above)
ar rcs "$WORK/libwsclient.a" "$WORK"/ws_*.o
COMPAT="$WORK/compat" WSCLIENT="$WORK/libwsclient.a" sh "$WS/dock/build.sh" "$WORK/dock" > "$WORK/dock.log" 2>&1; install -m 755 "$WORK/dock/Dock" /usr/local/bin/Dock-gnustep || { cat "$WORK/dock.log"; exit 1; }
COMPAT="$WORK/compat" sh "$WS/topbar/build.sh" "$WORK/topbar" > "$WORK/topbar.log" 2>&1; install -m 755 "$WORK/topbar/TopBar" /usr/local/bin/TopBar-gnustep || { cat "$WORK/topbar.log"; exit 1; }
for a in terminal:Terminal-gnustep uitest:UITest-gnustep ksa:KeyboardSetupAssistant-gnustep; do d="${a%%:*}"; b="${a##*:}"; (cd "$WS/../$d" && make gnustep >/dev/null 2>&1 && install -m 755 "$b" /usr/local/bin/"$b"); done
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
tar -C / -cf - usr/local/GNUstep usr/local/sbin/wsd usr/local/sbin/spctl usr/local/bin usr/local/libexec/dyld usr/local/lib/libwsclient.so usr/local/lib/libwsbsdcompat.so usr/local/lib/libQuartzCore.so usr/local/share/fonts usr/local/etc/fonts usr/local/share/wsbsd usr/local/bin/zsh usr/local/share/zsh usr/local/lib/zsh usr/local/share/icu usr/local/lib/libicudata.so usr/local/lib/libicudata.so.76 usr/local/lib/libicudata.so.76.1 2>/dev/null | tar -C "$ROOT" -xpf -
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
# /private/{etc,var,tmp} next to /etc /var /tmp (the Mac has the first as the real places and the others as links; here both are real)
mkdir -p "$ROOT/private/etc" "$ROOT/private/var" "$ROOT/private/tmp" "$ROOT/Users/Shared"
cp -R "$ROOT/etc/." "$ROOT/private/etc/"

echo "== 5. configuration: silent boot, desktop on start"
cp "$HERE/overlay/boot/loader.conf" "$ROOT/boot/loader.conf"
for d in etc private/etc; do
	mkdir -p "$ROOT/$d/rc.d"
	cp "$HERE/overlay/etc-rc.conf" "$ROOT/$d/rc.conf"; cp "$HERE/overlay/etc-fstab" "$ROOT/$d/fstab"
	install -m 755 "$HERE/overlay/etc-rc.d-macdesktop" "$ROOT/$d/rc.d/macdesktop"
done
mkdir -p "$ROOT/System/Library/LaunchDaemons"
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
ls -l "$ISO"; sha256 "$ISO" > "$ISO.sha256"; cat "$ISO.sha256"
