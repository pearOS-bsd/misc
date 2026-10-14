/* Event records: the "modern" tagged, big-endian byte stream used by PostEventRecord and CGEventCreateData.
 * Format: docs/SPEC-SLS-WIRE.md section 7 (observed by serialising real events; the field ids follow CGEventField). */
#ifndef WS_EVREC_H
#define WS_EVREC_H
#include <stddef.h>
#include <stdint.h>

#define WS_EV_FIELD_MAX 96

typedef struct {
	uint16_t id;        /* low 14 bits of the tag: CGEventField number */
	uint8_t kind;       /* 1 = integer, 2 = float */
	uint8_t words;      /* 1 = one 32-bit value, 2 = a pair of floats or one 64-bit integer */
	uint32_t v[2];      /* raw big-endian-decoded words (for a 64-bit value: v[0] is the high word) */
	int wide;           /* 1 if the tag marks a single 64-bit value */
} ws_evfield;

typedef struct {
	int n;
	ws_evfield f[WS_EV_FIELD_MAX];
} ws_evrec;

/* 0 on success; negative if the stream is malformed or has trailing bytes. */
int ws_evrec_parse(const uint8_t *b, size_t len, ws_evrec *out);
const ws_evfield *ws_evrec_find(const ws_evrec *r, unsigned id);

/* typed views */
int ws_evrec_type(const ws_evrec *r);                       /* CGEventType (field 0x37), -1 if absent */
int ws_evrec_location(const ws_evrec *r, float *x, float *y);
uint32_t ws_evrec_flags(const ws_evrec *r);                 /* field 0x3b */
uint64_t ws_evrec_timestamp(const ws_evrec *r);             /* field 0x3a */
int ws_evrec_keycode(const ws_evrec *r);                    /* field 9, -1 if absent */
int ws_evrec_click_state(const ws_evrec *r);                /* field 1 */

/* builders reproduce the bytes CGEventCreateData produces for the same event; return the length or 0 */
size_t ws_evrec_make_mouse(uint8_t *out, size_t cap, int type, float x, float y, uint32_t flags, int click_state, int button, uint64_t ts);
size_t ws_evrec_make_key(uint8_t *out, size_t cap, int down, int keycode, uint32_t flags, float x, float y, uint64_t ts, int ch, int f50);
#endif
