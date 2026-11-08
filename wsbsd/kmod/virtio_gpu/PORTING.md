# virtio_gpu for FreeBSD (virgl 3D in virtual machines)

Goal: `/dev/dri/card0` + `renderD128` on a QEMU `virtio-vga-gl` (or any virtio-gpu with virgl) so Mesa's `virgl` driver (already in libgallium of the image) gives the GL compositor of `wsd` hardware acceleration in VMs.

Source: Linux 6.1.128 `drivers/gpu/drm/virtio/*` and `drm_gem_shmem_helper.c` (GPL-2.0-only, kept as is; the module is a separate GPL work like drm-kmod itself). The build is `make SYSDIR=<src>/sys -C kmod/virtio_gpu` inside a checkout of freebsd/drm-kmod branch `6.1-lts` (copy this directory to `drm-kmod/virtio_gpu`).

STATE: milestone 1 done (virtio shim builds), working on milestone 2.

Design: the module is a LinuxKPI PCI driver (like i915) for the modern virtio GPU (1af4:1050) with its own virtio-pci transport written over the Linux API (`virtio_pci_shim.c`: capabilities, feature negotiation, split virtqueues without indirect descriptors, one MSI-X vector or INTx, shared memory regions, `virtio_dma_buf`). FreeBSD's virtio(4) is not used: it attaches the child before DRIVER_OK and gives no `struct pci_dev` to the DRM core. The device has to be free when the module loads: `devctl detach virtio_pci<N>` first (wsbsd_gpu does it). `include/linux/virtio*.h` replace Linux's headers with what virtio_gpu uses.

Done (milestone 1): virtgpu_*.c, drm_simple_kms_helper.c and the shim compile against drm-kmod 6.1-lts (`~/fbsd-vm/vg-build.sh`).

Open (milestone 2): `drm_gem_shmem_helper.c` needs a FreeBSD back end (pages from a `vm_object`, mmap by fault) instead of `shmem_file_setup` / `i_mapping` / `vmf_insert_pfn` / `anon_inode` / `dma_buf_mmap` / `mapping_set_gfp_mask` (see how i915's shmem objects do it in drm-kmod).

4. Test loop: `~/fbsd-vm/start-gl.sh` (QEMU with `-device virtio-vga-gl -display egl-headless`, the host's GPU renders), `kldload ./virtio_gpu.ko`, then `wsd -b kms -c /dev/dri/card0 -r gl` with `MESA_LOADER_DRIVER_OVERRIDE=virgl`.
