# Running wsd on FreeBSD (first run)

Status: the headless build is tested on macOS. The KMS/evdev backend (`src/backend_kms.c`) has never been run:
it was only syntax-checked against stub headers. Expect a first-run fixing pass.

## VM
FreeBSD 14 or newer in UTM/QEMU or VMware, with a virtio-gpu or VMware SVGA display so a DRM driver exists.
On bare metal use an Intel or AMD GPU with `drm-kmod`.

    pkg install drm-kmod libdrm pkgconf gmake
    sysrc kld_list+=i915kms          # or amdgpu / radeonkms / vmwgfx for the virtual GPU
    pw groupmod video -m $USER       # access to /dev/dri
    # evdev input: add the user to the group that owns /dev/input/event*, or run wsd as root for the first test

## Build and run
    gmake                 # headless build; gmake check runs the compositor tests
    gmake kms             # display + input backend
    ./wsd -b kms -c /dev/dri/card0 &    # from a text console (not under X11)
    ./test_window shot.ppm              # draws the test window; with -b kms it appears on screen

Switch to a text console first (Ctrl+Alt+F2); DRM master is exclusive, so no X server or other compositor may be running.

## What to check first
1. `wsd: ... backend kms` printed, screen goes black then shows the desktop colour.
2. Mouse moves the cursor (`/dev/input/event*` readable).
3. `test_window` window appears with shadows; click it, type a key (events are drained by the client).
4. If the mode set fails: `drmModeSetCrtc` error means another DRM master or a connector without a CRTC.

## Sandbox (Capsicum)

`wsd -S` enters capability mode once the listening socket, the event queue and (with `kms`) the display and input devices are open: from then on the server cannot open files or paths,
create named sockets or reach anything outside the descriptors it holds. Clients still connect and shared memory is created with `SHM_ANON`. The FreeBSD CI job runs `test_props` and
`test_robust` against a sandboxed server. The test-mode screenshot (`-t`, writes a file) does not work under `-S`, as intended. On systems without Capsicum `-S` is a no-op with a message.

## Console switching (KMS backend)

On a vt(4) console, `wsd -b kms` puts its VT in graphics mode, puts the console keyboard in raw mode and asks the kernel for SIGUSR1 (leave) and SIGUSR2 (come back). While another VT is in front it drops
DRM master and discards raw input, so nothing typed on the other console reaches the window server or its clients; coming back it takes master again and redraws. SIGTERM / SIGINT restore text mode
and the keyboard. When wsd is not started from a vt(4) console it says so and runs without this (input stays grabbed). Written against vt(4); never run on real hardware.

## A real screen without a GPU driver (vt framebuffer) - verified in QEMU
`gmake fb` builds wsd with `src/backend_fb.c`: the display is the framebuffer the console already uses (EFI GOP on arm64 and UEFI amd64, simplefb), reached through `/dev/ttyv0`
(`FBIOGTYPE`, `FBIO_GETLINEWIDTH`, `mmap`). `wsd -b kms -c /dev/ttyv0` selects it (the backend keeps the KMS interface, so the rest of wsd is the same); the cursor is composed in software.
Input is evdev. On FreeBSD 14 the USB HID drivers are not used by default: `/boot/loader.conf` needs `hw.usb.usbhid.enable="1"`, `hkbd_load="YES"`, `hms_load="YES"`, `hidmap_load="YES"`
(`/etc/rc.conf`: `devmatch_blocklist="uhid"`), then the keyboard is `hkbd` and the tablet `hms` (absolute positions), both as `/dev/input/event*`.

QEMU (aarch64 virt, HVF): `-device ramfb -device qemu-xhci -device usb-kbd -device usb-tablet -display cocoa`, keeping the PCI slots of the disk and network devices so that the UEFI boot entry
still matches (`~/fbsd-vm/start-gui.sh`); `sh ci/fb-session.sh terminal hexfiend` starts the desktop. Measured: 800x600 (the ramfb default), a frame is composed and copied in 2 to 3 ms.
