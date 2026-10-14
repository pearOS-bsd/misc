/* Shared pixel buffers: the FreeBSD counterpart of the IOSurface exchange contract.
 * Contract facts (public IOSurface API, probed on macOS 27.0): the client picks width, height, pixel format and gets a row stride aligned to
 * 128 bytes and an allocation rounded up to 16 KiB; the buffer is handed to another process as a transferable right (a Mach port there,
 * file descriptors over SCM_RIGHTS here). Backends: anonymous shared memory (always available) and DRM dma-buf allocated through GBM and
 * imported by the server as an EGLImage (compile with -DWS_GBM / -DWS_EGL; UNTESTED, no FreeBSD GPU was available). */
#ifndef WS_BUFFER_H
#define WS_BUFFER_H
#include "ws.h"

#define WS_FOURCC_ARGB8888 0x34325241u          /* DRM_FORMAT_ARGB8888 'AR24' == IOSurface 'BGRA': B,G,R,A bytes, premultiplied here */
#define WS_BUF_MAX_PLANES 4

enum { WS_BUF_SHM = 0, WS_BUF_DMABUF = 1 };

typedef struct {
	uint32_t id;
	int kind;                                    /* WS_BUF_SHM or WS_BUF_DMABUF */
	int w, h;
	uint32_t fourcc;
	int nplanes;
	uint32_t stride[WS_BUF_MAX_PLANES], offset[WS_BUF_MAX_PLANES];
	uint64_t modifier;                           /* DRM format modifier; 0 = linear, ~0 = invalid/unspecified */
	int fd[WS_BUF_MAX_PLANES];                   /* owned descriptors, -1 when none */
	ws_surface *cpu;                             /* CPU view of plane 0 when it is linearly mappable */
	void *gbm_bo;                                /* GBM buffer object (client side), NULL otherwise */
	void *egl_image;                             /* EGLImageKHR once imported by the compositor, NULL otherwise */
	uint32_t owner;                              /* connection that created it (server side) */
} ws_buffer;

size_t ws_buffer_stride_for(int w, int bytes_per_pixel);       /* row stride aligned to 128 bytes */
size_t ws_buffer_alloc_size(size_t stride, int h);             /* rounded up to 16 KiB */
int ws_buffer_bytes_per_pixel(uint32_t fourcc);                /* 0 if the format is not supported */

void ws_buffer_init(ws_buffer *b);
/* Anonymous shared-memory buffer, mapped; fd[0] can be passed to another process. 0 on success. */
int ws_buffer_create_shm(ws_buffer *b, int w, int h, uint32_t fourcc);
/* Maps an imported descriptor (shm or a linear dma-buf) so the CPU compositor can read it. 0 on success. */
int ws_buffer_map(ws_buffer *b);
void ws_buffer_close(ws_buffer *b);

#ifdef WS_GBM
struct gbm_device;
struct gbm_device *ws_gbm_open(const char *render_node);       /* e.g. /dev/dri/renderD128; NULL on failure */
void ws_gbm_close(struct gbm_device *);
/* Allocates a linear scan-out/render capable buffer with gbm_bo_create, maps it for CPU drawing and exports it as a dma-buf. */
int ws_buffer_create_gbm(ws_buffer *b, struct gbm_device *dev, int w, int h);
#endif
#ifdef WS_EGL
/* Server side: eglCreateImageKHR(EGL_LINUX_DMA_BUF_EXT) for a dma-buf buffer. Returns the EGLImageKHR or NULL. */
void *ws_buffer_egl_import(ws_buffer *b, void *egl_display);
#endif
#endif
