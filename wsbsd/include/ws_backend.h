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
int ws_kms_present(ws_kms *);                               /* queue a page flip of the back buffer */
int ws_kms_handle_events(ws_kms *);                         /* call when ws_kms_fd is readable */
void ws_kms_close(ws_kms *);

typedef struct ws_evdev ws_evdev;
ws_evdev *ws_evdev_open(const char *dir);                   /* opens every /dev/input/event* it can read */
int ws_evdev_count(ws_evdev *);
int ws_evdev_fd(ws_evdev *, int i);
/* Reads pending events from fd i and feeds the server; returns -1 if the device went away. */
int ws_evdev_dispatch(ws_evdev *, int i, ws_server *, int screen_w, int screen_h);
void ws_evdev_close(ws_evdev *);
#endif
#endif
