/* Client library: what an application links to talk to wsd (the SLS/CGS client side). */
#ifndef WS_CLIENT_H
#define WS_CLIENT_H
#include "ws.h"
#include "ws_buffer.h"

typedef struct ws_conn ws_conn;
typedef struct { ws_wid id; ws_surface *px; } ws_win;

ws_conn *ws_connect(const char *socket_path);       /* NULL path: $WS_SOCKET or the default */
void ws_disconnect(ws_conn *);
int ws_conn_screen(ws_conn *, int *w, int *h);
int ws_win_create(ws_conn *, ws_rect frame, int level, ws_win *out);
int ws_win_order(ws_conn *, ws_win *, int mode, ws_wid relative);
int ws_win_move(ws_conn *, ws_win *, int x, int y);
int ws_win_alpha(ws_conn *, ws_win *, float alpha);
int ws_win_blur(ws_conn *, ws_win *, int radius);               /* SetWindowBackgroundBlurRadius (30260): blur what is behind the window */
int ws_win_shadow(ws_conn *, ws_win *, int corner_radius, int on);
int ws_win_flush(ws_conn *, ws_win *);
int ws_win_release(ws_conn *, ws_win *);
ws_wid ws_win_find(ws_conn *, int x, int y);                   /* FindWindow (30014) */
int ws_win_get_event_mask(ws_conn *, ws_win *, int *mask);        /* GetWindowEventMask (30052) */
int ws_win_is_ordered_in(ws_conn *, ws_win *, int *in);           /* WindowIsOrderedIn (30311) */
int ws_win_list(ws_conn *, int owner, int onscreen, uint32_t *out, int max, int *total);   /* GetWindowListWithTags (30066), front to back */
void ws_raw_header(uint8_t *m, uint32_t size, int id);               /* a request header (shims build their own bodies) */
int ws_raw_call(ws_conn *, const void *req, size_t n, void *reply, size_t cap);   /* request/reply, returns the return code */
int ws_raw_simple(ws_conn *, const void *req, size_t n);          /* send a request, return its return code */
/* transactions (30429 / 30430): build the operation stream with the ws_tx_* encoders, then commit */
size_t ws_tx_packed(uint8_t *out, int64_t v);                      /* packed64 */
size_t ws_tx_float(uint8_t *out, float f);
size_t ws_tx_double(uint8_t *out, double d);
int ws_transaction_commit(ws_conn *, const uint8_t *stream, size_t n, int sync);
int ws_win_set_frame(ws_conn *, ws_win *, ws_rect frame);        /* ShapeWindow: origin and size */
int ws_win_set_resolution(ws_conn *, ws_win *, float scale);       /* SetWindowResolution (30279) */
int ws_win_get_resolution(ws_conn *, ws_win *, float *scale);      /* GetWindowResolution (30280) */
int ws_win_set_level(ws_conn *, ws_win *, int level);            /* SetWindowLevel (30012) */
int ws_win_get_level(ws_conn *, ws_win *, int *level);          /* GetWindowLevel (30013) */
int ws_win_get_alpha(ws_conn *, ws_win *, float *alpha);        /* GetWindowAlpha (30042) */
int ws_win_get_bounds(ws_conn *, ws_win *, ws_rect *r);         /* GetWindowFrameBounds (30060) */
int ws_win_get_owner(ws_conn *, ws_win *, int *owner, int *rights); /* GetWindowOwner (30070) */
int ws_win_set_sublevel(ws_conn *, ws_win *, int sublevel);       /* SetWindowSubLevel */
int ws_win_get_sublevel(ws_conn *, ws_win *, int *sublevel);       /* GetWindowSubLevel */
int ws_win_get_shape_bounds(ws_conn *, ws_win *, ws_rect *r);      /* GetWindowShapeBounds, window-relative */
int ws_win_onscreen_count(ws_conn *, int connection_id);           /* GetOnScreenWindowCount */
int ws_win_move_list(ws_conn *, const ws_win *const *w, int n, int dx, int dy);  /* MoveWindowList: relative move */
int ws_win_order_list(ws_conn *, const ws_win *const *w, const int *ops, const ws_wid *rel, int n); /* OrderWindowList */
/* Shared buffers and surfaces (the IOSurface exchange contract). A buffer is allocated by the client (GBM dma-buf when built with
 * WS_GBM and a render node exists, otherwise shared memory; WS_BUFFER=shm forces shm), registered with the server, then bound to a
 * window surface; a flush commits a finished frame. */
typedef struct { ws_buffer buf; uint32_t id; } ws_cbuf;
int ws_cbuf_create(ws_conn *, int w, int h, ws_cbuf *out);       /* CPU view in out->buf.cpu */
int ws_cbuf_release(ws_conn *, ws_cbuf *);
int ws_surface_add(ws_conn *, ws_win *, uint32_t *sid);           /* AddSurface (30090) */
int ws_surface_remove(ws_conn *, ws_win *, uint32_t sid);         /* RemoveSurface (30091) */
int ws_surface_bind_buffer(ws_conn *, ws_win *, uint32_t sid, const ws_cbuf *); /* BindSurface (30093), kind 4 */
int ws_surface_unbind(ws_conn *, ws_win *, uint32_t sid);         /* BindSurface kind 0 */
int ws_surface_binding(ws_conn *, ws_win *, uint32_t sid, int *kind, uint32_t *a, uint32_t *b); /* GetSurfaceBinding (30109) */
int ws_surface_flush(ws_conn *, ws_win *, uint32_t sid, const ws_rect *dirty); /* FlushSurface (30097); NULL = whole surface */
int ws_conn_fd(ws_conn *);                                      /* the request socket (robustness tests send raw messages on it) */
int ws_conn_id(ws_conn *);                                      /* the id returned by the NewConnectionPort handshake */
int ws_conn_event_fd(ws_conn *);                                /* the event channel from the handshake (poll it) */
/* Waits up to timeout_ms (0 = just check) for an event pushed on the event channel. 1 if one was returned. */
int ws_conn_next_pushed_event(ws_conn *, int timeout_ms, ws_event *out);
int ws_conn_pid_version(ws_conn *, int connection_id, long *pid);   /* ConnectionGetPIDAndVersion (32001) */
int ws_cursor_warp(ws_conn *, int x, int y, float interval);        /* WarpCursorPosition (30124) */
int ws_win_set_event_mask(ws_conn *, ws_win *, int mask);           /* SetWindowEventMask (30051) */
int ws_cursor_scale(ws_conn *, float *scale);                       /* GetCursorScale (30135) */
/* PostEventRecord (30121): types are CGEventType numbers (1 left down, 2 left up, 5 moved, ...) */
int ws_post_event_record(ws_conn *, const uint8_t *rec, size_t n);   /* PostEventRecord with a record as CGEventCreateData makes it */
int ws_post_mouse_event(ws_conn *, int type, float x, float y, uint32_t flags, int click_state, int button);
int ws_post_key_event(ws_conn *, int down, int keycode, uint32_t flags);                       /* GetCursorScale (30135) */                                      /* private: this connection's id */
int ws_win_count(ws_conn *, int connection_id);                 /* GetWindowCount (30063) */
int ws_inject_mouse(ws_conn *, int x, int y, int buttons);
int ws_inject_key(ws_conn *, int key, int down);
int ws_poll_event(ws_conn *, ws_win *, ws_event *out);   /* 1 if an event was returned */
int ws_screenshot(ws_conn *, const char *path);                       /* with the cursor */
int ws_screenshot_scene(ws_conn *, const char *path);                 /* windows only, no cursor (for pixel comparisons) */
int ws_server_quit(ws_conn *);
#endif
