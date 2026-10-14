#include "ws_buffer.h"
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/mman.h>

size_t ws_buffer_stride_for(int w, int bpp) { size_t s = (size_t)w * (size_t)bpp; return (s + 127) & ~(size_t)127; }
size_t ws_buffer_alloc_size(size_t stride, int h) { size_t n = stride * (size_t)h; return (n + 16383) & ~(size_t)16383; }
int ws_buffer_bytes_per_pixel(uint32_t fourcc) { return fourcc == WS_FOURCC_ARGB8888 ? 4 : 0; }

void ws_buffer_init(ws_buffer *b)
{
	memset(b, 0, sizeof *b);
	for (int i = 0; i < WS_BUF_MAX_PLANES; i++) b->fd[i] = -1;
	b->modifier = ~0ULL;
}

int ws_buffer_create_shm(ws_buffer *b, int w, int h, uint32_t fourcc)
{
	int bpp = ws_buffer_bytes_per_pixel(fourcc);
	if (!bpp || w <= 0 || h <= 0 || w > 16384 || h > 16384) return -1;
	ws_buffer_init(b);
	size_t stride = ws_buffer_stride_for(w, bpp), size = ws_buffer_alloc_size(stride, h);
	static unsigned counter;
	char name[40];
	snprintf(name, sizeof name, "/wsb.%d.%u", (int)getpid(), ++counter);
	int fd = shm_open(name, O_RDWR | O_CREAT | O_EXCL, 0600);
	if (fd < 0) return -1;
	shm_unlink(name);
	if (ftruncate(fd, (off_t)size) < 0) { close(fd); return -1; }
	b->kind = WS_BUF_SHM; b->w = w; b->h = h; b->fourcc = fourcc; b->nplanes = 1;
	b->stride[0] = (uint32_t)stride; b->offset[0] = 0; b->modifier = 0; b->fd[0] = fd;
	if (ws_buffer_map(b)) { close(fd); b->fd[0] = -1; return -1; }
	return 0;
}

int ws_buffer_map(ws_buffer *b)
{
	int bpp = ws_buffer_bytes_per_pixel(b->fourcc);
	if (!bpp || b->nplanes < 1 || b->fd[0] < 0 || b->w <= 0 || b->h <= 0) return -1;
	if (b->stride[0] < (uint32_t)(b->w * bpp)) return -1;
	if (b->kind == WS_BUF_DMABUF && b->modifier != 0 && b->modifier != ~0ULL) return -1;     /* tiled: needs the GPU path */
	size_t len = (size_t)b->offset[0] + (size_t)b->stride[0] * (size_t)b->h;
	void *m = mmap(NULL, len, PROT_READ | PROT_WRITE, MAP_SHARED, b->fd[0], 0);
	if (m == MAP_FAILED) return -1;
	ws_surface *s = calloc(1, sizeof *s);
	if (!s) { munmap(m, len); return -1; }
	s->w = b->w; s->h = b->h; s->stride = b->stride[0]; s->px = (uint8_t *)m + b->offset[0]; s->map = m; s->maplen = len;
	b->cpu = s;
	return 0;
}

void ws_buffer_close(ws_buffer *b)
{
	if (b->cpu) { if (b->cpu->map) munmap(b->cpu->map, b->cpu->maplen); free(b->cpu); b->cpu = NULL; }
	for (int i = 0; i < WS_BUF_MAX_PLANES; i++) if (b->fd[i] >= 0) { close(b->fd[i]); b->fd[i] = -1; }
	/* gbm_bo and egl_image are released by their owners (ws_gbm / the compositor) */
}

#ifdef WS_GBM
#include <gbm.h>

struct gbm_device *ws_gbm_open(const char *node)
{
	int fd = open(node, O_RDWR | O_CLOEXEC);
	if (fd < 0) return NULL;
	struct gbm_device *d = gbm_create_device(fd);
	if (!d) close(fd);
	return d;
}

void ws_gbm_close(struct gbm_device *d)
{
	if (!d) return;
	int fd = gbm_device_get_fd(d);
	gbm_device_destroy(d);
	if (fd >= 0) close(fd);
}

int ws_buffer_create_gbm(ws_buffer *b, struct gbm_device *dev, int w, int h)
{
	if (!dev || w <= 0 || h <= 0) return -1;
	ws_buffer_init(b);
	/* linear, so the compositor (and the CPU fallback) can read it back; usable as a render target */
	struct gbm_bo *bo = gbm_bo_create(dev, (uint32_t)w, (uint32_t)h, GBM_FORMAT_ARGB8888, GBM_BO_USE_RENDERING | GBM_BO_USE_LINEAR);
	if (!bo) return -1;
	int fd = gbm_bo_get_fd(bo);                               /* the dma-buf descriptor */
	if (fd < 0) { gbm_bo_destroy(bo); return -1; }
	b->kind = WS_BUF_DMABUF; b->w = w; b->h = h; b->fourcc = WS_FOURCC_ARGB8888; b->nplanes = 1;
	b->stride[0] = gbm_bo_get_stride(bo); b->offset[0] = 0; b->modifier = gbm_bo_get_modifier(bo); b->fd[0] = fd; b->gbm_bo = bo;
	if (b->modifier == 0x00ffffffffffffffULL) b->modifier = ~0ULL;   /* DRM_FORMAT_MOD_INVALID */
	if (ws_buffer_map(b)) {                                   /* mmap of the dma-buf for CPU drawing; not all drivers allow it */
		void *map_data = NULL; uint32_t st = 0;
		void *p = gbm_bo_map(bo, 0, 0, (uint32_t)w, (uint32_t)h, GBM_BO_TRANSFER_READ_WRITE, &st, &map_data);
		if (!p) { gbm_bo_destroy(bo); close(fd); b->fd[0] = -1; b->gbm_bo = NULL; return -1; }
		ws_surface *s = calloc(1, sizeof *s);
		if (!s) { gbm_bo_unmap(bo, map_data); gbm_bo_destroy(bo); close(fd); b->fd[0] = -1; return -1; }
		s->w = w; s->h = h; s->stride = st; s->px = p;           /* not owned by us: unmapped with the bo */
		b->cpu = s;
	}
	return 0;
}
#endif

#ifdef WS_EGL
#include <EGL/egl.h>
#include <EGL/eglext.h>

void *ws_buffer_egl_import(ws_buffer *b, void *dpy)
{
	if (b->kind != WS_BUF_DMABUF || b->fd[0] < 0 || b->nplanes != 1) return NULL;
	PFNEGLCREATEIMAGEKHRPROC create = (PFNEGLCREATEIMAGEKHRPROC)eglGetProcAddress("eglCreateImageKHR");
	if (!create) return NULL;
	EGLint attr[32]; int n = 0;
	attr[n++] = EGL_WIDTH; attr[n++] = b->w;
	attr[n++] = EGL_HEIGHT; attr[n++] = b->h;
	attr[n++] = EGL_LINUX_DRM_FOURCC_EXT; attr[n++] = (EGLint)b->fourcc;
	attr[n++] = EGL_DMA_BUF_PLANE0_FD_EXT; attr[n++] = b->fd[0];
	attr[n++] = EGL_DMA_BUF_PLANE0_OFFSET_EXT; attr[n++] = (EGLint)b->offset[0];
	attr[n++] = EGL_DMA_BUF_PLANE0_PITCH_EXT; attr[n++] = (EGLint)b->stride[0];
	if (b->modifier != ~0ULL) {                               /* explicit modifier, when the driver reported one */
		attr[n++] = EGL_DMA_BUF_PLANE0_MODIFIER_LO_EXT; attr[n++] = (EGLint)(b->modifier & 0xffffffffu);
		attr[n++] = EGL_DMA_BUF_PLANE0_MODIFIER_HI_EXT; attr[n++] = (EGLint)(b->modifier >> 32);
	}
	attr[n++] = EGL_NONE;
	EGLImageKHR img = create((EGLDisplay)dpy, EGL_NO_CONTEXT, EGL_LINUX_DMA_BUF_EXT, (EGLClientBuffer)0, attr);
	return img == EGL_NO_IMAGE_KHR ? NULL : (void *)img;
}
#endif
