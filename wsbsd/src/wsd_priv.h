/* Internals of wsd shared with the protocol families (src/sls_*.c). */
#ifndef WSD_PRIV_H
#define WSD_PRIV_H
#include "ws.h"
#include "ws_ipc.h"
#include "sls_wire.h"
#include <stdint.h>
#include <stddef.h>

typedef struct {
	int fd; uint32_t id; int efd; int pid; char app[64]; int handshaken;
	uint32_t notify_n, notify[256];                                           /* connection notification interests */
	int registered; uint32_t psn_hi, psn_lo, session_id; int app_type;          /* process record made by CreateApplication */
} conn;

extern ws_server *srv;
extern int wsd_dirty;                                   /* set when something visible may have changed */
conn *wsd_conn_by_id(uint32_t id);

/* replies: 0x24 simple, 0x28 with one value, MIG error, header for custom layouts */
void fill_reply_header(mach_msg_header_t *r, const mach_msg_header_t *req, uint32_t size, int complex);
int reply_simple(int fd, const mach_msg_header_t *req, int32_t retcode);
int reply_value(int fd, const mach_msg_header_t *req, int32_t value);
int reply_mig_error(int fd, const mach_msg_header_t *req, int32_t code);
int simple_ok(const mach_msg_header_t *h, size_t len, size_t want);   /* not complex, size and datagram length both equal want */
int holds_rights(const conn *c, uint32_t wid);

int wsd_bind_surface(conn *c, uint32_t wid, uint32_t sid, int kind, uint32_t a, uint32_t b);   /* BindSurface semantics, returns the retcode */
int wsd_remove_surface(conn *c, uint32_t wid, uint32_t sid);

/* Protocol families. Each returns -2 for an id it does not handle, otherwise the result of sending the reply (>= 0) or -1 to drop the connection. */
int sls_ext_dispatch(conn *c, const uint8_t *buf, size_t len);
void sls_ext_owner_cleanup(uint32_t owner);

#define MIG_SIZE_ERR  (-304)                            /* wrong request size: MIG_BAD_ARGUMENTS */
#define MIG_TYPE_ERR  (-300)

/* little-endian field access in a request/reply buffer */
static inline uint32_t rd32(const uint8_t *b, size_t off) { uint32_t v; __builtin_memcpy(&v, b + off, 4); return v; }
static inline void wr32(uint8_t *b, size_t off, uint32_t v) { __builtin_memcpy(b + off, &v, 4); }
#endif
