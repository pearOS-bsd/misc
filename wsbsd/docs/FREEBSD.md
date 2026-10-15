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
