#!/bin/sh
# Firmware and helper programs for the hardware the image is meant to run on: Wi-Fi firmware (iwlwifi, rtw88, rtw89, mt76, ath, ... as kernel modules), Bluetooth firmware (Intel, Realtek),
# usbmuxd + libimobiledevice (pairing for the iPhone's USB tethering, ipheth). Copied from the build machine's packages into the image root, like guesttools.sh.  sh drivers.sh ROOT
# A package missing for this architecture or release is reported, not an error.
ROOT="${1:?image root}"
want="$(pkg search -q -x '^(drm-61-kmod|gpu-firmware-intel-kmod-.*|gpu-firmware-radeon-kmod-.*|wifi-firmware-.*-kmod|.*(ath10k|ath11k|mt76|mt7921|rtl88|rtw8).*-kmod|bwn-firmware-kmod|iwi-firmware-kmod|ipw-firmware-kmod|iwmbt-firmware|rtlbt-firmware|usbmuxd|libimobiledevice|libusbmuxd|libplist)(-[0-9][^-]*)?$' 2>/dev/null | sed 's/-[0-9][^-]*$//' | sort -u)"
[ -n "$want" ] || want="drm-61-kmod wifi-firmware-iwlwifi-kmod wifi-firmware-rtw88-kmod wifi-firmware-rtw89-kmod wifi-firmware-mt76-kmod iwmbt-firmware rtlbt-firmware usbmuxd libimobiledevice"
for top in $want; do
	pkg info -e "$top" 2>/dev/null || pkg install -y "$top" >/dev/null 2>&1 || true
	pkg info -e "$top" 2>/dev/null || { echo "NOTE: $top is not available for $(uname -p), skipped"; continue; }
	pkg info -l "$top" 2>/dev/null | sed -n 's/^[[:space:]]*\(\/.*\)$/\1/p' | grep -vE '^/usr/local/(share/(doc|man|info|examples|gtk-doc|locale|bash-completion)|include|man|info|lib/pkgconfig|libdata)/' | cut -c2- | tar -C / -cf - -T - 2>/dev/null | tar -C "$ROOT" -xpf - 2>/dev/null
	echo "drivers: $top"
done
# the firmware modules sit in /boot/modules (kernel modules of the ports), the loader finds them there
[ -d "$ROOT/boot/modules" ] && echo "drivers: $(ls "$ROOT/boot/modules" | wc -l) files in /boot/modules"
# AMD: the radeon firmware packages (CIK and older: radeonkms; the A10-7800B / Kaveri among them); the firmware of amdgpu (gpu-firmware-amd-kmod-*, hundreds of MB) is not in yet; the image is published as .iso.xz, so the GitHub size limit of 2 GiB per file no longer binds
for need in drm-61-kmod usbmuxd iwmbt-firmware; do pkg info -e "$need" 2>/dev/null || echo "NOTE: $need is NOT in the image"; done
ls "$ROOT"/boot/modules | grep -E -c 'iwlwifi|rtw8|mt76' | sed 's/^/drivers: Wi-Fi firmware modules: /'
