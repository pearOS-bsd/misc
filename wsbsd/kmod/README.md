# Kernel modules

Not in this tree any more. `iso/build.sh` fetches them when it builds the image:

- `virtio_gpu` (virgl / KMS in QEMU): https://github.com/pearOS-bsd/virtio (ref in `PEAR_VIRTIO_REF`, default `main`)
- `clevo_dchu` (Clevo keyboard backlight): https://github.com/pearOS-bsd/clevo_wmi (ref in `PEAR_CLEVO_REF`, default `main`)
