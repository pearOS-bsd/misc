// SPDX-License-Identifier: GPL-2.0
/*
 * The virtio transport virtio_gpu needs on FreeBSD (LinuxKPI has no virtio): a PCI driver for the modern virtio-pci GPU (1af4:1050) that does what
 * Linux's virtio_pci_modern.c and virtio_ring.c do for it (capabilities, features, split virtqueues, interrupts, shared memory regions) and then hands the
 * device to the Linux driver (struct virtio_driver), the way register_virtio_driver() does there.
 * The device must be free when the module loads: devctl detach the virtio_pci instance first (wsbsd_gpu does that).
 */
#include <linux/module.h>
#include <linux/pci.h>
#include <linux/interrupt.h>
#include <linux/io.h>
#include <linux/slab.h>
#include <linux/delay.h>
#include <linux/dma-mapping.h>
#include <linux/dma-buf.h>
#include <linux/virtio.h>
#include <linux/virtio_config.h>
#include <linux/virtio_dma_buf.h>

#ifndef PCI_CAP_ID_VNDR
#define PCI_CAP_ID_VNDR 0x09
#endif
#define VIRTIO_PCI_CAP_COMMON_CFG	1
#define VIRTIO_PCI_CAP_NOTIFY_CFG	2
#define VIRTIO_PCI_CAP_ISR_CFG		3
#define VIRTIO_PCI_CAP_DEVICE_CFG	4
#define VIRTIO_PCI_CAP_SHARED_MEMORY_CFG 8
#define VIRTIO_MSI_NO_VECTOR		0xffff

/* struct virtio_pci_common_cfg, by offset */
#define CC_DFSEL	0x00
#define CC_DF		0x04
#define CC_GFSEL	0x08
#define CC_GF		0x0c
#define CC_MSIX		0x10
#define CC_NUMQ		0x12
#define CC_STATUS	0x14
#define CC_CFGGEN	0x15
#define CC_QSEL		0x16
#define CC_QSIZE	0x18
#define CC_QMSIX	0x1a
#define CC_QENABLE	0x1c
#define CC_QNOFF	0x1e
#define CC_QDESC	0x20
#define CC_QAVAIL	0x28
#define CC_QUSED	0x30

extern struct virtio_driver *virtio_shim_driver;      /* module_virtio_driver() of the Linux driver */

struct vp_device;
struct vring_virtqueue {
	struct virtqueue vq;
	struct vp_device *vp;
	unsigned int num, free_head, last_used;
	u16 avail_idx_shadow;
	struct vring_desc *desc;
	struct vring_avail *avail;
	struct vring_used *used;
	void *ring;
	dma_addr_t ring_dma;
	size_t ring_size;
	void **data;
	void __iomem *notify;
};
#define to_vvq(_vq) container_of(_vq, struct vring_virtqueue, vq)

struct vp_device {
	struct pci_dev *pdev;
	struct virtio_device vdev;
	void __iomem *bar[6];
	void __iomem *common, *isr, *devcfg;
	void __iomem *notify_base;
	u32 notify_mult;
	size_t devcfg_len;
	bool msix;
	u8 cfg_gen;
	bool probed;
};
static struct vp_device *vp_one;                      /* one virtio GPU per machine is all that is handled */

static inline u8 cc_r8(struct vp_device *vp, int o) { return readb((u8 __iomem *)vp->common + o); }
static inline u16 cc_r16(struct vp_device *vp, int o) { return readw((u8 __iomem *)vp->common + o); }
static inline u32 cc_r32(struct vp_device *vp, int o) { return readl((u8 __iomem *)vp->common + o); }
static inline void cc_w8(struct vp_device *vp, int o, u8 v) { writeb(v, (u8 __iomem *)vp->common + o); }
static inline void cc_w16(struct vp_device *vp, int o, u16 v) { writew(v, (u8 __iomem *)vp->common + o); }
static inline void cc_w32(struct vp_device *vp, int o, u32 v) { writel(v, (u8 __iomem *)vp->common + o); }
static inline void cc_w64(struct vp_device *vp, int o, u64 v) { cc_w32(vp, o, (u32)v); cc_w32(vp, o + 4, (u32)(v >> 32)); }

/* ---- capabilities ---- */
static int vp_find_cap(struct pci_dev *pdev, u8 type, u8 id, bool by_id, u8 *bar, u32 *off, u32 *len, u32 *extra)
{
	u8 pos, next, cap_id, cfg_type, cap_len, cbar, cid;
	u32 coff, clen;
	int guard = 48;
	pci_read_config_byte(pdev, PCI_CAPABILITY_LIST, &pos);
	while (pos && pos != 0xff && guard--) {
		pci_read_config_byte(pdev, pos + 0, &cap_id);
		pci_read_config_byte(pdev, pos + 1, &next);
		if (cap_id == PCI_CAP_ID_VNDR) {
			pci_read_config_byte(pdev, pos + 2, &cap_len);
			pci_read_config_byte(pdev, pos + 3, &cfg_type);
			pci_read_config_byte(pdev, pos + 4, &cbar);
			pci_read_config_byte(pdev, pos + 5, &cid);
			if (cfg_type == type && (!by_id || cid == id)) {
				pci_read_config_dword(pdev, pos + 8, &coff);
				pci_read_config_dword(pdev, pos + 12, &clen);
				*bar = cbar; *off = coff; *len = clen;
				if (extra) pci_read_config_dword(pdev, pos + 16, extra);
				return pos;
			}
		}
		pos = next;
	}
	return 0;
}
static void __iomem *vp_map(struct vp_device *vp, u8 bar, u32 off, u32 len)
{
	if (bar >= 6) return NULL;
	if (!vp->bar[bar]) vp->bar[bar] = pci_iomap(vp->pdev, bar, 0);
	if (!vp->bar[bar]) return NULL;
	(void)len;
	return (u8 __iomem *)vp->bar[bar] + off;
}

/* ---- device status, features ---- */
static void vp_set_status(struct vp_device *vp, u8 s) { cc_w8(vp, CC_STATUS, s); }
static u8 vp_get_status(struct vp_device *vp) { return cc_r8(vp, CC_STATUS); }
static u64 vp_get_features(struct vp_device *vp)
{
	u64 f;
	cc_w32(vp, CC_DFSEL, 0); f = cc_r32(vp, CC_DF);
	cc_w32(vp, CC_DFSEL, 1); f |= (u64)cc_r32(vp, CC_DF) << 32;
	return f;
}
static void vp_set_features(struct vp_device *vp, u64 f)
{
	cc_w32(vp, CC_GFSEL, 0); cc_w32(vp, CC_GF, (u32)f);
	cc_w32(vp, CC_GFSEL, 1); cc_w32(vp, CC_GF, (u32)(f >> 32));
}
void virtio_reset_device(struct virtio_device *vdev)
{
	struct vp_device *vp = vdev->transport; int i;
	vp_set_status(vp, 0);
	for (i = 0; i < 1000 && vp_get_status(vp) != 0; i++) msleep(1);
}
void virtio_device_ready(struct virtio_device *vdev)
{
	struct vp_device *vp = vdev->transport;
	vp_set_status(vp, vp_get_status(vp) | VIRTIO_CONFIG_S_DRIVER_OK);
}
void virtio_shim_cread(struct virtio_device *vdev, unsigned int offset, void *buf, unsigned int len)
{
	struct vp_device *vp = vdev->transport; u8 *p = buf; unsigned int i;
	for (i = 0; i < len; i++) p[i] = (offset + i < vp->devcfg_len) ? readb((u8 __iomem *)vp->devcfg + offset + i) : 0;
}
void virtio_shim_cwrite(struct virtio_device *vdev, unsigned int offset, const void *buf, unsigned int len)
{
	struct vp_device *vp = vdev->transport; const u8 *p = buf; unsigned int i;
	for (i = 0; i < len; i++) if (offset + i < vp->devcfg_len) writeb(p[i], (u8 __iomem *)vp->devcfg + offset + i);
}
bool virtio_get_shm_region(struct virtio_device *vdev, struct virtio_shm_region *region, u8 id)
{
	struct vp_device *vp = vdev->transport; u8 bar; u32 off, len, extra = 0;
	if (!vp_find_cap(vp->pdev, VIRTIO_PCI_CAP_SHARED_MEMORY_CFG, id, true, &bar, &off, &len, &extra)) return false;
	region->addr = (u64)pci_resource_start(vp->pdev, bar) + off;
	region->len = len;
	return true;
}

/* ---- virtqueues (split ring, no indirect descriptors, no event index) ---- */
static void vring_setup_free(struct vring_virtqueue *v)
{
	unsigned int i;
	for (i = 0; i < v->num - 1; i++) v->desc[i].next = cpu_to_le16(i + 1);
	v->desc[v->num - 1].next = 0;
	v->free_head = 0; v->vq.num_free = v->num;
}
static int vp_setup_vq(struct vp_device *vp, unsigned int index, vq_callback_t *cb, const char *name, struct virtqueue **out)
{
	struct vring_virtqueue *v; u16 num, noff; size_t desc_sz, avail_sz, used_off, total;
	cc_w16(vp, CC_QSEL, index);
	num = cc_r16(vp, CC_QSIZE);
	if (num == 0 || cc_r16(vp, CC_QENABLE)) return -ENOENT;
	if (num > 1024) num = 1024;
	while (num & (num - 1)) num &= num - 1;                       /* a power of two */
	cc_w16(vp, CC_QSIZE, num);
	v = kzalloc(sizeof(*v), GFP_KERNEL); if (!v) return -ENOMEM;
	v->vp = vp; v->num = num; v->vq.callback = cb; v->vq.name = name; v->vq.vdev = &vp->vdev; v->vq.index = index; v->vq.priv = NULL;
	desc_sz = 16 * (size_t)num; avail_sz = 6 + 2 * (size_t)num; used_off = ALIGN(desc_sz + avail_sz, 4);
	total = used_off + 6 + 8 * (size_t)num;
	v->ring_size = ALIGN(total, PAGE_SIZE);
	v->ring = dma_alloc_coherent(&vp->pdev->dev, v->ring_size, &v->ring_dma, GFP_KERNEL);
	if (!v->ring) { kfree(v); return -ENOMEM; }
	memset(v->ring, 0, v->ring_size);
	v->desc = v->ring; v->avail = (void *)((u8 *)v->ring + desc_sz); v->used = (void *)((u8 *)v->ring + used_off);
	v->data = kcalloc(num, sizeof(void *), GFP_KERNEL);
	if (!v->data) { dma_free_coherent(&vp->pdev->dev, v->ring_size, v->ring, v->ring_dma); kfree(v); return -ENOMEM; }
	vring_setup_free(v);
	cc_w64(vp, CC_QDESC, v->ring_dma);
	cc_w64(vp, CC_QAVAIL, v->ring_dma + desc_sz);
	cc_w64(vp, CC_QUSED, v->ring_dma + used_off);
	if (vp->msix) { cc_w16(vp, CC_QMSIX, 0); if (cc_r16(vp, CC_QMSIX) == VIRTIO_MSI_NO_VECTOR) vp->msix = false; }
	noff = cc_r16(vp, CC_QNOFF);
	v->notify = (u8 __iomem *)vp->notify_base + (size_t)noff * vp->notify_mult;
	cc_w16(vp, CC_QENABLE, 1);
	list_add_tail(&v->vq.list, &vp->vdev.vqs);
	*out = &v->vq;
	return 0;
}
static void vp_del_vqs(struct virtio_device *vdev)
{
	struct vp_device *vp = vdev->transport; struct virtqueue *vq, *tmp;
	list_for_each_entry_safe(vq, tmp, &vdev->vqs, list) {
		struct vring_virtqueue *v = to_vvq(vq);
		cc_w16(vp, CC_QSEL, vq->index); cc_w16(vp, CC_QENABLE, 0);
		list_del(&vq->list);
		dma_free_coherent(&vp->pdev->dev, v->ring_size, v->ring, v->ring_dma);
		kfree(v->data); kfree(v);
	}
}
static const struct virtio_config_ops vp_config_ops = { .del_vqs = vp_del_vqs };

int virtio_find_vqs(struct virtio_device *vdev, unsigned int nvqs, struct virtqueue *vqs[], vq_callback_t *callbacks[], const char * const names[], struct irq_affinity *desc)
{
	struct vp_device *vp = vdev->transport; unsigned int i; int err;
	if (vp->msix) cc_w16(vp, CC_MSIX, 0);
	for (i = 0; i < nvqs; i++) {
		err = vp_setup_vq(vp, i, callbacks[i], names[i], &vqs[i]);
		if (err) { vp_del_vqs(vdev); return err; }
	}
	return 0;
}

int virtqueue_add_sgs(struct virtqueue *_vq, struct scatterlist *sgs[], unsigned int out_sgs, unsigned int in_sgs, void *data, gfp_t gfp)
{
	struct vring_virtqueue *v = to_vvq(_vq); struct scatterlist *sg; unsigned int n, total = 0, i, head, prev = 0, avail;
	for (n = 0; n < out_sgs + in_sgs; n++) for (sg = sgs[n]; sg; sg = sg_next(sg)) total++;
	if (total == 0) return -EINVAL;
	if (total > v->vq.num_free) return -ENOSPC;
	head = i = v->free_head;
	for (n = 0; n < out_sgs + in_sgs; n++) {
		for (sg = sgs[n]; sg; sg = sg_next(sg)) {
			u16 flags = VRING_DESC_F_NEXT | (n >= out_sgs ? VRING_DESC_F_WRITE : 0);
			v->desc[i].addr = cpu_to_le64((u64)sg_phys(sg));
			v->desc[i].len = cpu_to_le32(sg->length);
			v->desc[i].flags = cpu_to_le16(flags);
			prev = i; i = le16_to_cpu(v->desc[i].next);
		}
	}
	v->desc[prev].flags &= cpu_to_le16(~VRING_DESC_F_NEXT);
	v->free_head = i; v->vq.num_free -= total;
	v->data[head] = data;
	avail = v->avail_idx_shadow & (v->num - 1);
	v->avail->ring[avail] = cpu_to_le16(head);
	wmb();
	v->avail_idx_shadow++;
	v->avail->idx = cpu_to_le16(v->avail_idx_shadow);
	return 0;
}
bool virtqueue_kick_prepare(struct virtqueue *_vq)
{
	struct vring_virtqueue *v = to_vvq(_vq);
	mb();
	return !(le16_to_cpu(v->used->flags) & VRING_USED_F_NO_NOTIFY);
}
bool virtqueue_notify(struct virtqueue *_vq)
{
	struct vring_virtqueue *v = to_vvq(_vq);
	writew(_vq->index, v->notify);
	return true;
}
bool virtqueue_kick(struct virtqueue *vq) { if (virtqueue_kick_prepare(vq)) return virtqueue_notify(vq); return true; }
static inline bool more_used(struct vring_virtqueue *v) { return v->last_used != le16_to_cpu(v->used->idx); }
void *virtqueue_get_buf(struct virtqueue *_vq, unsigned int *len)
{
	struct vring_virtqueue *v = to_vvq(_vq); unsigned int i, id; void *ret;
	if (!more_used(v)) return NULL;
	rmb();
	i = v->last_used & (v->num - 1);
	id = le32_to_cpu(v->used->ring[i].id);
	if (len) *len = le32_to_cpu(v->used->ring[i].len);
	if (id >= v->num || !v->data[id]) return NULL;
	ret = v->data[id]; v->data[id] = NULL;
	{	/* give the chain back to the free list */
		unsigned int j = id, cnt = 1;
		while (le16_to_cpu(v->desc[j].flags) & VRING_DESC_F_NEXT) { j = le16_to_cpu(v->desc[j].next); cnt++; }
		v->desc[j].next = cpu_to_le16(v->free_head);
		v->free_head = id; v->vq.num_free += cnt;
	}
	v->last_used++;
	return ret;
}
bool virtqueue_enable_cb(struct virtqueue *_vq)
{
	struct vring_virtqueue *v = to_vvq(_vq);
	v->avail->flags &= cpu_to_le16(~VRING_AVAIL_F_NO_INTERRUPT);
	mb();
	return !more_used(v);
}
void virtqueue_disable_cb(struct virtqueue *_vq) { to_vvq(_vq)->avail->flags |= cpu_to_le16(VRING_AVAIL_F_NO_INTERRUPT); }
unsigned int virtqueue_get_vring_size(struct virtqueue *_vq) { return to_vvq(_vq)->num; }
void *virtqueue_detach_unused_buf(struct virtqueue *_vq)
{
	struct vring_virtqueue *v = to_vvq(_vq); unsigned int i; void *d;
	for (i = 0; i < v->num; i++) if (v->data[i]) { d = v->data[i]; v->data[i] = NULL; return d; }
	return NULL;
}

/* ---- interrupts ---- */
static irqreturn_t vp_interrupt(int irq, void *arg)
{
	struct vp_device *vp = arg; struct virtqueue *vq; bool config = false;
	if (!vp->probed) { if (!vp->msix && vp->isr) (void)readb(vp->isr); return IRQ_HANDLED; }
	if (!vp->msix) {
		u8 isr = readb(vp->isr);                                  /* reading clears it */
		if (!isr) return IRQ_NONE;
		config = isr & 2;
	} else {
		u8 g = cc_r8(vp, CC_CFGGEN);
		if (g != vp->cfg_gen) { vp->cfg_gen = g; config = true; }
	}
	if (config && virtio_shim_driver->config_changed) virtio_shim_driver->config_changed(&vp->vdev);
	list_for_each_entry(vq, &vp->vdev.vqs, list) {
		struct vring_virtqueue *v = to_vvq(vq);
		if (more_used(v) && vq->callback) vq->callback(vq);
	}
	return IRQ_HANDLED;
}

/* ---- PCI driver ---- */
static int vp_probe(struct pci_dev *pdev, const struct pci_device_id *id)
{
	struct vp_device *vp; struct virtio_driver *drv = virtio_shim_driver; u8 bar; u32 off, len, mult = 0; u64 dev_features, want = 0; unsigned int i; int err;
	if (vp_one) return -EBUSY;
	vp = kzalloc(sizeof(*vp), GFP_KERNEL); if (!vp) return -ENOMEM;
	vp->pdev = pdev; INIT_LIST_HEAD(&vp->vdev.vqs);
	err = pci_enable_device(pdev); if (err) goto err_free;
	pci_set_master(pdev);
	if (!vp_find_cap(pdev, VIRTIO_PCI_CAP_COMMON_CFG, 0, false, &bar, &off, &len, NULL)) { err = -ENODEV; goto err_dis; }
	vp->common = vp_map(vp, bar, off, len);
	if (!vp_find_cap(pdev, VIRTIO_PCI_CAP_NOTIFY_CFG, 0, false, &bar, &off, &len, &mult)) { err = -ENODEV; goto err_dis; }
	vp->notify_base = vp_map(vp, bar, off, len); vp->notify_mult = mult;
	if (!vp_find_cap(pdev, VIRTIO_PCI_CAP_ISR_CFG, 0, false, &bar, &off, &len, NULL)) { err = -ENODEV; goto err_dis; }
	vp->isr = vp_map(vp, bar, off, len);
	if (!vp_find_cap(pdev, VIRTIO_PCI_CAP_DEVICE_CFG, 0, false, &bar, &off, &len, NULL)) { err = -ENODEV; goto err_dis; }
	vp->devcfg = vp_map(vp, bar, off, len); vp->devcfg_len = len;
	if (!vp->common || !vp->notify_base || !vp->isr || !vp->devcfg) { err = -ENOMEM; goto err_dis; }
	/* the device wakes up: reset, acknowledge, driver */
	vp->vdev.transport = vp; vp->vdev.config = &vp_config_ops;
	vp_set_status(vp, 0); for (i = 0; i < 1000 && vp_get_status(vp) != 0; i++) msleep(1);
	vp_set_status(vp, VIRTIO_CONFIG_S_ACKNOWLEDGE);
	vp_set_status(vp, vp_get_status(vp) | VIRTIO_CONFIG_S_DRIVER);
	dev_features = vp_get_features(vp);
	for (i = 0; i < drv->feature_table_size; i++) want |= 1ULL << drv->feature_table[i];
	want |= 1ULL << VIRTIO_F_VERSION_1;
	vp->vdev.features = dev_features & want;
	if (!(vp->vdev.features & (1ULL << VIRTIO_F_VERSION_1))) { dev_err(&pdev->dev, "virtio_gpu: the device is not virtio 1.0\n"); err = -ENODEV; goto err_fail; }
	vp_set_features(vp, vp->vdev.features);
	vp_set_status(vp, vp_get_status(vp) | VIRTIO_CONFIG_S_FEATURES_OK);
	if (!(vp_get_status(vp) & VIRTIO_CONFIG_S_FEATURES_OK)) { dev_err(&pdev->dev, "virtio_gpu: features not accepted\n"); err = -ENODEV; goto err_fail; }
	/* the interrupt: one MSI-X vector for the queues and the configuration, else INTx and the ISR byte */
	err = pci_alloc_irq_vectors(pdev, 1, 1, PCI_IRQ_MSIX | PCI_IRQ_LEGACY);
	if (err < 0) goto err_fail;
	vp->msix = pdev->msix_enabled ? true : false;
	vp->cfg_gen = cc_r8(vp, CC_CFGGEN);
	err = request_irq(pci_irq_vector(pdev, 0), vp_interrupt, IRQF_SHARED, "virtio_gpu", vp);
	if (err) { pci_free_irq_vectors(pdev); goto err_fail; }
	vp->vdev.dev.parent = &pdev->dev;
	vp->vdev.id.device = pdev->device - 0x1040; vp->vdev.id.vendor = pdev->subsystem_vendor;
	vp->vdev.index = 0; dev_set_name(&vp->vdev.dev, "virtio0");
	vp_one = vp;
	err = drv->probe(&vp->vdev);                                   /* virtio_gpu_probe(): find_vqs, DRM registration */
	if (err) { vp_one = NULL; free_irq(pci_irq_vector(pdev, 0), vp); pci_free_irq_vectors(pdev); goto err_fail; }
	vp->probed = true;
	pci_set_drvdata(pdev, vp);
	return 0;
err_fail:
	vp_set_status(vp, VIRTIO_CONFIG_S_FAILED);
err_dis:
	pci_disable_device(pdev);
err_free:
	kfree(vp);
	return err;
}
static void vp_remove(struct pci_dev *pdev)
{
	struct vp_device *vp = pci_get_drvdata(pdev); if (!vp) return;
	vp->probed = false;
	if (virtio_shim_driver->remove) virtio_shim_driver->remove(&vp->vdev);
	virtio_reset_device(&vp->vdev);
	free_irq(pci_irq_vector(pdev, 0), vp); pci_free_irq_vectors(pdev);
	pci_disable_device(pdev);
	vp_one = NULL; kfree(vp);
}
static const struct pci_device_id vp_ids[] = { { PCI_DEVICE(0x1af4, 0x1050) }, { 0, } };
static struct pci_driver vp_pci_driver = {
	.name = "virtio_gpu", .id_table = vp_ids, .probe = vp_probe, .remove = vp_remove,
	.bsd_probe_return = BUS_PROBE_DEFAULT + 1,                    /* before FreeBSD's virtio_pci, when the device is free */
};
int register_virtio_driver(struct virtio_driver *drv) { (void)drv; return linux_pci_register_driver(&vp_pci_driver); }
void unregister_virtio_driver(struct virtio_driver *drv) { (void)drv; linux_pci_unregister_driver(&vp_pci_driver); }

/* ---- virtio_dma_buf (drivers/virtio/virtio_dma_buf.c) ---- */
struct dma_buf *virtio_dma_buf_export(const struct dma_buf_export_info *exp_info)
{
	const struct virtio_dma_buf_ops *vops;
	if (!exp_info->ops || exp_info->ops->attach != &virtio_dma_buf_attach) return ERR_PTR(-EINVAL);
	vops = container_of(exp_info->ops, struct virtio_dma_buf_ops, ops);
	if (!vops->get_uuid) return ERR_PTR(-EINVAL);
	return dma_buf_export(exp_info);
}
int virtio_dma_buf_attach(struct dma_buf *dma_buf, struct dma_buf_attachment *attach)
{
	const struct virtio_dma_buf_ops *vops = container_of(dma_buf->ops, struct virtio_dma_buf_ops, ops);
	return vops->device_attach ? vops->device_attach(dma_buf, attach) : 0;
}
bool is_virtio_dma_buf(struct dma_buf *dma_buf) { return dma_buf->ops->attach == &virtio_dma_buf_attach; }
int virtio_dma_buf_get_uuid(struct dma_buf *dma_buf, uuid_t *uuid)
{
	const struct virtio_dma_buf_ops *vops = container_of(dma_buf->ops, struct virtio_dma_buf_ops, ops);
	if (!is_virtio_dma_buf(dma_buf)) return -EINVAL;
	return vops->get_uuid(dma_buf, uuid);
}

static int __init virtio_gpu_shim_init(void) { return register_virtio_driver(virtio_shim_driver); }
static void __exit virtio_gpu_shim_exit(void) { unregister_virtio_driver(virtio_shim_driver); }
LKPI_DRIVER_MODULE(virtio_gpu, virtio_gpu_shim_init, virtio_gpu_shim_exit);
MODULE_DEPEND(virtio_gpu, drmn, 2, 2, 2);
MODULE_DEPEND(virtio_gpu, ttm, 1, 1, 1);
MODULE_DEPEND(virtio_gpu, agp, 1, 1, 1);
MODULE_DEPEND(virtio_gpu, linuxkpi, 1, 1, 1);
MODULE_DEPEND(virtio_gpu, dmabuf, 1, 1, 1);
MODULE_LICENSE("GPL");
