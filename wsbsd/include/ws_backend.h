/* Display and input backends for FreeBSD. UNTESTED: written against libdrm and <dev/evdev/input.h>, never run
 * (no FreeBSD machine was available). Build with `gmake BACKEND=kms` on FreeBSD. */
#ifndef WS_BACKEND_H
#define WS_BACKEND_H
#include "ws.h"

#ifdef WS_KMS
typedef struct ws_kms ws_kms;
ws_kms *ws_kms_open(const char *card, int *w, int *h);      /* e.g. /dev/dri/card0; NULL on failure */
int ws_kms_fd(ws_kms *);                                    /* poll this for page-flip completion */
ws_surface *ws_kms_back(ws_kms *);                          /* surface to compose into (maps a dumb buffer) */
int ws_kms_present_ready(ws_kms *);                         /* 1 if no flip is pending (a new frame may be queued) */
int ws_kms_present(ws_kms *);                               /* queue a page flip of the back buffer: 0 queued, 1 skipped (flip pending), -1 error */
/* Hardware cursor plane. The image is premultiplied BGRA (ARGB8888); only moving it needs no new frame. */
int ws_kms_cursor_supported(ws_kms *);
int ws_kms_cursor_set(ws_kms *, const ws_surface *img, int hot_x, int hot_y);
int ws_kms_cursor_move(ws_kms *, int x, int y);              /* x, y: the top-left corner of the image on screen */
void ws_kms_pause(ws_kms *);                                /* the VT was switched away: drop DRM master */
int ws_kms_resume(ws_kms *);                                /* the VT is back: take DRM master, show the front buffer again; -1 on failure */
int ws_kms_handle_events(ws_kms *);                         /* call when ws_kms_fd is readable */
void ws_kms_close(ws_kms *);

typedef struct ws_evdev ws_evdev;
ws_evdev *ws_evdev_open(const char *dir);                   /* opens every /dev/input/event* it can read */
int ws_evdev_count(ws_evdev *);
int ws_evdev_fd(ws_evdev *, int i);
/* Reads pending events from fd i and feeds the server; returns -1 if the device went away. */
int ws_evdev_dispatch(ws_evdev *, int i, ws_server *, int screen_w, int screen_h);
int ws_evdev_drain(ws_evdev *, int i);                      /* read and discard pending events (another VT is active); -1 if the device went away */
int ws_evdev_rescan(ws_evdev *);                           /* opens devices that appeared since (USB keyboards enumerate late); returns the index of the first new one, or -1 when none */
void ws_evdev_forget(ws_evdev *, int i);                   /* closes the device and frees its slot (it may come back with rescan) */
void ws_evdev_close(ws_evdev *);
/* console switching (FreeBSD vt(4)), src/vt_switch.c */
int wsd_vt_setup(const char *console);       /* takes over the VT behind the console device (e.g. /dev/ttyv0), else the controlling terminal */
void wsd_vt_release_ack(void);
void wsd_vt_acquire_ack(void);
void wsd_vt_restore(void);
#endif
#endif
