/* Protocol conformance against a running wsd: raw SkyLight-layout messages, error codes and rights as recovered
 * from the decompiled server routines (docs/SPEC-SLS-WIRE.md). Run through test/run_wire.sh. */
#include "ws_ipc.h"
#include "ws_region.h"
#include "ws_evrec.h"
#include "ws_buffer.h"
#include "sls_wire.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/select.h>

static int fails;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); fails++; } } while (0)

static void hdr(mach_msg_header_t *h, uint32_t size, int id, int complex)
{
	h->msgh_bits = (complex ? MACH_MSGH_BITS_COMPLEX : 0) | MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, MACH_MSG_TYPE_MAKE_SEND_ONCE);
	h->msgh_size = size; h->msgh_remote_port = 1; h->msgh_local_port = 1; h->msgh_voucher_port = 0; h->msgh_id = id;
}

static int xchg(int s, const void *req, size_t len, void *rep, size_t cap, int *fds, int *nfds)
{
	struct iovec v = { (void *)req, len };
	int d[WS_IPC_MAX_FDS], dn = 0;
	if (ws_ipc_send(s, &v, 1, NULL, 0)) return -1;
	return (int)ws_ipc_recv(s, rep, cap, fds ? fds : d, nfds ? nfds : &dn);
}

/* returns the simple-reply return code, and checks the reply id; -9999 on a transport failure */
static int rc_of(int s, const void *req, size_t len, int expect_id)
{
	sls_simple_reply r;
	if (xchg(s, req, len, &r, sizeof r, NULL, NULL) != (int)sizeof r) return -9999;
	CHECK(r.h.msgh_id == expect_id);
	CHECK(r.h.msgh_size == 0x24 && !(r.h.msgh_bits & MACH_MSGH_BITS_COMPLEX));
	CHECK(memcmp(&r.ndr, &WS_NDR, 8) == 0);
	return r.retcode;
}

static uint32_t create(int s, ws_rect f, int type, int *fd_out, int *rc)
{
	uint8_t region[64];
	size_t rl = ws_region_serialize(&f, 1, region, sizeof region);
	sls_create_window_req q; memset(&q, 0, sizeof q);
	{ mach_msg_header_t h; hdr(&h, sizeof q, SLS_MSG_CreateWindow, 1); memcpy(&q.h, &h, sizeof h); }
	q.body.msgh_descriptor_count = 1;
	q.region = (mach_msg_ool_descriptor_t){ .deallocate = 1, .copy = 1, .type = MACH_MSG_OOL_DESCRIPTOR, .size = (uint32_t)rl };
	q.ndr = WS_NDR; q.window_type = type; q.region_size = (uint32_t)rl;
	struct iovec v[2] = { { &q, sizeof q }, { region, rl } };
	if (ws_ipc_send(s, v, 2, NULL, 0)) { *rc = -9999; return 0; }
	uint8_t buf[128]; int fds[WS_IPC_MAX_FDS], nfds = 0;
	ssize_t n = ws_ipc_recv(s, buf, sizeof buf, fds, &nfds);
	mach_msg_header_t *h = (mach_msg_header_t *)buf;
	CHECK(h->msgh_id == SLS_MSG_CreateWindow + 100);
	if (n == (ssize_t)sizeof(sls_create_window_rep) && (h->msgh_bits & MACH_MSGH_BITS_COMPLEX)) {
		sls_create_window_rep r; memcpy(&r, buf, sizeof r);
		CHECK(r.h.msgh_size == 0x44 && r.body.msgh_descriptor_count == 1 && r.shmem.disposition == MACH_MSG_TYPE_MOVE_SEND && r.shmem.type == MACH_MSG_PORT_DESCRIPTOR);
		CHECK(nfds == 1 && r.shmem.name == 1);
		*fd_out = nfds ? fds[0] : -1; *rc = 0;
		return r.window_id;
	}
	sls_simple_reply e; memcpy(&e, buf, n < (ssize_t)sizeof e ? (size_t)n : sizeof e);
	for (int i = 0; i < nfds; i++) close(fds[i]);
	*rc = n == (ssize_t)sizeof e ? e.retcode : -9999;
	return 0;
}

int main(void)
{
	const char *path = getenv("WS_SOCKET");
	int a = ws_ipc_connect(path), b = ws_ipc_connect(path);
	if (a < 0 || b < 0) { printf("cannot connect to wsd\n"); return 1; }

	/* NewConnectionPort (32000): handshake layout, errors, event channel, PID/version */
	int cfd = ws_ipc_connect(path);
	CHECK(cfd >= 0);
	{
		const char *app = "conformance-test";
		uint32_t n = (uint32_t)strlen(app) + 1, pad = (n + 3) & ~3u, size = pad + 0x54;
		uint8_t req[0x454]; memset(req, 0, sizeof req);
		sls_new_connection_head hd; memset(&hd, 0, sizeof hd);
		{ mach_msg_header_t h; hdr(&h, size, SLS_MSG_NewConnectionPort, 1); memcpy(&hd.h, &h, sizeof h); }
		hd.body.msgh_descriptor_count = 2;
		hd.port_a = (mach_msg_port_descriptor_t){ .disposition = MACH_MSG_TYPE_MOVE_SEND, .type = MACH_MSG_PORT_DESCRIPTOR };
		hd.port_b = hd.port_a; hd.ndr = WS_NDR; hd.name_len = n;
		memcpy(req, &hd, sizeof hd); memcpy(req + sizeof hd, app, n);

		/* wrong port disposition: MIG_TYPE_ERROR */
		sls_new_connection_head bad = hd; bad.port_b.disposition = MACH_MSG_TYPE_COPY_SEND;
		uint8_t breq[0x454]; memcpy(breq, req, sizeof breq); memcpy(breq, &bad, sizeof bad);
		CHECK(rc_of(cfd, breq, size, SLS_MSG_NewConnectionPort + 100) == MIG_TYPE_ERROR);
		/* name_len that disagrees with the size: MIG_BAD_ARGUMENTS */
		bad = hd; bad.name_len = n + 8; memcpy(breq, req, sizeof breq); memcpy(breq, &bad, sizeof bad);
		CHECK(rc_of(cfd, breq, size, SLS_MSG_NewConnectionPort + 100) == MIG_BAD_ARGUMENTS);
		/* a simple (non-complex) message for a complex routine: MIG_BAD_ARGUMENTS */
		bad = hd; bad.h.msgh_bits &= ~MACH_MSGH_BITS_COMPLEX; memcpy(breq, req, sizeof breq); memcpy(breq, &bad, sizeof bad);
		CHECK(rc_of(cfd, breq, size, SLS_MSG_NewConnectionPort + 100) == MIG_BAD_ARGUMENTS);

		sls_new_connection_rep rep; int fds[WS_IPC_MAX_FDS], nfds = 0;
		CHECK(xchg(cfd, req, size, &rep, sizeof rep, fds, &nfds) == (int)sizeof rep);
		CHECK(rep.h.msgh_size == 0x40 && (rep.h.msgh_bits & MACH_MSGH_BITS_COMPLEX) && rep.h.msgh_id == SLS_MSG_NewConnectionPort + 100);
		CHECK(rep.body.msgh_descriptor_count == 2 && rep.port1.disposition == 20 && rep.port2.disposition == MACH_MSG_TYPE_MOVE_SEND);
		CHECK(rep.connection_id != 0 && nfds == 1 && rep.port2.name == 1);
		int efd = nfds ? fds[0] : -1;
		/* a second handshake on the same connection fails */
		CHECK(rc_of(cfd, req, size, SLS_MSG_NewConnectionPort + 100) == CGS_ERROR_FAILURE);

		/* ConnectionGetPIDAndVersion: our own pid; unknown connection: 1002 */
		sls_wid_req pq; memset(&pq, 0, sizeof pq); hdr(&pq.h, sizeof pq, SLS_MSG_ConnectionGetPIDAndVersion, 0); pq.ndr = WS_NDR; pq.wid = rep.connection_id;
		sls_pid_version_rep pr;
		CHECK(xchg(cfd, &pq, sizeof pq, &pr, sizeof pr, NULL, NULL) == (int)sizeof pr && pr.retcode == 0 && pr.h.msgh_size == 0x2c);
#if defined(__APPLE__) || defined(__FreeBSD__)
		CHECK((uint32_t)pr.value == (uint32_t)getpid());
#endif
		pq.wid = 99999; sls_simple_reply se;
		CHECK(xchg(cfd, &pq, sizeof pq, &se, sizeof se, NULL, NULL) == (int)sizeof se && se.retcode == 0x3ea);

		/* WarpCursorPosition: moves the cursor even when the interval is invalid (1007); GetCursorScale is 1.0 */
		sls_warp_req wq; memset(&wq, 0, sizeof wq); hdr(&wq.h, sizeof wq, SLS_MSG_WarpCursorPosition, 0); wq.ndr = WS_NDR; wq.x = 111; wq.y = 222;
		{ float f = 0.5f; memcpy(&wq.interval_bits, &f, 4); }
		CHECK(rc_of(cfd, &wq, sizeof wq, SLS_MSG_WarpCursorPosition + 100) == 0);
		wsx_req gq; memset(&gq, 0, sizeof gq); hdr(&gq.h, sizeof gq, WSX_GET_CURSOR, 0); gq.ndr = WS_NDR; wsx_rep gr;
		CHECK(xchg(cfd, &gq, sizeof gq, &gr, sizeof gr, NULL, NULL) == (int)sizeof gr && gr.a[0] == 111 && gr.a[1] == 222);
		wq.x = 5; wq.y = 6; { float f = 11.0f; memcpy(&wq.interval_bits, &f, 4); }
		CHECK(rc_of(cfd, &wq, sizeof wq, SLS_MSG_WarpCursorPosition + 100) == 0x3ef);
		CHECK(xchg(cfd, &gq, sizeof gq, &gr, sizeof gr, NULL, NULL) == (int)sizeof gr && gr.a[0] == 5 && gr.a[1] == 6);
		{ float f = -1.0f; memcpy(&wq.interval_bits, &f, 4); }
		CHECK(rc_of(cfd, &wq, sizeof wq, SLS_MSG_WarpCursorPosition + 100) == 0x3ef);
		sls_header_only_req cs; hdr(&cs, sizeof cs, SLS_MSG_GetCursorScale, 0);
		sls_value_reply csr;
		CHECK(xchg(cfd, &cs, sizeof cs, &csr, sizeof csr, NULL, NULL) == (int)sizeof csr && csr.retcode == 0 && csr.value == 0x3f800000 && csr.h.msgh_size == 0x28);

		/* key focus (theft ids from 0x65), typing/key focus process, cursor hide counts -- layouts from the decompiled __X routines */
		{
			uint32_t me = rep.connection_id;
			sls_wid_req kq; memset(&kq, 0, sizeof kq); sls_value_reply kr; sls_keyproc_reply pr2;
			sls_header_only_req ho; hdr(&ho, sizeof ho, SLS_MSG_GetKeyFocusProcess, 0);
			CHECK(xchg(cfd, &ho, sizeof ho, &pr2, sizeof pr2, NULL, NULL) == (int)sizeof(sls_simple_reply) && ((sls_simple_reply *)&pr2)->retcode == -600);   /* nobody has focus */
			hdr(&kq.h, sizeof kq, SLS_MSG_StealKeyFocusReturningID, 0); kq.ndr = WS_NDR; kq.wid = 0;
			CHECK(xchg(cfd, &kq, sizeof kq, &kr, sizeof kr, NULL, NULL) == (int)sizeof kr && kr.retcode == 0 && kr.h.msgh_size == 0x28 && kr.value == 0x65);
			CHECK(xchg(cfd, &ho, sizeof ho, &pr2, sizeof pr2, NULL, NULL) == (int)sizeof pr2 && pr2.retcode == 0 && pr2.h.msgh_size == 0x30 && pr2.psn_lo == me && pr2.is_default == 0);
			hdr(&ho, sizeof ho, SLS_MSG_GetTypingFocusProcess, 0);
			CHECK(xchg(cfd, &ho, sizeof ho, &kr, sizeof kr, NULL, NULL) == (int)sizeof kr && kr.retcode == 0 && kr.h.msgh_size == 0x28);
			hdr(&kq.h, sizeof kq, SLS_MSG_StealKeyFocusReturningID, 0);
			CHECK(xchg(cfd, &kq, sizeof kq, &kr, sizeof kr, NULL, NULL) == (int)sizeof kr && kr.value == 0x66);          /* the counter moves on */
			hdr(&kq.h, sizeof kq, SLS_MSG_ReleaseKeyFocusWithID, 0); kq.wid = 0x65;
			CHECK(rc_of(cfd, &kq, sizeof kq, SLS_MSG_ReleaseKeyFocusWithID + 100) == 0);
			kq.wid = 0x66;
			CHECK(rc_of(cfd, &kq, sizeof kq, SLS_MSG_ReleaseKeyFocusWithID + 100) == 0);
			hdr(&ho, sizeof ho, SLS_MSG_GetKeyFocusProcess, 0);
			CHECK(xchg(cfd, &ho, sizeof ho, &pr2, sizeof pr2, NULL, NULL) == (int)sizeof(sls_simple_reply) && ((sls_simple_reply *)&pr2)->retcode == -600);   /* released */
			sls_two_req mq; memset(&mq, 0, sizeof mq); hdr(&mq.h, sizeof mq, SLS_MSG_ModifyKeyFocus, 0); mq.ndr = WS_NDR; mq.a = 0; mq.b = 0;
			CHECK(rc_of(cfd, &mq, sizeof mq, SLS_MSG_ModifyKeyFocus + 100) == 0);                                          /* plain steal */
			CHECK(rc_of(cfd, &mq, sizeof mq, SLS_MSG_ModifyKeyFocus + 100) == 0);                                          /* already the holder */
			mq.b = 0x200; CHECK(rc_of(cfd, &mq, sizeof mq, SLS_MSG_ModifyKeyFocus + 100) == 1010);                          /* ... and says so when asked */
			mq.a = 1; mq.b = 0; CHECK(rc_of(cfd, &mq, sizeof mq, SLS_MSG_ModifyKeyFocus + 100) == 0);
			hdr(&kq.h, sizeof kq, SLS_MSG_StealKeyFocusReturningID, 0); kq.wid = 0; mq.a = 0;
			CHECK(rc_of(cfd, &kq, 0x20, 71) == MIG_BAD_ARGUMENTS);                                                 /* wrong size: a MIG error reply (id 71) */

			sls_wid_req cq; memset(&cq, 0, sizeof cq); cq.ndr = WS_NDR; cq.wid = me;
			hdr(&cq.h, sizeof cq, SLS_MSG_HideCursor, 0);
			CHECK(rc_of(cfd, &cq, sizeof cq, SLS_MSG_HideCursor + 100) == 0);
			cq.wid = 77777; CHECK(rc_of(cfd, &cq, sizeof cq, SLS_MSG_HideCursor + 100) == 1000);                           /* unknown connection */
			hdr(&cq.h, sizeof cq, SLS_MSG_ObscureCursor, 0);
			CHECK(rc_of(cfd, &cq, sizeof cq, SLS_MSG_ObscureCursor + 100) == 1001);
			cq.wid = me; CHECK(rc_of(cfd, &cq, sizeof cq, SLS_MSG_ObscureCursor + 100) == 0);
			hdr(&cq.h, sizeof cq, SLS_MSG_RevealCursor, 0); CHECK(rc_of(cfd, &cq, sizeof cq, SLS_MSG_RevealCursor + 100) == 0);
			sls_two_req sq; memset(&sq, 0, sizeof sq); hdr(&sq.h, sizeof sq, SLS_MSG_ShowCursor, 0); sq.ndr = WS_NDR; sq.a = (int32_t)me; sq.b = 1;
			CHECK(rc_of(cfd, &sq, sizeof sq, SLS_MSG_ShowCursor + 100) == 0);                                              /* force: back to zero */
			sq.a = 77777; CHECK(rc_of(cfd, &sq, sizeof sq, SLS_MSG_ShowCursor + 100) == 0);                                /* always 0 */
		}

		/* registered cursors: register with pixel data (OOL), query, read back, set it, see it on screen, remove */
		{
			const char *nm = "wsbsd.test.cursor"; uint32_t nl = (uint32_t)strlen(nm), P = (nl + 3) & ~3u;
			uint8_t pix[4 * 4 * 4]; for (int i = 0; i < 16; i++) { pix[i * 4] = 0; pix[i * 4 + 1] = 0; pix[i * 4 + 2] = 255; pix[i * 4 + 3] = 255; }   /* BGRA red */
			uint8_t m[0x68 + 32 + sizeof pix]; memset(m, 0, sizeof m);
			uint32_t size = P + 0x68;
			hdr((mach_msg_header_t *)m, size, SLS_MSG_RegisterCursorWithData, 1);
			uint32_t one = 1, osz = sizeof pix;
			memcpy(m + 0x18, &one, 4); m[0x25] = 1; m[0x27] = MACH_MSG_OOL_DESCRIPTOR; memcpy(m + 0x28, &osz, 4); memcpy(m + 0x2c, &WS_NDR, 8);
			memcpy(m + 0x38, &nl, 4); memcpy(m + 0x3c, nm, nl);
			uint32_t f[11] = { 0, 1, 4, 4, 4, 4, 1, 1, 16, 1, 0 };                       /* not global, set now, 4x4 px, 4x4 pt, hotspot (1,1), 16 px, 1 frame */
			memcpy(m + 0x3c + P, f, sizeof f);
			memcpy(m + size, pix, sizeof pix);
			sls_value_reply vr;
			CHECK(xchg(cfd, m, size + sizeof pix, &vr, sizeof vr, NULL, NULL) == (int)sizeof vr && vr.retcode == 0 && vr.h.msgh_size == 0x28 && vr.h.msgh_id == SLS_MSG_RegisterCursorWithData + 100);

			/* the name requests */
			uint8_t nq[0x28 + 32]; memset(nq, 0, sizeof nq);
			uint32_t nsz = P + 0x28;
			#define NAMEREQ(id) do { memset(nq, 0, sizeof nq); hdr((mach_msg_header_t *)nq, nsz, id, 0); memcpy(nq + 0x18, &WS_NDR, 8); memcpy(nq + 0x24, &nl, 4); memcpy(nq + 0x28, nm, nl); } while (0)
			NAMEREQ(SLS_MSG_IsCursorRegistered);
			CHECK(xchg(cfd, nq, nsz, &vr, sizeof vr, NULL, NULL) == (int)sizeof vr && vr.retcode == 0 && vr.h.msgh_size == 0x28 && vr.value == 1);
			NAMEREQ(SLS_MSG_GetRegisteredCursorDataSize);
			CHECK(xchg(cfd, nq, nsz, &vr, sizeof vr, NULL, NULL) == (int)sizeof vr && vr.retcode == 0 && vr.value == 64);
			NAMEREQ(SLS_MSG_GetRegisteredCursorData);
			uint8_t gb[0x58 + 64]; uint32_t g[0x58 / 4];
			CHECK(xchg(cfd, nq, nsz, gb, sizeof gb, NULL, NULL) == (int)sizeof gb);
			memcpy(g, gb, 0x58);
			CHECK(g[1] == 0x58 && (g[0] & 0x80000000u) && g[6] == 1 && g[10] == 64 && g[13] == 4 && g[14] == 4 && g[15] == 4 && g[16] == 4 && g[17] == 1 && g[18] == 1 && g[19] == 64 && g[20] == 1);
			CHECK(memcmp(gb + 0x58, pix, 64) == 0);
			NAMEREQ(SLS_MSG_SetRegisteredCursor);
			CHECK(rc_of(cfd, nq, nsz, SLS_MSG_SetRegisteredCursor + 100) == 0);
			{	/* warp the pointer and look at the screen: the red square sits at pointer - hotspot */
				sls_warp_req w2; memset(&w2, 0, sizeof w2); hdr(&w2.h, sizeof w2, SLS_MSG_WarpCursorPosition, 0); w2.ndr = WS_NDR; w2.x = 300; w2.y = 300;
				CHECK(rc_of(cfd, &w2, sizeof w2, SLS_MSG_WarpCursorPosition + 100) == 0);
				wsx_req sr; memset(&sr, 0, sizeof sr); hdr(&sr.h, sizeof sr, WSX_SCREENSHOT, 0); sr.ndr = WS_NDR; sr.a[0] = 0;
				snprintf(sr.s, sizeof sr.s, "%s/wsbsd-cursor-%d.ppm", getenv("TMPDIR") ? getenv("TMPDIR") : "/tmp", (int)getpid());
				wsx_rep srp;
				CHECK(xchg(cfd, &sr, sizeof sr, &srp, sizeof srp, NULL, NULL) == (int)sizeof srp && srp.retcode == 0);
				FILE *pf = fopen(sr.s, "rb"); int pw = 0, ph = 0, mx = 0;
				if (pf && fscanf(pf, "P6 %d %d %d", &pw, &ph, &mx) == 3 && fgetc(pf) >= 0) {
					uint8_t *rgb = malloc((size_t)pw * ph * 3);
					if (rgb && fread(rgb, 3, (size_t)pw * ph, pf) == (size_t)pw * ph) {
						const uint8_t *a = rgb + ((size_t)299 * pw + 299) * 3, *b = rgb + ((size_t)302 * pw + 302) * 3, *o = rgb + ((size_t)298 * pw + 298) * 3;
						CHECK(a[0] == 255 && a[1] == 0 && a[2] == 0 && b[0] == 255 && b[1] == 0);        /* inside the 4x4 square */
						CHECK(!(o[0] == 255 && o[1] == 0 && o[2] == 0));                                  /* just outside */
					} else CHECK(0);
					free(rgb);
				} else CHECK(0);
				if (pf) fclose(pf);
				unlink(sr.s);
			}
			/* errors: unknown name 1007, system names cannot be removed (1000), removal then makes it unknown */
			uint8_t uq[0x28 + 8]; memset(uq, 0, sizeof uq); hdr((mach_msg_header_t *)uq, 0x2c, SLS_MSG_SetRegisteredCursor, 0);
			memcpy(uq + 0x18, &WS_NDR, 8); { uint32_t l = 3; memcpy(uq + 0x24, &l, 4); memcpy(uq + 0x28, "xyz", 3); }
			((mach_msg_header_t *)uq)->msgh_size = 0x2c;
			CHECK(rc_of(cfd, uq, 0x2c, SLS_MSG_SetRegisteredCursor + 100) == 0x3ef);
			uint8_t rq[0x28 + 32 + 4]; memset(rq, 0, sizeof rq);
			uint32_t rsz = P + 0x2c;
			hdr((mach_msg_header_t *)rq, rsz, SLS_MSG_RemoveRegisteredCursor, 0); memcpy(rq + 0x18, &WS_NDR, 8); memcpy(rq + 0x24, &nl, 4); memcpy(rq + 0x28, nm, nl);
			CHECK(rc_of(cfd, rq, rsz, SLS_MSG_RemoveRegisteredCursor + 100) == 0);
			NAMEREQ(SLS_MSG_IsCursorRegistered);
			CHECK(xchg(cfd, nq, nsz, &vr, sizeof vr, NULL, NULL) == (int)sizeof vr && vr.value == 0);
			NAMEREQ(SLS_MSG_GetRegisteredCursorData);
			CHECK(rc_of(cfd, nq, nsz, SLS_MSG_GetRegisteredCursorData + 100) == 0x3ef);
			{ const char *sys = "com.apple.coregraphics.Arrow"; uint32_t sl = (uint32_t)strlen(sys), sp = (sl + 3) & ~3u, ss = sp + 0x2c;
			  uint8_t sq[0x28 + 64]; memset(sq, 0, sizeof sq); hdr((mach_msg_header_t *)sq, ss, SLS_MSG_RemoveRegisteredCursor, 0);
			  memcpy(sq + 0x18, &WS_NDR, 8); memcpy(sq + 0x24, &sl, 4); memcpy(sq + 0x28, sys, sl);
			  CHECK(rc_of(cfd, sq, ss, SLS_MSG_RemoveRegisteredCursor + 100) == 1000); }
			/* a bad registration: pixel count mismatch -> type error, zero size -> 1001 */
			f[8] = 15; memcpy(m + 0x3c + P, f, sizeof f);
			CHECK(rc_of(cfd, m, size + sizeof pix, SLS_MSG_RegisterCursorWithData + 100) == MIG_TYPE_ERROR);
			f[8] = 16; f[4] = 0; memcpy(m + 0x3c + P, f, sizeof f);
			CHECK(rc_of(cfd, m, size + sizeof pix, SLS_MSG_RegisterCursorWithData + 100) == 1001);
			#undef NAMEREQ
		}

		/* window event mask by the owner; events for the owner's window arrive asynchronously on its event channel */
		int wfd = -1, wrc = 0;
		uint32_t cw = create(cfd, (ws_rect){ 10, 10, 100, 80 }, 2, &wfd, &wrc);
		CHECK(cw && wrc == 0); if (wfd >= 0) close(wfd);
		sls_eventmask_req em; memset(&em, 0, sizeof em); hdr(&em.h, sizeof em, SLS_MSG_SetWindowEventMask, 0); em.ndr = WS_NDR; em.wid = cw; em.level = 0x7f;
		CHECK(rc_of(cfd, &em, sizeof em, SLS_MSG_SetWindowEventMask + 100) == 0);
		sls_order_req oo; memset(&oo, 0, sizeof oo); hdr(&oo.h, sizeof oo, SLS_MSG_OrderWindow, 0); oo.ndr = WS_NDR; oo.wid = cw; oo.op = 1;
		CHECK(rc_of(cfd, &oo, sizeof oo, SLS_MSG_OrderWindow + 100) == 0);
		wsx_req mq; memset(&mq, 0, sizeof mq); hdr(&mq.h, sizeof mq, WSX_INJECT_MOUSE, 0); mq.ndr = WS_NDR; mq.a[0] = 40; mq.a[1] = 30; mq.a[2] = 1;
		wsx_rep mr; CHECK(xchg(cfd, &mq, sizeof mq, &mr, sizeof mr, NULL, NULL) == (int)sizeof mr);
		int got_down = 0, got_move = 0, got_focus = 0;
		for (int k = 0; k < 6; k++) {
			wsx_event_msg em2; int f2[WS_IPC_MAX_FDS], n2 = 0;
			if (efd < 0) break;
			struct { int fd; } dummy; (void)dummy;
			fd_set rs; FD_ZERO(&rs); FD_SET(efd, &rs); struct timeval tv = { 0, 200000 };
			if (select(efd + 1, &rs, NULL, NULL, &tv) <= 0) break;
			if (ws_ipc_recv(efd, &em2, sizeof em2, f2, &n2) != (ssize_t)sizeof em2) break;
			CHECK(em2.h.msgh_id == WSX_EVENT_PUSH && em2.wid == cw);
			got_down += em2.type == WS_EV_MOUSE_DOWN; got_move += em2.type == WS_EV_MOUSE_MOVE; got_focus += em2.type == WS_EV_FOCUS_IN;
			if (em2.type == WS_EV_MOUSE_DOWN) CHECK(em2.x == 30 && em2.y == 20);                  /* window-local coordinates */
		}
		CHECK(got_down == 1 && got_move == 1 && got_focus == 1);
		/* PostEventRecord (30121): a mouse-down at (50,40) over the window becomes a pushed event, a key goes to the focused window */
		{
			uint8_t rec[512]; size_t rn;
			uint8_t pb[0x38 + 512]; memset(pb, 0, sizeof pb);
			sls_post_event_head ph; memset(&ph, 0, sizeof ph);
			uint32_t psize;
			/* the earlier injected press is still held: release it with a left-up record first */
			rn = ws_evrec_make_mouse(rec, sizeof rec, 2, 50, 40, 0x100, 1, 0, 0x1111222233334444ULL);
			psize = 0x38 + (((uint32_t)rn + 3) & ~3u);
			hdr(&ph.h, psize, SLS_MSG_PostEventRecord, 0); ph.ndr = WS_NDR; ph.record_len = (uint32_t)rn;
			memcpy(pb, &ph, sizeof ph); memcpy(pb + sizeof ph, rec, rn);
			CHECK(rc_of(cfd, pb, psize, SLS_MSG_PostEventRecord + 100) == 0);
			rn = ws_evrec_make_mouse(rec, sizeof rec, 1, 50, 40, 0x100, 1, 0, 0x1111222233334444ULL);
			memset(pb, 0, sizeof pb);
			psize = 0x38 + (((uint32_t)rn + 3) & ~3u);
			hdr(&ph.h, psize, SLS_MSG_PostEventRecord, 0); ph.ndr = WS_NDR; ph.record_len = (uint32_t)rn;
			memcpy(pb, &ph, sizeof ph); memcpy(pb + sizeof ph, rec, rn);
			CHECK(rc_of(cfd, pb, psize, SLS_MSG_PostEventRecord + 100) == 0);
			int down2 = 0, focus2 = 0;
			for (int k = 0; k < 10 && efd >= 0; k++) {
				wsx_event_msg ev; int f3[WS_IPC_MAX_FDS], n3 = 0;
				fd_set rs2; FD_ZERO(&rs2); FD_SET(efd, &rs2); struct timeval tv2 = { 0, 200000 };
				if (select(efd + 1, &rs2, NULL, NULL, &tv2) <= 0) break;
				if (ws_ipc_recv(efd, &ev, sizeof ev, f3, &n3) != (ssize_t)sizeof ev) break;
				if (ev.type == WS_EV_MOUSE_DOWN) { down2++; CHECK(ev.x == 40 && ev.y == 30 && (ev.buttons & 1)); }   /* window-local */
				if (ev.type == WS_EV_FOCUS_IN) focus2++;
			}
			CHECK(down2 == 1);
			(void)focus2;
			rn = ws_evrec_make_key(rec, sizeof rec, 1, 36, 0x100, 0, 0, 0, 0, 0x0a);
			psize = 0x38 + (((uint32_t)rn + 3) & ~3u);
			hdr(&ph.h, psize, SLS_MSG_PostEventRecord, 0); ph.record_len = (uint32_t)rn;
			memset(pb, 0, sizeof pb); memcpy(pb, &ph, sizeof ph); memcpy(pb + sizeof ph, rec, rn);
			CHECK(rc_of(cfd, pb, psize, SLS_MSG_PostEventRecord + 100) == 0);
			int key2 = 0;
			for (int k = 0; k < 3 && efd >= 0; k++) {
				wsx_event_msg ev; int f3[WS_IPC_MAX_FDS], n3 = 0;
				fd_set rs2; FD_ZERO(&rs2); FD_SET(efd, &rs2); struct timeval tv2 = { 0, 200000 };
				if (select(efd + 1, &rs2, NULL, NULL, &tv2) <= 0) break;
				if (ws_ipc_recv(efd, &ev, sizeof ev, f3, &n3) != (ssize_t)sizeof ev) break;
				if (ev.type == WS_EV_KEY_DOWN) { key2++; CHECK(ev.key == 36); }
			}
			CHECK(key2 == 1);
			/* validation: size/length mismatch -> -304; a garbage record -> 1000; an empty record -> 1001 */
			hdr(&ph.h, psize + 4, SLS_MSG_PostEventRecord, 0);
			memset(pb, 0, sizeof pb); memcpy(pb, &ph, sizeof ph); memcpy(pb + sizeof ph, rec, rn);
			CHECK(rc_of(cfd, pb, psize + 4, SLS_MSG_PostEventRecord + 100) == MIG_BAD_ARGUMENTS);
			uint8_t junk[8] = { 9, 9, 9, 9, 9, 9, 9, 9 };
			ph.record_len = 8; hdr(&ph.h, 0x38 + 8, SLS_MSG_PostEventRecord, 0);
			memset(pb, 0, sizeof pb); memcpy(pb, &ph, sizeof ph); memcpy(pb + sizeof ph, junk, 8);
			CHECK(rc_of(cfd, pb, 0x38 + 8, SLS_MSG_PostEventRecord + 100) == CGS_ERROR_FAILURE);
			ph.record_len = 0; hdr(&ph.h, 0x38, SLS_MSG_PostEventRecord, 0);
			memset(pb, 0, sizeof pb); memcpy(pb, &ph, sizeof ph);
			CHECK(rc_of(cfd, pb, 0x38, SLS_MSG_PostEventRecord + 100) == CGS_ERROR_ILLEGAL_ARGUMENT);
		}
		if (efd >= 0) close(efd);
	}
	close(cfd);

	/* CreateWindow: success path, shared surface, id */
	int fd = -1, rc = 0;
	uint32_t w1 = create(a, (ws_rect){ 100, 200, 300, 150 }, 2, &fd, &rc);
	CHECK(w1 != 0 && rc == 0 && fd >= 0);
	if (fd >= 0) {
		ws_surface *s = ws_surface_from_fd(fd, 300, 150);
		CHECK(s != NULL);
		if (s) { s->px[0] = 7; ws_surface_free(s); }           /* the mapping is writable and sized w*h*4 */
		close(fd);
	}
	/* window types: 0 and 1 rejected, 3 and 5 accepted (mask 0x2c); the live system rejected 0 and 1 and accepted 2 */
	int fd2 = -1;
	CHECK(create(a, (ws_rect){ 0, 0, 10, 10 }, 0, &fd2, &rc) == 0 && rc == CGS_ERROR_ILLEGAL_ARGUMENT);
	CHECK(create(a, (ws_rect){ 0, 0, 10, 10 }, 1, &fd2, &rc) == 0 && rc == CGS_ERROR_ILLEGAL_ARGUMENT);
	uint32_t w3 = create(a, (ws_rect){ 0, 0, 10, 10 }, 3, &fd2, &rc); CHECK(w3 && rc == 0); if (fd2 >= 0) close(fd2);
	uint32_t w5 = create(a, (ws_rect){ 0, 0, 10, 10 }, 5, &fd2, &rc); CHECK(w5 && rc == 0); if (fd2 >= 0) close(fd2);
	CHECK(w3 != w1 && w5 != w3);

	/* MoveWindow / OrderWindow / SetWindowLevel / SetWindowListAlpha / TerminateWindow by the owner */
	sls_move_req mv; memset(&mv, 0, sizeof mv); hdr(&mv.h, sizeof mv, SLS_MSG_MoveWindow, 0); mv.ndr = WS_NDR; mv.wid = w1; mv.x = 400; mv.y = 500;
	CHECK(rc_of(a, &mv, sizeof mv, SLS_MSG_MoveWindow + 100) == 0);
	sls_order_req od; memset(&od, 0, sizeof od); hdr(&od.h, sizeof od, SLS_MSG_OrderWindow, 0); od.ndr = WS_NDR; od.wid = w1; od.op = 1;
	CHECK(rc_of(a, &od, sizeof od, SLS_MSG_OrderWindow + 100) == 0);
	sls_level_req lv; memset(&lv, 0, sizeof lv); hdr(&lv.h, sizeof lv, SLS_MSG_SetWindowLevel, 0); lv.ndr = WS_NDR; lv.wid = w1; lv.level = 5;
	CHECK(rc_of(a, &lv, sizeof lv, SLS_MSG_SetWindowLevel + 100) == 0);
	sls_alpha_req al; memset(&al, 0, sizeof al); hdr(&al.h, sizeof al, SLS_MSG_SetWindowListAlpha, 0); al.ndr = WS_NDR; al.wid = w1; { float f = 0.5f; memcpy(&al.alpha_bits, &f, 4); }
	CHECK(rc_of(a, &al, sizeof al, SLS_MSG_SetWindowListAlpha + 100) == 0);

	/* real FindWindow (30014): the window moved, so it is found at the new origin and reports its owner */
	sls_find_req fq; memset(&fq, 0, sizeof fq); hdr(&fq.h, sizeof fq, SLS_MSG_FindWindow, 0); fq.ndr = WS_NDR; fq.x = 450; fq.y = 520;
	sls_find_reply fr; CHECK(xchg(a, &fq, sizeof fq, &fr, sizeof fr, NULL, NULL) == (int)sizeof fr && fr.wid == w1 && fr.retcode == 0 && fr.owner != 0);
	CHECK(fr.h.msgh_id == SLS_MSG_FindWindow + 100 && fr.h.msgh_size == 0x34);
	uint32_t owner_a = fr.owner;

	/* GetWindowLevel / GetWindowAlpha / GetWindowFrameBounds / GetWindowOwner / GetWindowCount (reply sizes from the decompiled routines) */
	{
		sls_wid_req g; memset(&g, 0, sizeof g); hdr(&g.h, sizeof g, SLS_MSG_GetWindowLevel, 0); g.ndr = WS_NDR; g.wid = w1;
		sls_value_reply vr;
		CHECK(xchg(a, &g, sizeof g, &vr, sizeof vr, NULL, NULL) == (int)sizeof vr && vr.retcode == 0 && vr.value == 5 && vr.h.msgh_size == 0x28);
		g.wid = 99999;
		sls_simple_reply er;
		CHECK(xchg(a, &g, sizeof g, &er, sizeof er, NULL, NULL) == (int)sizeof er && er.retcode == CGS_ERROR_FAILURE && er.h.msgh_size == 0x24);   /* unknown window: 1000, short reply */
		g.h.msgh_id = SLS_MSG_GetWindowAlpha; g.wid = w1;
		CHECK(xchg(a, &g, sizeof g, &vr, sizeof vr, NULL, NULL) == (int)sizeof vr && vr.retcode == 0);
		{ float f; memcpy(&f, &vr.value, 4); CHECK(f == 0.5f); }
		g.wid = 99999;                                                                      /* alpha of an unknown window: success with 0 */
		CHECK(xchg(a, &g, sizeof g, &vr, sizeof vr, NULL, NULL) == (int)sizeof vr && vr.retcode == 0 && vr.value == 0);
		g.h.msgh_id = SLS_MSG_GetWindowFrameBounds; g.wid = w1;
		sls_bounds_reply br;
		CHECK(xchg(a, &g, sizeof g, &br, sizeof br, NULL, NULL) == (int)sizeof br && br.retcode == 0 && br.x == 400 && br.y == 500 && br.w == 300 && br.ht == 150 && br.h.msgh_size == 0x44);
		g.h.msgh_id = SLS_MSG_GetWindowOwner;
		sls_owner_reply orp;
		CHECK(xchg(a, &g, sizeof g, &orp, sizeof orp, NULL, NULL) == (int)sizeof orp && orp.retcode == 0 && (uint32_t)orp.owner == owner_a && orp.rights == 5 && orp.h.msgh_size == 0x30);
		CHECK(xchg(b, &g, sizeof g, &orp, sizeof orp, NULL, NULL) == (int)sizeof orp && (uint32_t)orp.owner == owner_a && orp.rights == 0);     /* another connection sees no rights */
		g.h.msgh_id = SLS_MSG_GetWindowCount; g.wid = owner_a;                              /* the argument is a connection id: a owns w1, w3, w5 */
		CHECK(xchg(a, &g, sizeof g, &vr, sizeof vr, NULL, NULL) == (int)sizeof vr && vr.retcode == 0 && vr.value == 3);
		g.h.msgh_bits |= MACH_MSGH_BITS_COMPLEX;                                            /* complex bit on a simple routine */
		CHECK(xchg(a, &g, sizeof g, &er, sizeof er, NULL, NULL) == (int)sizeof er && er.retcode == MIG_BAD_ARGUMENTS);
	}

	/* GetWindowShapeBounds (window-relative), SubLevel, GetOnScreenWindowCount, MoveWindowList, OrderWindowList */
	{
		sls_wid_req g; memset(&g, 0, sizeof g); hdr(&g.h, sizeof g, SLS_MSG_GetWindowShapeBounds, 0); g.ndr = WS_NDR; g.wid = w1;
		sls_shape_bounds_reply sb;
		CHECK(xchg(a, &g, sizeof g, &sb, sizeof sb, NULL, NULL) == (int)sizeof sb && sb.retcode == 0 && sb.x == 0 && sb.y == 0 && sb.w == 300 && sb.ht == 150 && sb.h.msgh_size == 0x34);
		sls_sublevel_req sl; memset(&sl, 0, sizeof sl); hdr(&sl.h, sizeof sl, SLS_MSG_SetWindowSubLevel, 0); sl.ndr = WS_NDR; sl.wid = w1; sl.level = 70000;   /* cast to a short: 70000 -> 4464 */
		CHECK(rc_of(a, &sl, sizeof sl, SLS_MSG_SetWindowSubLevel + 100) == 0);
		g.h.msgh_id = SLS_MSG_GetWindowSubLevel;
		sls_value_reply vr;
		CHECK(xchg(a, &g, sizeof g, &vr, sizeof vr, NULL, NULL) == (int)sizeof vr && vr.retcode == 0 && vr.value == 4464);
		g.h.msgh_id = SLS_MSG_GetOnScreenWindowCount; g.wid = owner_a;                  /* only w1 was ordered in */
		CHECK(xchg(a, &g, sizeof g, &vr, sizeof vr, NULL, NULL) == (int)sizeof vr && vr.retcode == 0 && vr.value == 1);

		/* MoveWindowList: relative move of two windows, one of them not owned -> skipped; empty list -> 1000; bad size -> -304 */
		uint32_t ml[13]; memset(ml, 0, sizeof ml);
		{ mach_msg_header_t mh; hdr(&mh, 0x2c + 8, SLS_MSG_MoveWindowList, 0); memcpy(ml, &mh, sizeof mh); }
		memcpy(ml + 6, &WS_NDR, 8);
		ml[8] = (uint32_t)10; ml[9] = (uint32_t)-20; ml[10] = 2; ml[11] = w1; ml[12] = 99999;
		CHECK(rc_of(a, ml, 0x2c + 8, SLS_MSG_MoveWindowList + 100) == 0);
		sls_wid_req bq; memset(&bq, 0, sizeof bq); hdr(&bq.h, sizeof bq, SLS_MSG_GetWindowFrameBounds, 0); bq.ndr = WS_NDR; bq.wid = w1;
		sls_bounds_reply br2;
		CHECK(xchg(a, &bq, sizeof bq, &br2, sizeof br2, NULL, NULL) == (int)sizeof br2 && br2.x == 410 && br2.y == 480);
		ml[10] = 0; { mach_msg_header_t mh; hdr(&mh, 0x2c, SLS_MSG_MoveWindowList, 0); memcpy(ml, &mh, sizeof mh); }
		CHECK(rc_of(a, ml, 0x2c, SLS_MSG_MoveWindowList + 100) == CGS_ERROR_FAILURE);
		ml[10] = 3; { mach_msg_header_t mh; hdr(&mh, 0x2c + 8, SLS_MSG_MoveWindowList, 0); memcpy(ml, &mh, sizeof mh); }    /* count 3 does not match size */
		CHECK(rc_of(a, ml, 0x2c + 8, SLS_MSG_MoveWindowList + 100) == MIG_BAD_ARGUMENTS);

		/* OrderWindowList: w3 and w5 ordered above in one call; then the on-screen count is 3 */
		uint32_t ol[11 + 3 * 2]; memset(ol, 0, sizeof ol);
		{ mach_msg_header_t oh; hdr(&oh, 0x2c + 24, SLS_MSG_OrderWindowList, 0); memcpy(ol, &oh, sizeof oh); }
		memcpy(ol + 6, &WS_NDR, 8);
		ol[8] = 2; ol[9] = w3; ol[10] = w5; ol[11] = 2; ol[12] = 1; ol[13] = 1; ol[14] = 2; ol[15] = 0; ol[16] = 0;
		CHECK(rc_of(a, ol, 0x2c + 24, SLS_MSG_OrderWindowList + 100) == 0);
		g.h.msgh_id = SLS_MSG_GetOnScreenWindowCount; g.wid = owner_a;
		CHECK(xchg(a, &g, sizeof g, &vr, sizeof vr, NULL, NULL) == (int)sizeof vr && vr.value == 3);
		ol[8] = 5000; CHECK(rc_of(a, ol, 0x2c + 24, SLS_MSG_OrderWindowList + 100) == MIG_BAD_ARGUMENTS);                    /* count above 0x400 */
	}

	/* surfaces: AddSurface / BindSurface / GetSurfaceBinding / FlushSurface / RemoveSurface and the private buffer import */
	{
		/* register a shared-memory buffer by hand (the way a client sends it) */
		ws_buffer sb;
		CHECK(ws_buffer_create_shm(&sb, 100, 50, WS_FOURCC_ARGB8888) == 0);
		wsx_buffer_import_req iq; memset(&iq, 0, sizeof iq);
		{ mach_msg_header_t ih; hdr(&ih, sizeof iq, WSX_BUFFER_IMPORT, 1); memcpy(&iq.h, &ih, sizeof ih); }
		iq.body.msgh_descriptor_count = 1;
		iq.plane[0] = (mach_msg_port_descriptor_t){ .name = 1, .disposition = MACH_MSG_TYPE_MOVE_SEND, .type = MACH_MSG_PORT_DESCRIPTOR };
		iq.ndr = WS_NDR; iq.kind = WS_BUF_SHM; iq.width = 100; iq.height = 50; iq.fourcc = WS_FOURCC_ARGB8888; iq.nplanes = 1; iq.stride[0] = sb.stride[0]; iq.modifier = 0;
		struct iovec iv = { &iq, sizeof iq };
		sls_value_reply ir; int ifd[WS_IPC_MAX_FDS], inf = 0;
		CHECK(ws_ipc_send(a, &iv, 1, &sb.fd[0], 1) == 0 && ws_ipc_recv(a, &ir, sizeof ir, ifd, &inf) == (ssize_t)sizeof ir && ir.retcode == 0 && ir.value > 0);
		uint32_t buf_id = (uint32_t)ir.value;
		/* a stride below width*4 is refused, a count that disagrees with the descriptors is refused */
		iq.stride[0] = 100; sls_simple_reply ier;
		CHECK(ws_ipc_send(a, &iv, 1, &sb.fd[0], 1) == 0 && ws_ipc_recv(a, &ier, sizeof ier, ifd, &inf) == (ssize_t)sizeof ier && ier.retcode == CGS_ERROR_ILLEGAL_ARGUMENT);
		iq.stride[0] = sb.stride[0]; iq.body.msgh_descriptor_count = 2;
		CHECK(ws_ipc_send(a, &iv, 1, &sb.fd[0], 1) == 0 && ws_ipc_recv(a, &ier, sizeof ier, ifd, &inf) == (ssize_t)sizeof ier && ier.retcode == MIG_BAD_ARGUMENTS);

		/* AddSurface: not the owner -> 1000; owner -> an id */
		sls_wid_req aq; memset(&aq, 0, sizeof aq); hdr(&aq.h, sizeof aq, SLS_MSG_AddSurface, 0); aq.ndr = WS_NDR; aq.wid = w1;
		sls_value_reply vr; sls_simple_reply se2;
		CHECK(xchg(b, &aq, sizeof aq, &se2, sizeof se2, NULL, NULL) == (int)sizeof se2 && se2.retcode == CGS_ERROR_FAILURE);
		CHECK(xchg(a, &aq, sizeof aq, &vr, sizeof vr, NULL, NULL) == (int)sizeof vr && vr.retcode == 0 && vr.value > 0 && vr.h.msgh_size == 0x28);
		uint32_t sid = (uint32_t)vr.value;

		/* BindSurface: unknown surface -> 1001; wrong kind 3 -> 1001; bind the buffer (kind 4); GetSurfaceBinding returns what was bound */
		sls_bind_req bq; memset(&bq, 0, sizeof bq); hdr(&bq.h, sizeof bq, SLS_MSG_BindSurface, 0); bq.ndr = WS_NDR;
		bq.wid = w1; bq.sid = 99999; bq.kind = SLS_BIND_CONTEXT; bq.b = buf_id;
		CHECK(rc_of(a, &bq, sizeof bq, SLS_MSG_BindSurface + 100) == CGS_ERROR_ILLEGAL_ARGUMENT);
		bq.sid = sid; bq.kind = SLS_BIND_INVALID;
		CHECK(rc_of(a, &bq, sizeof bq, SLS_MSG_BindSurface + 100) == CGS_ERROR_ILLEGAL_ARGUMENT);
		bq.kind = SLS_BIND_CONTEXT; bq.b = 4242;                                          /* no such buffer */
		CHECK(rc_of(a, &bq, sizeof bq, SLS_MSG_BindSurface + 100) == CGS_ERROR_ILLEGAL_ARGUMENT);
		bq.kind = 9;                                                                      /* unknown kinds succeed as a no-op, as in the original */
		CHECK(rc_of(a, &bq, sizeof bq, SLS_MSG_BindSurface + 100) == 0);
		bq.kind = SLS_BIND_CONTEXT; bq.b = buf_id; bq.a = 7;
		CHECK(rc_of(b, &bq, sizeof bq, SLS_MSG_BindSurface + 100) == CGS_ERROR_FAILURE);   /* another connection holds no rights */
		CHECK(rc_of(a, &bq, sizeof bq, SLS_MSG_BindSurface + 100) == 0);
		sls_surface_req gq; memset(&gq, 0, sizeof gq); hdr(&gq.h, sizeof gq, SLS_MSG_GetSurfaceBinding, 0); gq.ndr = WS_NDR; gq.wid = w1; gq.level = (int32_t)sid;
		sls_binding_reply gr2;
		CHECK(xchg(a, &gq, sizeof gq, &gr2, sizeof gr2, NULL, NULL) == (int)sizeof gr2 && gr2.retcode == 0 && gr2.kind == SLS_BIND_CONTEXT && gr2.a == 7 && gr2.b == buf_id && gr2.h.msgh_size == 0x30);
		gq.level = 99999;
		CHECK(xchg(a, &gq, sizeof gq, &se2, sizeof se2, NULL, NULL) == (int)sizeof se2 && se2.retcode == CGS_ERROR_FAILURE);

		/* FlushSurface (30097): a region as the dirty area; size/descriptor mismatches are MIG errors; unknown surface 1001; empty region ok */
		uint8_t dreg[64]; ws_rect dr = { 0, 0, 50, 25 }; size_t drl = ws_region_serialize(&dr, 1, dreg, sizeof dreg);
		sls_flush_surface_req fq2; memset(&fq2, 0, sizeof fq2);
		{ mach_msg_header_t fh; hdr(&fh, sizeof fq2, SLS_MSG_FlushSurface, 1); memcpy(&fq2.h, &fh, sizeof fh); }
		fq2.body.msgh_descriptor_count = 1;
		fq2.region = (mach_msg_ool_descriptor_t){ .deallocate = 1, .copy = 1, .type = MACH_MSG_OOL_DESCRIPTOR, .size = (uint32_t)drl };
		fq2.ndr = WS_NDR; fq2.wid = w1; fq2.sid = sid; fq2.region_size = (uint32_t)drl;
		uint8_t fbuf[sizeof fq2 + 64]; memcpy(fbuf, &fq2, sizeof fq2); memcpy(fbuf + sizeof fq2, dreg, drl);
		CHECK(rc_of(a, fbuf, sizeof fq2 + drl, SLS_MSG_FlushSurface + 100) == 0);
		fq2.region_size = (uint32_t)drl + 4; memcpy(fbuf, &fq2, sizeof fq2);                 /* count field disagrees with the descriptor */
		CHECK(rc_of(a, fbuf, sizeof fq2 + drl, SLS_MSG_FlushSurface + 100) == MIG_TYPE_ERROR);
		fq2.region_size = (uint32_t)drl; fq2.sid = 99999; memcpy(fbuf, &fq2, sizeof fq2);
		CHECK(rc_of(a, fbuf, sizeof fq2 + drl, SLS_MSG_FlushSurface + 100) == CGS_ERROR_ILLEGAL_ARGUMENT);
		fq2.sid = sid; fq2.region.size = 0; fq2.region_size = 0; memcpy(fbuf, &fq2, sizeof fq2);   /* empty region: the whole surface */
		CHECK(rc_of(a, fbuf, sizeof fq2, SLS_MSG_FlushSurface + 100) == 0);
		uint8_t junk2[12] = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 };
		fq2.region.size = 12; fq2.region_size = 12; memcpy(fbuf, &fq2, sizeof fq2); memcpy(fbuf + sizeof fq2, junk2, 12);
		CHECK(rc_of(a, fbuf, sizeof fq2 + 12, SLS_MSG_FlushSurface + 100) == CGS_ERROR_FAILURE);   /* an undecodable region */

		/* the committed buffer is what gets composed: paint it, screenshot-free check through window shape/bounds is not possible, so unbind and remove */
		bq.kind = SLS_BIND_NONE; bq.a = 0; bq.b = 0;
		CHECK(rc_of(a, &bq, sizeof bq, SLS_MSG_BindSurface + 100) == 0);
		CHECK(xchg(a, &gq, sizeof gq, &se2, sizeof se2, NULL, NULL) == (int)sizeof se2);       /* (surface 99999 still unknown) */
		gq.level = (int32_t)sid;
		CHECK(xchg(a, &gq, sizeof gq, &gr2, sizeof gr2, NULL, NULL) == (int)sizeof gr2 && gr2.kind == SLS_BIND_NONE);
		sls_surface_req rq2; memset(&rq2, 0, sizeof rq2); hdr(&rq2.h, sizeof rq2, SLS_MSG_RemoveSurface, 0); rq2.ndr = WS_NDR; rq2.wid = w1; rq2.level = (int32_t)sid;
		CHECK(rc_of(b, &rq2, sizeof rq2, SLS_MSG_RemoveSurface + 100) == CGS_ERROR_FAILURE);
		CHECK(rc_of(a, &rq2, sizeof rq2, SLS_MSG_RemoveSurface + 100) == 0);
		CHECK(xchg(a, &gq, sizeof gq, &se2, sizeof se2, NULL, NULL) == (int)sizeof se2 && se2.retcode == CGS_ERROR_FAILURE);   /* gone */
		/* release the buffer: owner only; second release fails */
		wsx_buffer_release_req br; memset(&br, 0, sizeof br); hdr(&br.h, sizeof br, WSX_BUFFER_RELEASE, 0); br.ndr = WS_NDR; br.level = (int32_t)buf_id;
		CHECK(rc_of(b, &br, sizeof br, WSX_BUFFER_RELEASE + 100) == CGS_ERROR_ILLEGAL_ARGUMENT);
		CHECK(rc_of(a, &br, sizeof br, WSX_BUFFER_RELEASE + 100) == 0);
		CHECK(rc_of(a, &br, sizeof br, WSX_BUFFER_RELEASE + 100) == CGS_ERROR_ILLEGAL_ARGUMENT);
		ws_buffer_close(&sb);
	}

	/* rights: another connection cannot move or order the window (1000), and level/alpha are silently ignored (0) */
	CHECK(rc_of(b, &mv, sizeof mv, SLS_MSG_MoveWindow + 100) == CGS_ERROR_FAILURE);
	CHECK(rc_of(b, &od, sizeof od, SLS_MSG_OrderWindow + 100) == CGS_ERROR_FAILURE);
	CHECK(rc_of(b, &lv, sizeof lv, SLS_MSG_SetWindowLevel + 100) == 0);
	mv.wid = 0; CHECK(rc_of(a, &mv, sizeof mv, SLS_MSG_MoveWindow + 100) == CGS_ERROR_FAILURE);   /* window id 0 */
	mv.wid = 99999; CHECK(rc_of(a, &mv, sizeof mv, SLS_MSG_MoveWindow + 100) == CGS_ERROR_FAILURE); /* unknown window */

	/* request validation as in the decompiled routines */
	mv.wid = w1;
	mv.h.msgh_bits |= MACH_MSGH_BITS_COMPLEX;                                              /* complex bit set on a simple routine */
	CHECK(rc_of(a, &mv, sizeof mv, SLS_MSG_MoveWindow + 100) == MIG_BAD_ARGUMENTS);
	mv.h.msgh_bits &= ~MACH_MSGH_BITS_COMPLEX;
	{                                                                                      /* wrong size: 48 bytes, size field 48 */
		uint8_t big[48]; memset(big, 0, sizeof big); memcpy(big, &mv, sizeof mv);
		((mach_msg_header_t *)big)->msgh_size = sizeof big;
		CHECK(rc_of(a, big, sizeof big, SLS_MSG_MoveWindow + 100) == MIG_BAD_ARGUMENTS);
		/* size field larger than the bytes delivered: cannot happen with Mach, answered with a MIG error reply */
		mv.h.msgh_size = sizeof mv + 4;
		sls_simple_reply e; int fds[WS_IPC_MAX_FDS], nfds = 0;
		CHECK(xchg(a, &mv, sizeof mv, &e, sizeof e, fds, &nfds) == (int)sizeof e && e.h.msgh_id == MACH_ERROR_REPLY_ID && e.retcode == MIG_BAD_ARGUMENTS);
		mv.h.msgh_size = sizeof mv;
	}
	/* CreateWindow with a descriptor size that disagrees with the size field: MIG_TYPE_ERROR */
	{
		uint8_t region[64]; ws_rect f = { 0, 0, 20, 20 }; size_t rl = ws_region_serialize(&f, 1, region, sizeof region);
		sls_create_window_req q; memset(&q, 0, sizeof q);
		{ mach_msg_header_t h; hdr(&h, sizeof q, SLS_MSG_CreateWindow, 1); memcpy(&q.h, &h, sizeof h); }
		q.body.msgh_descriptor_count = 1;
		q.region = (mach_msg_ool_descriptor_t){ .type = MACH_MSG_OOL_DESCRIPTOR, .copy = 1, .deallocate = 1, .size = (uint32_t)rl };
		q.ndr = WS_NDR; q.window_type = 2; q.region_size = (uint32_t)rl + 4;
		struct iovec v[2] = { { &q, sizeof q }, { region, rl } };
		sls_simple_reply e;
		ws_ipc_send(a, v, 2, NULL, 0);
		int fds[WS_IPC_MAX_FDS], nfds = 0;
		CHECK(ws_ipc_recv(a, &e, sizeof e, fds, &nfds) == (ssize_t)sizeof e && e.retcode == MIG_TYPE_ERROR);
		/* a malformed region is a plain failure */
		uint8_t junk[12] = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 };
		q.region.size = 12; q.region_size = 12;
		struct iovec v2[2] = { { &q, sizeof q }, { junk, 12 } };
		ws_ipc_send(a, v2, 2, NULL, 0);
		CHECK(ws_ipc_recv(a, &e, sizeof e, fds, &nfds) == (ssize_t)sizeof e && e.retcode == CGS_ERROR_FAILURE);
	}
	/* unknown / unimplemented id: MIG error reply (id 71) with MIG_BAD_ID */
	{
		sls_terminate_req t; memset(&t, 0, sizeof t); hdr(&t.h, sizeof t, 30000 + 646, 0); t.ndr = WS_NDR;
		sls_simple_reply e; int fds[WS_IPC_MAX_FDS], nfds = 0;
		CHECK(xchg(a, &t, sizeof t, &e, sizeof e, fds, &nfds) == (int)sizeof e && e.h.msgh_id == MACH_ERROR_REPLY_ID && e.retcode == MIG_BAD_ID);
		t.h.msgh_id = 12345;
		CHECK(xchg(a, &t, sizeof t, &e, sizeof e, fds, &nfds) == (int)sizeof e && e.h.msgh_id == MACH_ERROR_REPLY_ID && e.retcode == MIG_BAD_ID);
	}

	/* TerminateWindow: a non-owner is ignored (0, window stays), the owner removes it; a disconnect removes the rest */
	sls_terminate_req tr; memset(&tr, 0, sizeof tr); hdr(&tr.h, sizeof tr, SLS_MSG_TerminateWindow, 0); tr.ndr = WS_NDR; tr.wid = w1;
	CHECK(rc_of(b, &tr, sizeof tr, SLS_MSG_TerminateWindow + 100) == 0);
	CHECK(xchg(a, &fq, sizeof fq, &fr, sizeof fr, NULL, NULL) == (int)sizeof fr && fr.wid == w1);   /* still there */
	CHECK(rc_of(a, &tr, sizeof tr, SLS_MSG_TerminateWindow + 100) == 0);
	CHECK(xchg(a, &fq, sizeof fq, &fr, sizeof fr, NULL, NULL) == (int)sizeof fr && fr.wid != w1);   /* gone */
	close(a);                                                                          /* its other windows go with the connection */
	usleep(100000);
	fq.x = 5; fq.y = 5;
	CHECK(xchg(b, &fq, sizeof fq, &fr, sizeof fr, NULL, NULL) == (int)sizeof fr && fr.wid == 0);

	wsx_req qq; memset(&qq, 0, sizeof qq); hdr(&qq.h, sizeof qq, WSX_QUIT, 0); qq.ndr = WS_NDR;
	{ wsx_rep qr; xchg(b, &qq, sizeof qq, &qr, sizeof qr, NULL, NULL); }
	printf(fails ? "%d failures\n" : "wire conformance tests passed\n", fails);
	return fails != 0;
}
