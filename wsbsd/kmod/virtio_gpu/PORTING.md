# virtio_gpu for FreeBSD (virgl 3D in virtual machines)

Goal: `/dev/dri/card0` + `renderD128` on a QEMU `virtio-vga-gl` (or any virtio-gpu with virgl) so Mesa's `virgl` driver (already in libgallium of the image) gives the GL compositor of `wsd` hardware acceleration in VMs.

Source: Linux 6.1.128 `drivers/gpu/drm/virtio/*` and `drm_gem_shmem_helper.c` (GPL-2.0-only, kept as is; the module is a separate GPL work like drm-kmod itself). The build is `make SYSDIR=<src>/sys -C kmod/virtio_gpu` inside a checkout of freebsd/drm-kmod branch `6.1-lts` (copy this directory to `drm-kmod/virtio_gpu`).

STATE: works, with the limits below (milestones 1-6 plus the fixes of the first hardware-style test, see "Corrections"). Follow-ups, not blocking: unload leaks the BAR mappings and `kldunload` then `kldload` panics on duplicate devfs aliases (do not unload); no indirect descriptors, no blob / host-visible memory (QEMU reports -resource_blob -host_visible: the shared memory region is not exposed by this transport yet), no context_init (Venus / native context).

Design: the module is a LinuxKPI PCI driver (like i915) for the modern virtio GPU (1af4:1050) with its own virtio-pci transport written over the Linux API (`virtio_pci_shim.c`: capabilities, feature negotiation, split virtqueues without indirect descriptors, one MSI-X vector or INTx, shared memory regions, `virtio_dma_buf`). FreeBSD's virtio(4) is not used: it attaches the child before DRIVER_OK and gives no `struct pci_dev` to the DRM core. The device has to be free when the module loads: `devctl detach virtio_pci<N>` first (wsbsd_gpu does it). `include/linux/virtio*.h` replace Linux's headers with what virtio_gpu uses.

Done (milestone 1): virtgpu_*.c, drm_simple_kms_helper.c and the shim compile against drm-kmod 6.1-lts (`~/fbsd-vm/vg-build.sh`).

Done (milestone 2): `drm_gem_shmem_helper.c` has a FreeBSD back end: pages from the vm_object of LinuxKPI's shmem file (`bsd_gem_get_pages`), the fault handler follows ttm_bo_vm.c (`lkpi_vmf_insert_pfn_prot_locked` with the object lock), purge / madvise truncation and imported dma-buf mmap are Linux-only (`#ifdef __linux__`).

4. Test loop: `~/fbsd-vm/start-gl.sh` (QEMU with `-device virtio-vga-gl -display egl-headless`, the host's GPU renders), `kldload ./virtio_gpu.ko`, then `wsd -b kms -c /dev/dri/card0 -r gl` with `MESA_LOADER_DRIVER_OVERRIDE=virgl`.

Milestone 3 log (QEMU virtio-vga-gl, FreeBSD 14.5): `devctl detach virtio_pci1; kldload ./virtio_gpu.ko` prints `[drm] features: +virgl +edid -resource_blob -host_visible`, `number of scanouts: 1`, `number of cap sets: 2`, `Initialized virtio_gpu 0.1.0`, `VT: Replacing driver "vga" with new "drmfb"`. Needed on the way: the module must not depend on linuxkpi_gplv2, `MODULE_PARM_DESC(virglhack)` (the LinuxKPI sysctl macro needs it), virtgpu_debugfs.c in the build.

Milestone 4: the cap sets timed out because vp_interrupt dropped interrupts while probe() ran (probed was set after probe): fixed, `cap set 0: id 1 ... cap set 1: id 2` read at once. `gbmprobe` on renderD128: eglInitialize ok; `wsd -b kms -c /dev/dri/card0 -r gl -t -F` in the VM prints the virgl renderer line above.

Milestone 5 (SUPERSEDED, see "Corrections": these numbers were taken while GL drew nothing) (test/bench_fps.c, QEMU `-device virtio-vga-gl,xres=1920,yres=1080 -display egl-headless` on a Tiger Lake laptop, 8 vCPUs, `wsd -b kms -c /dev/dri/card0 -r gl|sw -t`, 8 glass windows of 900 px moving for 10 s, BENCH_WINDOWS=8 BENCH_WIDTH=900):
- GL on virgl: mean 91.3 FPS, 11.96 ms per frame, 878 frames
- software compositor: mean 67.6 FPS, 14.63 ms per frame, 607 frames
Lighter scene (4 windows of 560 px, 1280x800): GL 158 FPS / 6.2 ms, software 165 FPS / 4.3 ms: the benchmark is paced by its own move requests there, the GPU only wins when the scene is heavy.

Milestone 6 (image integration): `iso/build.sh` fetches drm-kmod 6.1-lts, builds this directory against it and installs /boot/modules/virtio_gpu.ko (then kldxref); `iso/overlay/etc-rc.d-wsbsd_gpu` detects 1af4:1050, `devctl detach`es virtio_pci and loads virtio_gpu. Booting the image in QEMU (OVMF, `-device virtio-vga-gl,xres=1920,yres=1080 -display egl-headless`) the serial report says: `module virtio_gpu: attached, /dev/dri/card0 present`, `wsd: GL compositor: EGL 1.5, virgl (Mesa Intel(R) Iris(R) Xe Graphics (TGL GT2)), dma-buf import yes, export yes, GBM display`, `acceleration: GPU (OpenGL ES compositor)`.


## Corrections (after looking at the real screen, not only the logs)

Milestones 1-6 were declared done on the strength of log lines and a frame-time benchmark. The first look at the image in QEMU showed flicker, wrong colours and lag, and the FPS figures above were wrong. What was found:

1. **GL commands were dropped.** `vmalloc_to_sgt()` (virtgpu_vq.c) refused buffers that are not page aligned. LinuxKPI's `is_vmalloc_addr()` is true for malloc'd memory, so every execbuffer from Mesa's virgl was dropped with -ENOMEM: GL drew nothing, read-back returned stale memory (flicker, wrong colours). Fixed: the first sg entry carries the page offset. `test/glcmp.c` (in wsbsd) composes one scene with the software and the GL compositor and compares pixels: llvmpipe 0 differences, virgl before 1024000 of 1024000, after 0.
2. **The queue froze after 65536 completions.** `last_used` was an `unsigned int` while `used->idx` is 16 bits: after the wrap `more_used()` stayed true and the dequeue work spun with the queue lock held (display frozen, interrupts stopped). Fixed: 16-bit `last_used`; a bogus used entry is skipped.
3. **Real speed.** With GL rendering correctly, virgl with a full read-back every frame is slower than the software compositor in the VM (1080p, 8 glass windows of 900 px: 39 FPS against 65 FPS, measured from wsd with WSD_FPSLOG). The scan-out is a dumb buffer, so each frame is read back (about 8 MB), converted and copied again. Zero-copy scan-out of the GL render target needs PRIME import / blob resources, which this port does not have. Use the software compositor on virtio unless that is done.
4. The first mode in the connector's list is not the preferred one under FreeBSD (640x480); wsd now picks the mode marked DRM_MODE_TYPE_PREFERRED. Display hotplug (host window resizes) works: config-changed interrupts reach the driver and wsd re-sets the mode.
