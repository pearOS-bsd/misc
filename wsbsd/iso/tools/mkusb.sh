#!/bin/sh
# mkusb.sh ISO OUT.img: a USB-bootable disk image from the ISO (FreeBSD host: mdconfig, makefs, mkimg).
#   GPT { p1: EFI system partition = Ploader + loader.efi + the whole /boot of the ISO, p2: the ISO itself (the kernel finds the cd9660 file system by its label) }
# Why /boot is on the ESP: FreeBSD's loader.efi does not treat a cd9660 partition on a hard disk as a boot device, but it does read /boot from the FAT partition it was started from.
set -e
ISO="${1:?ISO}"; OUT="${2:?output image}"; HERE="$(cd "$(dirname "$0")" && pwd)"
W="$(mktemp -d /tmp/mkusb.XXXXXX)"; mkdir -p "$W/iso" "$W/efi" "$W/esp"
cleanup() { umount "$W/iso" 2>/dev/null; umount "$W/efi" 2>/dev/null; [ -n "$MD1" ] && mdconfig -d -u "$MD1" 2>/dev/null; [ -n "$MD2" ] && mdconfig -d -u "$MD2" 2>/dev/null; rm -rf "$W"; }
trap cleanup EXIT
MD1=$(mdconfig -a -t vnode -f "$ISO"); mount -t cd9660 "/dev/$MD1" "$W/iso"
python3 -I "$HERE/mkusb.py" --extract-esp "$ISO" "$W/efiboot.img"
MD2=$(mdconfig -a -t vnode -f "$W/efiboot.img"); mount -t msdosfs "/dev/$MD2" "$W/efi"
cp -R "$W/efi/." "$W/esp/"
umount "$W/efi"; mdconfig -d -u "$MD2"; MD2=
cp -R "$W/iso/boot" "$W/esp/boot"
KB=$(du -sk "$W/esp" | cut -f1); MB=$(( KB / 1024 * 12 / 10 + 32 ))
echo "ESP: ${KB} KiB of files, ${MB} MiB image"
makefs -t msdos -o fat_type=16 -o volume_label=EFISYS -s "${MB}m" "$W/esp.img" "$W/esp"
mkimg -s gpt -p "efi/EFISYS:=$W/esp.img" -p "freebsd-ufs/PEAROS:=$ISO" -o "$OUT"
ls -l "$OUT"
