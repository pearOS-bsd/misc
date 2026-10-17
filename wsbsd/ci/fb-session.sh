#!/bin/sh
# A desktop on the machine's own screen (no VNC): wsd on the vt(4) framebuffer plus evdev input, and a few applications. Run as root from ssh or the console, after `gmake fb`.
#   sh ci/fb-session.sh [app ...]      apps: terminal (default), gallery, hexfiend, pashua
# The display is whatever the console already uses (EFI GOP, simplefb): in QEMU use ~/fbsd-vm/start-gui.sh (-device ramfb -display cocoa, USB keyboard and tablet).
# Input needs the HID drivers: /boot/loader.conf: hw.usb.usbhid.enable="1" hkbd_load="YES" hms_load="YES" hidmap_load="YES"
WS="$(cd "$(dirname "$0")/.." && pwd)"
pkill -x wsd 2>/dev/null; conscontrol mute on >/dev/null 2>&1          # kernel messages must not be drawn over the desktop
export WS_SOCKET=/tmp/wsd-live.sock XDG_CURRENT_DESKTOP=Aqua XDG_SESSION_DESKTOP=Aqua XDG_SESSION_TYPE=wsd TERM=xterm-256color HOME=/root
rm -f "$WS_SOCKET"
(cd "$WS" && nohup ./wsd -b kms -c /dev/ttyv0 -t ${WSD_FPS:+-F} > /tmp/wsd-fb.log 2>&1 &)
sleep 2; cat /tmp/wsd-fb.log
. /usr/local/GNUstep/System/Library/Makefiles/GNUstep.sh
rm -rf /tmp/GNUstepSecure0/NSMessagePort/names/lock
[ $# -eq 0 ] && set -- terminal
for a in "$@"; do
	case $a in
	terminal) nohup /root/terminal/Terminal-gnustep > /tmp/fb-terminal.log 2>&1 & ;;
	gallery) nohup /root/uitest/UITest-gnustep > /tmp/fb-ui.log 2>&1 & ;;
	hexfiend) (cd /root/oss/outa/HexFiend_2 && nohup ./HexFiend.app/HexFiend /tmp/sample.bin > /tmp/fb-hf.log 2>&1 &) ;;
	pashua) (cd /root/oss/outp/Pashua && nohup ./Pashua.app/Pashua /tmp/pashua2.conf > /tmp/fb-pashua.log 2>&1 &) ;;
	esac
done
