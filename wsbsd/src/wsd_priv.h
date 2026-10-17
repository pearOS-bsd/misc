/* Internals of wsd shared with the protocol families (src/sls_*.c). */
#ifndef WSD_PRIV_H
#define WSD_PRIV_H
#include "ws.h"
#include "ws_ipc.h"
#include "sls_wire.h"
#include <stdint.h>
#include <stddef.h>

/* replies leave through wsd_send, which zeroes the NDR record of the success replies the real server leaves zeroed (see sls_zero_ndr.h) */
int wsd_send(int sock, const struct iovec *iov, int iovcnt, const int *fds, int nfds);
#define ws_ipc_send wsd_send

typedef struct {
	int fd; uint32_t id; int efd; int pid; char app[64]; int handshaken;
	uint32_t notify_n, notify[256];                                           /* connection notification interests */
	int registered; uint32_t psn_hi, psn_lo, session_id; int app_type;          /* process record made by CreateApplication */
	uint32_t key_override;                                                       /* OverrideKeyRegistration bits (one per special key 0..6) */
	uint64_t gesture_mask; uint32_t coalesce_mask, notes;                        /* SetGestureEventSubmask, CoalesceEventsInMask, SetNotifications */
} conn;

extern ws_server *srv;
extern int wsd_dirty;                                   /* set when something visible may have changed */
conn *wsd_conn_by_id(uint32_t id);
int wsd_conns_for_pid(int pid, uint32_t *ids, int max);                           /* the live connections of a process */
conn *wsd_conn_by_psn(uint32_t hi, uint32_t lo);                                    /* the connection that registered this process (CreateApplication), NULL if none */

/* replies: 0x24 simple, 0x28 with one value, MIG error, header for custom layouts */
void fill_reply_header(mach_msg_header_t *r, const mach_msg_header_t *req, uint32_t size, int complex);
int reply_simple(int fd, const mach_msg_header_t *req, int32_t retcode);
int reply_value(int fd, const mach_msg_header_t *req, int32_t value);
int reply_mig_error(int fd, const mach_msg_header_t *req, int32_t code);
int simple_ok(const mach_msg_header_t *h, size_t len, size_t want);   /* not complex, size and datagram length both equal want */
/* VNC (src/vnc.c) */
struct ws_input_s;
int wsd_vnc_listen(int port, const char *password);                          /* the listening descriptor (127.0.0.1), -1 on failure */
int wsd_vnc_accept(void);                                                    /* the viewer's descriptor to watch, -1 if refused */
int wsd_vnc_client_fd(void);
int wsd_vnc_connected(void);
int wsd_vnc_flush(void);                                                    /* push queued update bytes; 1 = more waits for the socket, -1 = error */
int wsd_vnc_backlog(void);
int wsd_vnc_wants(uint64_t key);                                             /* 1 when the viewer waits for an update and something changed */
int wsd_vnc_update(const ws_surface *screen, uint64_t key);
int wsd_vnc_des_response(const char *password, const uint8_t challenge[16], uint8_t out[16]);
int wsd_sandbox_enter(int listen_fd, int kq);                                 /* Capsicum capability mode (FreeBSD); -1 elsewhere */
int holds_rights(const conn *c, uint32_t wid);
uint32_t wsd_rights_held(const conn *c, uint32_t wid);                       /* the rights mask the connection holds on the window (owner: 0x30007) */
int wsd_grant_create(conn *c, uint32_t recip, uint32_t wid, uint32_t a, uint32_t b);
int wsd_grant_complete(conn *c, uint32_t wid, uint32_t id);
uint32_t wsd_grant_id(uint32_t wid);
int wsd_rights_relinquish(conn *c, uint32_t wid, uint32_t mask);
int wsd_window_surfaces(uint32_t wid, uint32_t *out, int max);          /* surface ids of a window; returns the count */

int wsd_bind_surface(conn *c, uint32_t wid, uint32_t sid, int kind, uint32_t a, uint32_t b);   /* BindSurface semantics, returns the retcode */
int sls_symbolic_hotkey(uint32_t id, uint16_t *key, uint16_t *mods, uint32_t *flags, int *enabled);   /* the session's symbolic hot key table: 0 valid, 1 unset, -1 bad id */
uint64_t sls_space_of_window(uint32_t wid);                       /* the space a window is in (1: the default space) */
int ool_request(const mach_msg_header_t *h, const uint8_t *buf, size_t len, uint32_t want_size, int *err);   /* a complex request with one OOL descriptor: its size, or -1 with *err */
int wsd_remove_surface(conn *c, uint32_t wid, uint32_t sid);
int wsd_remove_all_surfaces(conn *c, uint32_t wid);                             /* RemoveAllSurfaces: the retcode */

/* Protocol families. Each returns -2 for an id it does not handle, otherwise the result of sending the reply (>= 0) or -1 to drop the connection. */
int sls_ext_dispatch(conn *c, const uint8_t *buf, size_t len);
void sls_ext_owner_cleanup(uint32_t owner);

#define MIG_SIZE_ERR  (-304)                            /* wrong request size: MIG_BAD_ARGUMENTS */
#define MIG_TYPE_ERR  (-300)

/* little-endian field access in a request/reply buffer */
static inline uint32_t rd32(const uint8_t *b, size_t off) { uint32_t v; __builtin_memcpy(&v, b + off, 4); return v; }
static inline void wr32(uint8_t *b, size_t off, uint32_t v) { __builtin_memcpy(b + off, &v, 4); }
#endif

#define WSD_NOTE_TAP_DATA 0x54415044u          /* notification type that carries event tap data to the tapping connection ("TAPD") */
void sls_tap_deliver(int cgtype, const uint8_t *rec, size_t n);
int sls_tap_filter_key(int key, int down);                                  /* 1 when an active tap holds the key event */
void sls_tap_post_result(uint32_t tap_id, uint32_t seq, const uint8_t *data, size_t n);
int sls_tap_poll(void);                                                      /* ms until a held event times out, -1 when none */
