/* GetDisplaySystemState (34003): the binary state of the main display. Layout recovered from the blob the real server returns (macOS runner):
 *   header 64 words: [4] index of the current mode, [23] marker 0x12345678 followed by the display UUID (16 bytes), doubles (width, height) at words 32/34, 40/42, 48/50
 *   (frame, bounds, ...), [63] the number of mode records
 *   mode record 33 words: [0]=4, [1]=index, [2]=mode id, [3]/[4] flags (1/3, the native mode 0x2000007), [5]=refresh 60.0f, [6..9]=width, height, pixel width, pixel height,
 *   [10]=row bytes, [11]=width*3/80, [12]=mode number, [13]=scale 1.0f, then the 32-character pixel encoding and IOKit mode flags
 *   tail 16 words
 * The fields that are not named are copied from the recorded state. Request: 0x28 with the display id@0x20 (the main display is 13 on the real system). */
#include "wsd_priv.h"
#include <stdlib.h>
#include <string.h>

extern const uint32_t disp_head[64], disp_rec[33], disp_tail[16];
extern int wsd_screen_w, wsd_screen_h;
static const uint8_t DISPLAY_UUID[16] = { 0x5E, 0x1D, 0x1A, 0x5B, 0x0C, 0x3E, 0x4D, 0x5B, 0x9D, 0x2A, 0x6F, 0x57, 0xA5, 0xB0, 0xC0, 0xDE };

size_t sls_display_state(uint8_t *out, size_t cap, int W, int H)
{
	static const int std[][2] = { { 640, 480 }, { 800, 600 }, { 1024, 768 }, { 1280, 720 }, { 1280, 800 }, { 1366, 768 }, { 1440, 900 }, { 1600, 900 }, { 1920, 1080 } };
	int mw[16], mh[16], n = 0, cur = 0;
	for (size_t i = 0; i < sizeof std / sizeof std[0] && n < 15; i++) if (std[i][0] < W && std[i][1] < H) { mw[n] = std[i][0]; mh[n] = std[i][1]; n++; }
	mw[n] = W; mh[n] = H; cur = n; n++;                                           /* the native mode last: it is the largest */
	size_t need = 64 * 4 + (size_t)n * 33 * 4 + 16 * 4 + 3;
	if (cap < need) return 0;
	uint32_t *w = (uint32_t *)out;
	memcpy(w, disp_head, sizeof disp_head);
	w[4] = (uint32_t)cur; w[63] = (uint32_t)n;
	memcpy(&w[24], DISPLAY_UUID, 16);
	const int dpos[3] = { 32, 40, 48 };
	for (int i = 0; i < 3; i++) { double dw = W, dh = H; memcpy(&w[dpos[i]], &dw, 8); memcpy(&w[dpos[i] + 2], &dh, 8); }
	for (int i = 0; i < n; i++) {
		uint32_t *r = &w[64 + i * 33];
		memcpy(r, disp_rec, sizeof disp_rec);
		int native = i == cur;
		r[1] = r[2] = (uint32_t)i; r[3] = native ? 0x2000007u : 1; r[4] = native ? 0x2000007u : 3;
		r[6] = r[8] = (uint32_t)mw[i]; r[7] = r[9] = (uint32_t)mh[i]; r[10] = (uint32_t)mw[i] * 4; r[11] = (uint32_t)mw[i] * 3 / 80; r[12] = 0x20 + (uint32_t)i;
	}
	memcpy(&w[64 + n * 33], disp_tail, sizeof disp_tail);
	memset(out + need - 3, 0, 3);
	return need;
}

int sls_display_dispatch(conn *c, const uint8_t *buf, size_t len)
{
	const mach_msg_header_t *h = (const mach_msg_header_t *)buf;
	if (h->msgh_id != SLS_MSG_GetDisplaySystemState) return -2;
	if (!simple_ok(h, len, 0x28)) return reply_simple(c->fd, h, -304);
	uint8_t blob[64 * 4 + 16 * 33 * 4 + 16 * 4 + 8];
	size_t n = sls_display_state(blob, sizeof blob, wsd_screen_w, wsd_screen_h);
	uint8_t m[0x38]; memset(m, 0, sizeof m);
	fill_reply_header((mach_msg_header_t *)m, h, sizeof m, 1);
	wr32(m, 0x18, 1); m[0x24] = 1; m[0x25] = 1; m[0x27] = 1; wr32(m, 0x28, (uint32_t)n); memcpy(m + 0x2c, &WS_NDR, 8); wr32(m, 0x34, (uint32_t)n);
	struct iovec v[2] = { { m, sizeof m }, { blob, n } };
	return ws_ipc_send(c->fd, v, 2, NULL, 0);
}
