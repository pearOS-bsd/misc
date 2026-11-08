.include "../kconfig.mk"
SRCDIR=	${.CURDIR}
.PATH:	${SRCDIR}
KMOD=	virtio_gpu
SRCS=	virtio_pci_shim.c virtgpu_debugfs.c drm_simple_kms_helper.c virtgpu_drv.c virtgpu_kms.c virtgpu_gem.c virtgpu_vq.c virtgpu_fence.c virtgpu_object.c virtgpu_display.c virtgpu_plane.c virtgpu_ioctl.c virtgpu_prime.c virtgpu_vram.c drm_gem_shmem_helper.c
SRCS+=	opt_acpi.h opt_drm.h opt_platform.h opt_splash.h opt_syscons.h opt_teken.h acpi_if.h bus_if.h fb_if.h device_if.h pci_if.h vnode_if.h
.include <bsd.kmod.mk>
.include "../linuxkpi_version.mk"
.include "../compiler_flags.mk"
CFLAGS+= -I${.CURDIR}/include -I${.CURDIR}/include/uapi
CFLAGS+= -I${.CURDIR:H}/linuxkpi/gplv2/include -I${.CURDIR:H}/linuxkpi/bsd/include
CFLAGS+= -I${SYSDIR}/compat/linuxkpi/common/include -I${SYSDIR}/compat/linuxkpi/dummy/include
CFLAGS+= -I${.CURDIR:H}/include -I${.CURDIR:H}/include/drm -I${.CURDIR:H}/include/uapi -I${.CURDIR:H}/drivers/gpu -I${.CURDIR:H}/drivers/gpu/drm
CFLAGS+= "-DKBUILD_MODNAME=\"${KMOD}\"" -DLINUXKPI_PARAM_PREFIX=virtio_gpu_ -DDRM_SYSCTL_PARAM_PREFIX=_dri ${KCONFIG:C/(.*)/-DCONFIG_\1/}
CWARNFLAGS+= -Wno-cast-qual -Wno-format -Wno-gnu-pointer-arith -Wno-unused-variable -Wno-missing-prototypes
