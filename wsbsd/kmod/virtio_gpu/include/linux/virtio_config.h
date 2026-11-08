/* SPDX-License-Identifier: GPL-2.0 */
#ifndef _LINUX_VIRTIO_CONFIG_H
#define _LINUX_VIRTIO_CONFIG_H
#include <linux/virtio.h>

int virtio_find_vqs(struct virtio_device *vdev, unsigned int nvqs, struct virtqueue *vqs[], vq_callback_t *callbacks[], const char * const names[], struct irq_affinity *desc);
void virtio_device_ready(struct virtio_device *dev);
void virtio_reset_device(struct virtio_device *dev);
bool virtio_get_shm_region(struct virtio_device *vdev, struct virtio_shm_region *region, u8 id);
void virtio_shim_cread(struct virtio_device *vdev, unsigned int offset, void *buf, unsigned int len);
void virtio_shim_cwrite(struct virtio_device *vdev, unsigned int offset, const void *buf, unsigned int len);

/* the device specific configuration is little endian (virtio 1.0) */
#define virtio_cread_le(vdev, structname, member, ptr)						\
	do {											\
		typeof(*(ptr)) _v;								\
		virtio_shim_cread(vdev, offsetof(structname, member), &_v, sizeof(_v));	\
		*(ptr) = _v;									\
	} while (0)
#define virtio_cwrite_le(vdev, structname, member, ptr)						\
	do {											\
		typeof(*(ptr)) _v = *(ptr);							\
		virtio_shim_cwrite(vdev, offsetof(structname, member), &_v, sizeof(_v));	\
	} while (0)
#endif
