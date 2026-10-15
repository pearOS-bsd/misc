/* A small VNC (RFB 3.8) server for wsd: remote view and control of the composed screen, e.g. over an SSH tunnel. One client at a time, raw encoding of the changed 64x64 tiles, VNC
 * password authentication (a random or given password) or none when no password is set; the listener binds to 127.0.0.1 only. */
#include "wsd_priv.h"
#include "ws_input.h"
#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/time.h>
#ifdef __APPLE__
#include <CommonCrypto/CommonCryptor.h>
#else
#define OPENSSL_SUPPRESS_DEPRECATED
#include <openssl/des.h>
#endif

#define TILE 64
enum { ST_VERSION, ST_SECTYPE, ST_AUTH, ST_INIT, ST_RUN };

static struct {
	int ls, fd, state, want, incremental;
	uint8_t in[512]; size_t inn;
	uint8_t challenge[16];
	uint32_t shift[3]; int bigendian;                     /* the client's pixel format (r, g, b shifts) */
	uint8_t *last; int lw, lh;                            /* what the client has */
	int rx, ry, rw, rh;                                   /* the region of the last request */
	uint64_t last_gen; double last_send;
	char password[9];
} v;

static double now(void) { struct timeval t; gettimeofday(&t, NULL); return t.tv_sec + t.tv_usec / 1e6; }

/* VNC authentication: DES-ECB of the 16 byte challenge with the password (padded to 8 bytes, each key byte bit-reversed) */
int wsd_vnc_des_response(const char *password, const uint8_t challenge[16], uint8_t out[16])
{
	uint8_t key[8]; memset(key, 0, sizeof key);
	for (int i = 0; i < 8 && password[i]; i++) { uint8_t b = (uint8_t)password[i], r = 0; for (int k = 0; k < 8; k++) if (b & (1 << k)) r |= (uint8_t)(0x80 >> k); key[i] = r; }
#ifdef __APPLE__
	size_t moved = 0;
	return CCCrypt(kCCEncrypt, kCCAlgorithmDES, kCCOptionECBMode, key, 8, NULL, challenge, 16, out, 16, &moved) == kCCSuccess ? 0 : -1;
#else
	DES_key_schedule ks; DES_cblock k; memcpy(k, key, 8);
	DES_set_key_unchecked(&k, &ks);
	for (int i = 0; i < 16; i += 8) DES_ecb_encrypt((const_DES_cblock *)(challenge + i), (DES_cblock *)(out + i), &ks, DES_ENCRYPT);
	return 0;
#endif
}

static int send_all(int fd, const void *p, size_t n)
{
	const uint8_t *b = p;
	while (n) { ssize_t w = send(fd, b, n, 0); if (w < 0) { if (errno == EINTR) continue; if (errno == EAGAIN) { usleep(1000); continue; } return -1; } b += w; n -= (size_t)w; }
	return 0;
}

int wsd_vnc_listen(int port, const char *password)
{
	memset(&v, 0, sizeof v); v.ls = v.fd = -1;
	if (password && *password) snprintf(v.password, sizeof v.password, "%s", password);
	int s = socket(AF_INET, SOCK_STREAM, 0); if (s < 0) return -1;
	int one = 1; setsockopt(s, SOL_SOCKET, SO_REUSEADDR, &one, sizeof one);
	struct sockaddr_in a; memset(&a, 0, sizeof a); a.sin_family = AF_INET; a.sin_port = htons((uint16_t)port); a.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
	if (bind(s, (struct sockaddr *)&a, sizeof a) < 0 || listen(s, 1) < 0) { close(s); return -1; }
	fcntl(s, F_SETFL, fcntl(s, F_GETFL) | O_NONBLOCK);
	v.ls = s;
	return s;
}
int wsd_vnc_client_fd(void) { return v.fd; }
int wsd_vnc_connected(void) { return v.fd >= 0 && v.state == ST_RUN; }

static void drop(void) { if (v.fd >= 0) close(v.fd); v.fd = -1; free(v.last); v.last = NULL; v.state = ST_VERSION; v.inn = 0; v.want = 0; }

/* returns the new client's descriptor to watch, or -1 */
int wsd_vnc_accept(void)
{
	int c = accept(v.ls, NULL, NULL);
	if (c < 0) return -1;
	if (v.fd >= 0) { close(c); return -1; }                  /* one viewer at a time */
	int one = 1; setsockopt(c, IPPROTO_TCP, TCP_NODELAY, &one, sizeof one);
	fcntl(c, F_SETFL, fcntl(c, F_GETFL) | O_NONBLOCK);
	v.fd = c; v.state = ST_VERSION; v.inn = 0; v.want = 0; v.shift[0] = 16; v.shift[1] = 8; v.shift[2] = 0; v.bigendian = 0;
	if (send_all(c, "RFB 003.008\n", 12) < 0) { drop(); return -1; }
	return c;
}

/* X keysym -> evdev key code of the key that produces it on a US keyboard (shift state arrives as separate Shift key events) */
static int keysym_to_evdev(uint32_t k)
{
	static const char lower[] = "abcdefghijklmnopqrstuvwxyz";
	static const int az[26] = { 30, 48, 46, 32, 18, 33, 34, 35, 23, 36, 37, 38, 50, 49, 24, 25, 16, 19, 31, 20, 22, 47, 17, 45, 21, 44 };
	if (k >= 'A' && k <= 'Z') k += 32;
	if (k >= 'a' && k <= 'z') return az[strchr(lower, (int)k) - lower];
	if (k >= '1' && k <= '9') return 2 + (int)(k - '1');
	if (k == '0') return 11;
	switch (k) {
	case '!': return 2; case '@': return 3; case '#': return 4; case '$': return 5; case '%': return 6; case '^': return 7; case '&': return 8; case '*': return 9; case '(': return 10; case ')': return 11;
	case '-': case '_': return 12; case '=': case '+': return 13; case '[': case '{': return 26; case ']': case '}': return 27; case ';': case ':': return 39; case '\'': case '"': return 40;
	case '`': case '~': return 41; case '\\': case '|': return 43; case ',': case '<': return 51; case '.': case '>': return 52; case '/': case '?': return 53; case ' ': return 57;
	case 0xff0d: case 0xff8d: return 28; case 0xff08: return 14; case 0xff09: return 15; case 0xff1b: return 1; case 0xffff: return 111;
	case 0xff51: return 105; case 0xff52: return 103; case 0xff53: return 106; case 0xff54: return 108; case 0xff50: return 102; case 0xff57: return 107; case 0xff55: return 104; case 0xff56: return 109;
	case 0xffe1: return 42; case 0xffe2: return 54; case 0xffe3: return 29; case 0xffe4: return 97; case 0xffe9: case 0xffe7: return 56; case 0xffea: case 0xffe8: return 100;
	case 0xffeb: case 0xffec: return 125; case 0xffe5: return 58;
	}
	if (k >= 0xffbe && k <= 0xffc9) return k - 0xffbe + 59;                          /* F1 .. F10, F11, F12 */
	return -1;
}

/* the bytes of a pixel in the client's format */
static void put_pixel(uint8_t *o, const uint8_t *bgra, const uint32_t sh[3], int big)
{
	uint32_t p = ((uint32_t)bgra[2] << sh[0]) | ((uint32_t)bgra[1] << sh[1]) | ((uint32_t)bgra[0] << sh[2]);
	if (big) { o[0] = (uint8_t)(p >> 24); o[1] = (uint8_t)(p >> 16); o[2] = (uint8_t)(p >> 8); o[3] = (uint8_t)p; }
	else { o[0] = (uint8_t)p; o[1] = (uint8_t)(p >> 8); o[2] = (uint8_t)(p >> 16); o[3] = (uint8_t)(p >> 24); }
}

static int consume(size_t n) { memmove(v.in, v.in + n, v.inn - n); v.inn -= n; return 0; }

/* handles whatever the viewer sent; returns -1 when the connection should be closed */
int wsd_vnc_read(ws_server *srv, ws_input *in, int sw, int sh, const char *name)
{
	ssize_t r = recv(v.fd, v.in + v.inn, sizeof v.in - v.inn, 0);
	if (r == 0 || (r < 0 && errno != EAGAIN && errno != EINTR)) { drop(); return -1; }
	if (r > 0) v.inn += (size_t)r;
	for (;;) {
		if (v.state == ST_VERSION) {
			if (v.inn < 12) return 0;
			if (memcmp(v.in, "RFB 003.", 8)) { drop(); return -1; }
			consume(12);
			uint8_t t[2] = { 1, v.password[0] ? 2 : 1 };
			if (send_all(v.fd, t, 2) < 0) { drop(); return -1; }
			v.state = ST_SECTYPE;
		} else if (v.state == ST_SECTYPE) {
			if (v.inn < 1) return 0;
			uint8_t sec = v.in[0]; consume(1);
			if (sec == 2 && v.password[0]) {
				for (int i = 0; i < 16; i++) v.challenge[i] = (uint8_t)(rand() >> 7);
				FILE *f = fopen("/dev/urandom", "rb"); if (f) { if (fread(v.challenge, 1, 16, f) != 16) {} fclose(f); }
				if (send_all(v.fd, v.challenge, 16) < 0) { drop(); return -1; }
				v.state = ST_AUTH;
			} else if (sec == 1 && !v.password[0]) { uint32_t ok = 0; if (send_all(v.fd, &ok, 4) < 0) { drop(); return -1; } v.state = ST_INIT; }
			else { drop(); return -1; }
		} else if (v.state == ST_AUTH) {
			if (v.inn < 16) return 0;
			uint8_t want[16]; wsd_vnc_des_response(v.password, v.challenge, want);
			int ok = memcmp(want, v.in, 16) == 0; consume(16);
			if (!ok) { uint8_t bad[4 + 4 + 13] = { 0, 0, 0, 1, 0, 0, 0, 13 }; memcpy(bad + 8, "auth failed.", 13); send_all(v.fd, bad, sizeof bad); usleep(200000); drop(); return -1; }
			uint32_t zero = 0; if (send_all(v.fd, &zero, 4) < 0) { drop(); return -1; }
			v.state = ST_INIT;
		} else if (v.state == ST_INIT) {
			if (v.inn < 1) return 0;
			consume(1);
			size_t nl = strlen(name); uint8_t si[24 + 64]; memset(si, 0, sizeof si);
			si[0] = (uint8_t)(sw >> 8); si[1] = (uint8_t)sw; si[2] = (uint8_t)(sh >> 8); si[3] = (uint8_t)sh;
			si[4] = 32; si[5] = 24; si[6] = 0; si[7] = 1; si[8] = 0; si[9] = 255; si[10] = 0; si[11] = 255; si[12] = 0; si[13] = 255; si[14] = 16; si[15] = 8; si[16] = 0;
			if (nl > 60) nl = 60;
			si[20] = 0; si[21] = 0; si[22] = (uint8_t)(nl >> 8); si[23] = (uint8_t)nl; memcpy(si + 24, name, nl);
			if (send_all(v.fd, si, 24 + nl) < 0) { drop(); return -1; }
			v.state = ST_RUN; v.last = NULL;
		} else {
			if (v.inn < 1) return 0;
			uint8_t t = v.in[0];
			if (t == 0) { if (v.inn < 20) return 0; v.bigendian = v.in[6]; if (v.in[4] == 32 && v.in[7]) { v.shift[0] = v.in[14]; v.shift[1] = v.in[15]; v.shift[2] = v.in[16]; } consume(20); }
			else if (t == 2) { if (v.inn < 4) return 0; size_t n = (size_t)(v.in[2] << 8 | v.in[3]); if (v.inn < 4 + 4 * n) { if (4 + 4 * n > sizeof v.in) { drop(); return -1; } return 0; } consume(4 + 4 * n); }
			else if (t == 3) { if (v.inn < 10) return 0; v.want = 1; v.incremental = v.in[1]; v.rx = v.in[2] << 8 | v.in[3]; v.ry = v.in[4] << 8 | v.in[5]; v.rw = v.in[6] << 8 | v.in[7]; v.rh = v.in[8] << 8 | v.in[9]; if (!v.incremental) { free(v.last); v.last = NULL; } consume(10); }
			else if (t == 4) { if (v.inn < 8) return 0; uint32_t k = (uint32_t)v.in[4] << 24 | (uint32_t)v.in[5] << 16 | (uint32_t)v.in[6] << 8 | v.in[7]; int code = keysym_to_evdev(k); if (code > 0) ws_input_feed(in, srv, WSI_EV_KEY, code, v.in[1] ? 1 : 0); consume(8); }
			else if (t == 5) {
				if (v.inn < 6) return 0;
				int buttons = v.in[1], x = v.in[2] << 8 | v.in[3], y = v.in[4] << 8 | v.in[5];
				in->x = x; in->y = y;
				int b = (buttons & 1) | ((buttons & 4) ? 2 : 0) | ((buttons & 2) ? 4 : 0);        /* RFB: 1 left, 2 middle, 4 right -> left, right, middle */
				if (buttons & 8) ws_server_scroll(srv, x, y, 0, 1, 0); if (buttons & 16) ws_server_scroll(srv, x, y, 0, -1, 0);                     /* wheel up / down */
				in->buttons = b; ws_server_mouse(srv, x, y, b);
				consume(6);
			}
			else if (t == 6) { if (v.inn < 8) return 0; size_t n = (size_t)(v.in[4] << 24 | v.in[5] << 16 | v.in[6] << 8 | v.in[7]); if (v.inn < 8 + n) { if (8 + n > sizeof v.in) { size_t skip = v.inn; consume(skip); return 0; } return 0; } consume(8 + n); }
			else { drop(); return -1; }
		}
	}
}

int wsd_vnc_wants(uint64_t key) { return v.fd >= 0 && v.state == ST_RUN && v.want && (!v.last || !v.incremental || key != v.last_gen) && now() - v.last_send >= 0.03; }

/* sends the changed tiles of the composed screen if the viewer asked for an update. gen: the server's content generation. Returns 0 or -1 (connection closed). */
int wsd_vnc_update(const ws_surface *screen, uint64_t gen)
{
	if (v.fd < 0 || v.state != ST_RUN || !v.want) return 0;
	double t = now();
	int W = screen->w, H = screen->h;
	if (!v.last) { v.last = calloc((size_t)W * H, 4); v.lw = W; v.lh = H; if (!v.last) { drop(); return -1; } memset(v.last, 0x5a, (size_t)W * H * 4); }
	int x0 = v.rx, y0 = v.ry, x1 = v.rx + v.rw, y1 = v.ry + v.rh; if (x1 > W) x1 = W; if (y1 > H) y1 = H;
	uint8_t hdr[4] = { 0, 0, 0, 0 };
	/* count the changed tiles first */
	int nrect = 0;
	for (int ty = y0 / TILE; ty * TILE < y1; ty++) for (int tx = x0 / TILE; tx * TILE < x1; tx++) {
		int px = tx * TILE, py = ty * TILE, pw = TILE, ph = TILE; if (px + pw > W) pw = W - px; if (py + ph > H) ph = H - py;
		int diff = 0; for (int y = 0; y < ph && !diff; y++) if (memcmp(screen->px + (size_t)(py + y) * screen->stride + (size_t)px * 4, v.last + ((size_t)(py + y) * W + px) * 4, (size_t)pw * 4)) diff = 1;
		if (diff) nrect++;
	}
	if (!nrect) { v.last_gen = gen; return 0; }
	hdr[2] = (uint8_t)(nrect >> 8); hdr[3] = (uint8_t)nrect;
	if (send_all(v.fd, hdr, 4) < 0) { drop(); return -1; }
	uint8_t buf[12 + TILE * TILE * 4];
	for (int ty = y0 / TILE; ty * TILE < y1; ty++) for (int tx = x0 / TILE; tx * TILE < x1; tx++) {
		int px = tx * TILE, py = ty * TILE, pw = TILE, ph = TILE; if (px + pw > W) pw = W - px; if (py + ph > H) ph = H - py;
		int diff = 0; for (int y = 0; y < ph && !diff; y++) if (memcmp(screen->px + (size_t)(py + y) * screen->stride + (size_t)px * 4, v.last + ((size_t)(py + y) * W + px) * 4, (size_t)pw * 4)) diff = 1;
		if (!diff) continue;
		buf[0] = (uint8_t)(px >> 8); buf[1] = (uint8_t)px; buf[2] = (uint8_t)(py >> 8); buf[3] = (uint8_t)py; buf[4] = (uint8_t)(pw >> 8); buf[5] = (uint8_t)pw; buf[6] = (uint8_t)(ph >> 8); buf[7] = (uint8_t)ph;
		buf[8] = buf[9] = buf[10] = buf[11] = 0;                                  /* raw encoding */
		uint8_t *o = buf + 12;
		for (int y = 0; y < ph; y++) {
			const uint8_t *row = screen->px + (size_t)(py + y) * screen->stride + (size_t)px * 4;
			for (int x = 0; x < pw; x++, o += 4) put_pixel(o, row + 4 * x, v.shift, v.bigendian);
			memcpy(v.last + ((size_t)(py + y) * W + px) * 4, row, (size_t)pw * 4);
		}
		if (send_all(v.fd, buf, (size_t)(o - buf)) < 0) { drop(); return -1; }
	}
	v.want = 0; v.last_gen = gen; v.last_send = t;
	return 0;
}
