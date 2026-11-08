/* SPDX-License-Identifier: GPL-2.0 */
/* The part of Linux's <linux/virtio.h> that virtio_gpu uses, for FreeBSD's LinuxKPI: the transport (virtio-pci, split rings) is in virtio_pci_shim.c. */
#ifndef _LINUX_VIRTIO_H
#define _LINUX_VIRTIO_H
#include <linux/types.h>
#include <linux/list.h>
#include <linux/gfp.h>
#include <linux/scatterlist.h>
#include <linux/spinlock.h>
#include <linux/device.h>
#include <linux/mod_devicetable.h>
#include <linux/pci.h>
#include <linux/uuid.h>
#include <linux/string.h>
#include <uapi/linux/virtio_ids.h>
#include <uapi/linux/virtio_config.h>
#include <uapi/linux/virtio_ring.h>

#ifndef VIRTIO_DEV_ANY_ID
#define VIRTIO_DEV_ANY_ID	0xffffffff

/* small things of Linux that LinuxKPI does not have, in the way virtio_gpu uses them */
#include <linux/dma-fence.h>
#include <linux/uaccess.h>
#include <linux/string.h>
#undef MODULE_DEVICE_TABLE
#define MODULE_DEVICE_TABLE(bus, table)
#define dma_sync_sgtable_for_device(dev, sgt, dir)	do { } while (0)       /* only used with the DMA API on the rings, which virtio_has_dma_quirk() turns off */
#define dma_sync_sgtable_for_cpu(dev, sgt, dir)	do { } while (0)
#define devm_request_mem_region(dev, start, n, name)	((void *)1)
#define trace_dma_fence_emit(fence)	do { } while (0)
static inline void *vmemdup_user(const void __user *src, size_t len) { return memdup_user(src, len); }
static inline bool dma_fence_match_context(struct dma_fence *fence, u64 context) { return fence->context == context; }
#ifndef PCI_IRQ_LEGACY
#define PCI_IRQ_LEGACY	PCI_IRQ_INTX
#endif
#endif
struct virtio_device_id { __u32 device; __u32 vendor; };

struct irq_affinity;
#ifndef PCI_CAP_ID_VNDR
#define PCI_CAP_ID_VNDR		0x09
#endif
#ifndef PCI_CAPABILITY_LIST
#define PCI_CAPABILITY_LIST	0x34
#endif
/* LinuxKPI has guid_t; Linux's uuid_t is the same thing */
typedef guid_t uuid_t;
static inline void uuid_copy(uuid_t *dst, const uuid_t *src) { memcpy(dst, src, sizeof(uuid_t)); }
static inline void import_uuid(uuid_t *dst, const __u8 *src) { memcpy(dst, src, sizeof(uuid_t)); }
static inline void export_uuid(__u8 *dst, const uuid_t *src) { memcpy(dst, src, sizeof(uuid_t)); }

struct virtio_device;
struct virtqueue {
	struct list_head list;
	void (*callback)(struct virtqueue *vq);
	const char *name;
	struct virtio_device *vdev;
	unsigned int index;
	unsigned int num_free;
	void *priv;
};
typedef void vq_callback_t(struct virtqueue *);

struct virtio_shm_region { u64 addr; u64 len; };
struct virtio_config_ops {
	void (*del_vqs)(struct virtio_device *);
};

struct virtio_device {
	int index;
	bool failed;
	struct device dev;
	struct virtio_device_id id;
	const struct virtio_config_ops *config;
	void *priv;
	u64 features;
	struct list_head vqs;
	void *transport;                 /* struct vp_device of virtio_pci_shim.c */
};

struct virtio_driver {
	struct device_driver driver;
	const struct virtio_device_id *id_table;
	const unsigned int *feature_table;
	unsigned int feature_table_size;
	int (*probe)(struct virtio_device *dev);
	void (*scan)(struct virtio_device *dev);
	void (*remove)(struct virtio_device *dev);
	void (*config_changed)(struct virtio_device *dev);
};

int register_virtio_driver(struct virtio_driver *drv);
void unregister_virtio_driver(struct virtio_driver *drv);
/* module_virtio_driver(): the module glue (LKPI_DRIVER_MODULE) is in virtio_pci_shim.c, which calls these two */
#define module_virtio_driver(__virtio_driver) \
	struct virtio_driver *virtio_shim_driver = &(__virtio_driver)

static inline bool __virtio_test_bit(const struct virtio_device *vdev, unsigned int fbit) { return (vdev->features >> fbit) & 1; }
static inline bool virtio_has_feature(const struct virtio_device *vdev, unsigned int fbit) { return __virtio_test_bit(vdev, fbit); }
static inline bool virtio_has_dma_quirk(const struct virtio_device *vdev) { return true; }   /* bus addresses are physical addresses: no DMA API on the rings */
static inline bool is_virtio_device(struct device *dev) { return false; }   /* importing from another virtio device is not supported yet */

void *virtqueue_get_buf(struct virtqueue *vq, unsigned int *len);
int virtqueue_add_sgs(struct virtqueue *vq, struct scatterlist *sgs[], unsigned int out_sgs, unsigned int in_sgs, void *data, gfp_t gfp);
bool virtqueue_kick_prepare(struct virtqueue *vq);
bool virtqueue_notify(struct virtqueue *vq);
bool virtqueue_kick(struct virtqueue *vq);
bool virtqueue_enable_cb(struct virtqueue *vq);
void virtqueue_disable_cb(struct virtqueue *vq);
unsigned int virtqueue_get_vring_size(struct virtqueue *vq);
void *virtqueue_detach_unused_buf(struct virtqueue *vq);
#endif
