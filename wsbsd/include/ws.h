/* wsbsd - window server for FreeBSD (no X11/Wayland).
 * Clean-room reimplementation of the behaviour observed in macOS SkyLight.
 * Pixel format everywhere: 32-bit BGRA, premultiplied alpha (as CompositorSW). */
#ifndef WS_H
#define WS_H

#include <stdint.h>
#include <stddef.h>

typedef struct { int32_t x, y, w, h; } ws_rect;

/* A pixel buffer. Stands in for IOSurface: later backed by shm / memfd. */
typedef struct {
	int w, h;
	size_t stride;          /* bytes per row */
	uint8_t *px;            /* BGRA, premultiplied */
	void *map;              /* non-NULL: px lives in a shared mapping (shm), freed with munmap */
	size_t maplen;
} ws_surface;

ws_surface *ws_surface_new(int w, int h);
/* Shared-memory surface (the IOSurface stand-in). name like "/wsd.123.4"; create=1 makes it. */
ws_surface *ws_surface_shm(const char *name, int w, int h, int create);
void ws_shm_unlink(const char *name);
/* Anonymous shared surface: returns the mapped surface and a descriptor to pass to another process. */
ws_surface *ws_surface_shm_anon(int w, int h, int *fd_out);
ws_surface *ws_surface_from_fd(int fd, int w, int h);
void ws_surface_free(ws_surface *s);

/* Compositor (CPU). Mirrors CompositorSW: FillSurface, CopySurface, CompositeLayers. */
void ws_fill(ws_surface *s, ws_rect r, float red, float green, float blue, float alpha);
void ws_copy(ws_surface *dst, int dx, int dy, const ws_surface *src, ws_rect sr);
/* Source-over of src into dst at (dx,dy), scaled by opacity 0..1, clipped to clip. */
void ws_over(ws_surface *dst, int dx, int dy, const ws_surface *src, float opacity, ws_rect clip);

/* Compositor backend interface. SkyLight has CompositorSW / CompositorMetal / CompositorNoop;
 * here: sw (CPU, below), gl (EGL/GLES2 on GBM via drm-kmod + Mesa, planned), noop. */
typedef struct ws_compositor ws_compositor;
struct ws_compositor {
	const char *name;
	void (*fill)(ws_compositor *, ws_surface *dst, ws_rect r, float red, float green, float blue, float alpha);
	void (*over)(ws_compositor *, ws_surface *dst, int dx, int dy, const ws_surface *src, float opacity, ws_rect clip);
	void (*flush)(ws_compositor *);   /* GPU: submit and fence; CPU: no-op */
	void *priv;
};
extern ws_compositor ws_compositor_sw;
ws_compositor *ws_compositor_get(const char *name);   /* "sw", later "gl"; NULL if unavailable */

/* Server model (subset of the SkyLight routines: CreateWindow, MoveWindow, OrderWindow,
 * SetWindowLevel, SetWindowAlpha, ...). Window ids start at 1; 0 means "none". */
typedef struct ws_server ws_server;
typedef uint32_t ws_wid;
enum { WS_BELOW = -1, WS_ABOVE = 1, WS_OUT = 0 };

ws_server *ws_server_new(int screen_w, int screen_h);
void ws_server_free(ws_server *);
ws_wid ws_create_window(ws_server *, ws_rect frame);         /* heap backing store */
ws_wid ws_create_window_shm(ws_server *, ws_rect frame, char name[32]); /* shm backing, name returned */
ws_wid ws_create_window_fd(ws_server *, ws_rect frame, uint32_t owner, int *fd_out); /* anonymous shm backing, fd returned */
void ws_set_window_shape(ws_server *, ws_wid, const ws_rect *abs_rects, int n);      /* region in screen coordinates; hit testing uses it */
uint32_t ws_window_owner(ws_server *, ws_wid);
int ws_window_frame(ws_server *, ws_wid, ws_rect *out);
int ws_resize_window(ws_server *, ws_wid, int w, int h);       /* new size, same origin; pixels come from the bound buffer */
int ws_window_level(ws_server *, ws_wid, int *level);
int ws_window_alpha(ws_server *, ws_wid, float *alpha);
int ws_count_owned(ws_server *, uint32_t owner);
int ws_count_onscreen_owned(ws_server *, uint32_t owner);
int ws_window_exists(ws_server *, ws_wid);
int ws_window_on_screen(ws_server *, ws_wid);                 /* 1 when ordered in */
int ws_set_window_sublevel(ws_server *, ws_wid, int sublevel);                      /* a 16-bit value, ordered after the level */
int ws_window_sublevel(ws_server *, ws_wid, int *sublevel);
int ws_window_shape_bounds(ws_server *, ws_wid, ws_rect *out);
/* Bound content (a shared buffer's CPU view, borrowed): composed in place of the backing store once committed. */
int ws_window_set_content(ws_server *, ws_wid, ws_surface *content, uint32_t buffer_id); /* NULL unbinds; clears the committed state */
int ws_window_commit(ws_server *, ws_wid);                               /* the client finished a frame: content is ready to compose */
/* FlushSurface: copies the dirty rectangle (NULL = everything) of the bound content into the window's committed image and marks it dirty.
 * Only what was flushed is shown: a change to the buffer that was not flushed does not appear. */
int ws_window_flush_rect(ws_server *, ws_wid, const ws_rect *dirty);
uint64_t ws_server_generation(const ws_server *);                       /* increases whenever anything that affects the rendered scene changes */
void ws_server_drop_content(ws_server *, const ws_surface *content);     /* a buffer is going away */                                      /* windows held by a connection */
void ws_release_owner(ws_server *, uint32_t owner);                                  /* a connection went away */
int ws_set_window_shadow(ws_server *, ws_wid, int corner_radius, int enabled);
ws_wid ws_active_window(ws_server *);                        /* frontmost window that has a shadow */
int ws_release_window(ws_server *, ws_wid);
ws_surface *ws_window_backing(ws_server *, ws_wid);
int ws_move_window(ws_server *, ws_wid, int x, int y);
int ws_order_window(ws_server *, ws_wid, int mode, ws_wid relative); /* WS_ABOVE/WS_BELOW/WS_OUT */
int ws_set_window_level(ws_server *, ws_wid, int level);
int ws_set_window_alpha(ws_server *, ws_wid, float alpha);
ws_wid ws_find_window(ws_server *, int x, int y);            /* topmost on-screen at point */
void ws_server_set_compositor(ws_server *, ws_compositor *);  /* default: sw */
void ws_compose(ws_server *, ws_surface *screen);            /* one full frame */

/* Input and cursor. The server is fed absolute pointer positions and key events by a backend (evdev on FreeBSD,
 * injection in tests); it picks the target window, raises on click, grabs while a button is held and queues
 * events per window. Clients drain their window's queue. */
enum { WS_EV_NONE = 0, WS_EV_MOUSE_MOVE, WS_EV_MOUSE_DOWN, WS_EV_MOUSE_UP, WS_EV_KEY_DOWN, WS_EV_KEY_UP, WS_EV_FOCUS_IN, WS_EV_FOCUS_OUT };
typedef struct { int type; ws_wid wid; int x, y;   /* x,y are window-local */ int buttons, key; } ws_event;
void ws_server_mouse(ws_server *, int x, int y, int buttons);   /* absolute, screen coordinates; buttons bitmask */
void ws_server_key(ws_server *, int key, int down);
int ws_next_event(ws_server *, ws_wid, ws_event *out);          /* 1 if an event was returned */
void ws_cursor_pos(ws_server *, int *x, int *y);
ws_wid ws_key_window(ws_server *);
typedef void (*ws_event_sink)(void *ctx, uint32_t owner, const ws_event *e);
void ws_server_set_event_sink(ws_server *, ws_event_sink fn, void *ctx);          /* called for every event queued for a window */
void ws_server_warp_cursor(ws_server *, int x, int y);
int ws_server_buttons(ws_server *);
int ws_set_window_event_mask(ws_server *, ws_wid, int mask);
int ws_window_event_mask(ws_server *, ws_wid, int *mask);
void ws_cursor_show(ws_server *, int visible);

/* Key focus, the theft model of CGXStealKeyFocusReturningID / CGXReleaseKeyFocusWithID (decompiled). A connection takes key focus either
 * plainly (theft id 0) or with a theft id (>= 0x65, a counter shared by all connections that wraps at 0x7fffffff back to 0x65); releasing
 * by id hands focus back to the previous holder. Returns 0, 1010 (nothing to do / not permitted) or -600 (unknown connection). */
#define WS_KEYFOCUS_FIRST_ID 0x65
int ws_keyfocus_steal(ws_server *, uint32_t cid, int options, int want_id, int *id_out);
int ws_keyfocus_release(ws_server *, uint32_t cid, int id);
uint32_t ws_keyfocus_holder(ws_server *, int *is_default);        /* connection holding key focus, 0 if none; default: nobody stole it */
/* Cursor visibility as the real routines keep it: a hide count per connection, a "force show" that clears one connection's count, and
 * obscure/reveal (hidden until the mouse moves). The cursor is drawn when no count is set, it is not obscured and ws_cursor_show is on. */
void ws_cursor_hide(ws_server *, uint32_t cid);
void ws_cursor_unhide(ws_server *, uint32_t cid, int force);
void ws_cursor_obscure(ws_server *, uint32_t cid);
void ws_cursor_reveal(ws_server *, uint32_t cid);

/* Renderer interface for GPU compositors: a back-to-front walk over the on-screen windows with everything a renderer needs to draw one
 * (geometry, opacity, corner radius, pixels, shadow layer, damage since the last frame). */
typedef struct {
	ws_wid id;
	ws_rect frame;
	float alpha;
	int corner_radius;              /* from the window's shadow settings; 0 if none */
	int active;                     /* the window that gets the active shadow */
	const ws_surface *pixels;       /* committed bound content if any, else the backing store (CPU view) */
	uint32_t buffer_id;             /* registered buffer the pixels come from, 0 for the backing store */
	const ws_surface *shadow;       /* premultiplied shadow layer or NULL; drawn above the window at (shadow_x, shadow_y) */
	int shadow_x, shadow_y;
	uint32_t shadow_gen;            /* changes whenever the shadow layer is rebuilt */
	ws_rect damage;                 /* union of the dirty rectangles since the last frame, window-local */
	int has_damage, full_damage;    /* full_damage: the whole content changed (new window, resize, new buffer) */
} ws_visit;
typedef void (*ws_visit_fn)(void *ctx, const ws_visit *v);
void ws_server_walk(ws_server *, ws_visit_fn fn, void *ctx);              /* bottom to top, on-screen windows only */
void ws_window_damage(ws_server *, ws_wid, const ws_rect *r);            /* r = NULL: the whole content changed */
void ws_server_clear_damage(ws_server *);                                /* after a frame was rendered */
void ws_draw_cursor(ws_server *, ws_surface *screen);                    /* software cursor onto a rendered frame */
/* The cursor is independent of every window buffer: an image with a hotspot and a position. A KMS backend puts the image on the hardware
 * cursor plane and only moves it; the software path blends it onto the finished frame. */
const ws_surface *ws_cursor_image(ws_server *, int *hot_x, int *hot_y);
uint32_t ws_cursor_serial(const ws_server *);                            /* changes when the image changes */
int ws_cursor_visible(const ws_server *);
void ws_server_set_cursor_image(ws_server *, const ws_surface *img, int hot_x, int hot_y);   /* copies; NULL restores the default arrow */
void ws_compose_scene(ws_server *, ws_surface *screen);                  /* windows only, no cursor */
void ws_server_desktop_color(ws_server *, float rgb[3]);
void ws_blur_region(ws_surface *img, ws_rect r, float sigma);            /* gaussian blur in place (premultiplied BGRA, clamped edges) */
/* Background blur behind a window (SetWindowBackgroundBlurRadius): radius in points (0..60), the compositor blurs what is behind the window before drawing it. */
int ws_set_window_blur(ws_server *, ws_wid, int radius, int flag, float amount);
int ws_window_blur(ws_server *, ws_wid, int *radius, int *flag, float *amount);
int ws_server_has_blur(ws_server *);                                     /* any on-screen window with a blur: such frames are composed in software */

/* Backends. headless writes PPM; drm (FreeBSD KMS) comes next. */
/* Shadow generator. Model recovered from SkyLight's ShadowVerticalBlurRGBA shader (see docs/DESIGN.md).
 * All windows-space quantities are in pixels. radius = (int)(stdev * 2.8), as in WSWindowShadowSigmaToRadius. */
typedef struct {
	float stdev;            /* gaussian sigma of the diffuse shadow */
	float density;          /* diffuse shadow opacity */
	float vertical_offset;  /* diffuse shadow is shifted down by this many pixels */
	float rim_density;      /* thin outer rim, outside the window shape */
	float rim_radius;       /* rim blur radius (sigma = radius / 2.8) */
	float inner_rim_density;/* white rim inside the window edge */
	float inner_rim_radius;
	int rim_white;          /* outer rim colour: 1 white, 0 black */
} ws_shadow_params;

ws_shadow_params ws_shadow_defaults(int active);
/* Returns a (w+2*pad)x(h+2*pad) premultiplied BGRA surface for a rounded-rect window of w x h placed at
 * (pad,pad). Draw it at (x-pad, y-pad) on top of the window: the shadow is cut out of the window shape and the
 * inner rim lies inside it. Built in nine parts from a cached prototype when large enough. */
ws_surface *ws_shadow_make(int w, int h, int corner_radius, const ws_shadow_params *p, int *pad_out);
int ws_write_ppm(const ws_surface *s, const char *path);

#endif
