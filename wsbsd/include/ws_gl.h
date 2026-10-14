/* GPU compositor: OpenGL ES 2 through EGL on a DRM device (Mesa on FreeBSD: i915/amdgpu/radeon via drm-kmod, or any EGL driver).
 * Compile with -DWS_GL -DWS_GBM -DWS_EGL. UNTESTED: written without access to an EGL/GLES implementation (see docs/DESIGN.md).
 * Runtime fallback: glc_create returns NULL when EGL or GLES2 cannot be initialised, and the caller keeps the software compositor. */
#ifndef WS_GL_H
#define WS_GL_H
#include "ws.h"
#include "ws_buffer.h"

typedef struct gl_compositor gl_compositor;

/* drm_node: e.g. "/dev/dri/renderD128" or "/dev/dri/card0" (EGL on GBM), NULL: EGL's default or surfaceless display. */
gl_compositor *glc_create(const char *drm_node, int width, int height);
void glc_destroy(gl_compositor *);

/* Hardware path: import a dma-buf buffer as an EGLImageKHR (EGL_LINUX_DMA_BUF_EXT) bound to a GL_TEXTURE_2D. 0 on success; -1 when the
 * extension is missing at runtime or the buffer is not a dma-buf, in which case the buffer is simply composed through the upload path. */
int glc_import_buffer(gl_compositor *, const ws_buffer *);
void glc_forget_buffer(gl_compositor *, uint32_t buffer_id);

/* One frame: walks the windows bottom to top, draws every on-screen window (and its shadow layer) into the target and waits for completion. */
int compositor_render_frame(gl_compositor *, ws_server *);

/* The finished frame as premultiplied BGRA (screenshots, headless runs, scanning out through a dumb buffer). dst must be width x height. */
int glc_read_pixels(gl_compositor *, ws_surface *dst);
/* Zero-copy hand-off to scan-out: the render target as a dma-buf (EGL_MESA_image_dma_buf_export). 0 on success. */
int glc_export_target(gl_compositor *, int *fd, uint32_t *fourcc, uint32_t *stride, uint32_t *offset, uint64_t *modifier);

int glc_has_dmabuf_import(const gl_compositor *);
const char *glc_describe(const gl_compositor *);
#endif
