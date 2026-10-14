/* Robustness: clients that die, garbage and truncated messages, and exhausted limits must never take wsd down or leak its state. */
#include "ws_client.h"
#include "ws_ipc.h"
#include "sls_wire.h"
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

static uint32_t rng = 0x12345678u;
static uint32_t rnd(void) { rng ^= rng << 13; rng ^= rng >> 17; rng ^= rng << 5; return rng; }

static const int ranges[][2] = { { 29000, 29042 }, { 30000, 30647 }, { 32000, 32074 }, { 33000, 33029 }, { 34000, 34010 }, { 39001, 39100 } };

static void drain(int fd)
{
	uint8_t buf[0x1000]; int fds[WS_IPC_MAX_FDS], n;
	for (int i = 0; i < 8; i++) { ssize_t r = ws_ipc_recv(fd, buf, sizeof buf, fds, &n); if (r <= 0) break; for (int k = 0; k < n; k++) close(fds[k]); }
}

/* one random message: random or plausible header, random body, sometimes descriptors */
static void fuzz_one(int fd)
{
	uint8_t m[600]; size_t len = rnd() % 4 == 0 ? rnd() % 16 : rnd() % 400;
	for (size_t i = 0; i < len; i++) m[i] = (uint8_t)rnd();
	if (len >= sizeof(mach_msg_header_t)) {
		mach_msg_header_t *h = (mach_msg_header_t *)m;
		const int *r = ranges[rnd() % 6];
		h->msgh_id = rnd() % 8 ? r[0] + (int)(rnd() % (uint32_t)(r[1] - r[0])) : (int)rnd();
		if (h->msgh_id == WSX_SCREENSHOT || h->msgh_id == WSX_QUIT) h->msgh_id = 29000;
		h->msgh_size = rnd() % 3 ? (uint32_t)len : rnd() % 1000;
		h->msgh_bits = rnd() % 2 ? 0x80000013u : 0x13u;
	}
	int fds[2], nf = 0;
	if (rnd() % 5 == 0) { fds[0] = open("/dev/null", O_RDONLY); nf = 1; }
	struct iovec v = { m, len };
	ws_ipc_send(fd, &v, 1, nf ? fds : NULL, nf);
	if (nf) close(fds[0]);
	drain(fd);
}

/* connects, retrying while the server is still busy reaping earlier connections */
static ws_conn *connect_retry(void)
{
	for (int i = 0; i < 100; i++) { ws_conn *c = ws_connect(NULL); if (c) return c; usleep(20000); }
	return NULL;
}
static int raw_connect_retry(void)
{
	for (int i = 0; i < 100; i++) { int fd = ws_ipc_connect(getenv("WS_SOCKET")); if (fd >= 0) return fd; usleep(20000); }
	return -1;
}

static int healthy(void)
{
	ws_conn *c = connect_retry();
	if (!c) return 0;
	ws_win w; int ok = ws_win_create(c, (ws_rect){ 10, 10, 50, 40 }, 0, &w) == 0 && ws_win_count(c, ws_conn_id(c)) == 1;
	ws_disconnect(c);
	return ok;
}

int main(void)
{
	signal(SIGPIPE, SIG_IGN);                                                    /* the server closes abusive connections */
	/* 1. a client dies without saying goodbye: its windows, buffers and surfaces go with it */
	ws_conn *a = ws_connect(NULL), *b = ws_connect(NULL);
	if (!a || !b) { fprintf(stderr, "test_robust: cannot connect\n"); return 1; }
	int acid = ws_conn_id(a);
	for (int i = 0; i < 5; i++) {
		ws_win w; ws_cbuf cb; uint32_t sid;
		CHECK(ws_win_create(a, (ws_rect){ 10 * i, 10, 64, 64 }, 0, &w) == 0 && ws_cbuf_create(a, 64, 64, &cb) == 0 &&
		      ws_surface_add(a, &w, &sid) == 0 && ws_surface_bind_buffer(a, &w, sid, &cb) == 0);
	}
	CHECK(ws_win_count(b, acid) == 5);
	close(ws_conn_fd(a));                                                      /* no Terminate, no release */
	int gone = 0;
	for (int i = 0; i < 40 && !gone; i++) { gone = ws_win_count(b, acid) == 0; if (!gone) usleep(50000); }
	CHECK(gone);

	/* 2. limits: asking for far more buffers than the server holds fails cleanly, and the slots come back when the client leaves */
	ws_conn *hog = ws_connect(NULL);
	int made = 0, refused = 0;
	for (int i = 0; i < 700; i++) { ws_cbuf cb; if (ws_cbuf_create(hog, 16, 16, &cb) == 0) made++; else refused++; }
	CHECK(made > 0 && refused > 0 && healthy());
	close(ws_conn_fd(hog));
	int again = 0;
	for (int i = 0; i < 40 && !again; i++) { ws_cbuf cb; ws_conn *n = ws_connect(NULL); again = n && ws_cbuf_create(n, 16, 16, &cb) == 0; if (n) ws_disconnect(n); if (!again) usleep(50000); }
	CHECK(again);

	/* 3. garbage before the handshake, on fresh connections */
	for (int i = 0; i < 1500; i++) {
		int fd = raw_connect_retry();
		if (fd < 0) { CHECK(0); break; }
		fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK);
		for (int k = 0; k < 1 + (int)(rnd() % 4); k++) fuzz_one(fd);
		close(fd);
	}
	CHECK(healthy());

	/* 4. garbage on an established connection that owns objects */
	for (int round = 0; round < 40; round++) {
		ws_conn *c = connect_retry();
		ws_win w; ws_cbuf cb; uint32_t sid;
		if (!c || ws_win_create(c, (ws_rect){ 0, 0, 32, 32 }, 0, &w) || ws_cbuf_create(c, 32, 32, &cb) || ws_surface_add(c, &w, &sid)) { CHECK(0); break; }
		ws_surface_bind_buffer(c, &w, sid, &cb);
		int fd = ws_conn_fd(c);
		fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK);
		for (int k = 0; k < 60; k++) fuzz_one(fd);
		close(fd);
	}
	CHECK(healthy());
	/* nothing leaked from all of that: only this test's own connection `b` is left, with no windows */
	CHECK(ws_win_count(b, ws_conn_id(b)) == 0);
	ws_disconnect(b);
	printf(failures ? "%d failures\n" : "robustness: all checks passed\n", failures);
	return failures != 0;
}
