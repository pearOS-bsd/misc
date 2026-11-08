/* SPDX-License-Identifier: GPL-2.0 */
#ifndef _LINUX_VIRTIO_DMA_BUF_H
#define _LINUX_VIRTIO_DMA_BUF_H
#include <linux/dma-buf.h>
#include <linux/uuid.h>
#include <linux/virtio.h>

struct virtio_dma_buf_ops {
	struct dma_buf_ops ops;
	int (*device_attach)(struct dma_buf *dma_buf, struct dma_buf_attachment *attach);
	int (*get_uuid)(struct dma_buf *dma_buf, uuid_t *uuid);
};
int virtio_dma_buf_attach(struct dma_buf *dma_buf, struct dma_buf_attachment *attach);
struct dma_buf *virtio_dma_buf_export(const struct dma_buf_export_info *exp_info);
bool is_virtio_dma_buf(struct dma_buf *dma_buf);
int virtio_dma_buf_get_uuid(struct dma_buf *dma_buf, uuid_t *uuid);
#endif
