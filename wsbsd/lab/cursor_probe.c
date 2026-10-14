/* lab probe: register a cursor with known numbers on the REAL WindowServer and read everything back (hotspot/size order, pixel format, seed).
 * The private routines are called through addresses computed from SLSMainConnectionID; the offsets are those of the runner's SkyLight build (lldb lookup). */
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
typedef int (*conn_fn)(void);
typedef int (*reg2_fn)(double, double, double, double, double, double, float, int, const char *, uint8_t, uint8_t, unsigned, void *, int, void *, int, int, int, int *);
typedef int (*get2_fn)(int, const char *, void *, unsigned *, int *, double *, double *, double *, int *, int *, int *, int *, int *);
typedef int (*size_fn)(int, const char *, int *);
#define OFF_MAIN 0x187039490UL
int main(void)
{
	setvbuf(stdout, NULL, _IONBF, 0);
	void *h = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW);
	conn_fn mainconn = dlsym(h, "SLSMainConnectionID");
	uintptr_t base = (uintptr_t)mainconn - OFF_MAIN;
	reg2_fn reg = (reg2_fn)(base + 0x186e726dcUL);
	get2_fn get = (get2_fn)(base + 0x186e739c8UL);
	size_fn gsz = (size_fn)(base + 0x186e736a4UL);
	int cid = mainconn();
	printf("cid %d\n", cid);
	int cols = 64, rows = 48;
	uint8_t *px = malloc((size_t)cols * rows * 4);
	for (int i = 0; i < cols * rows; i++) { px[i * 4] = 255; px[i * 4 + 1] = i & 0xff; px[i * 4 + 2] = (i >> 8) & 0xff; px[i * 4 + 3] = 0x44; }   /* bytes A,R,G,B */
	int out = -1;
	int ok = reg(cols, rows, 32, 24, 10, 14, 0.5f, cid, "wsbsd.probe.cursor", 0, 0, 0, px, cols * 4, NULL, 0, 4, 1, &out);
	printf("register ok=%d out=%d\n", ok, out);
	unsigned sz = (unsigned)cols * rows * 4 + 64;
	uint8_t *buf = calloc(1, sz);
	int rb = 0, bpp = 0, spp = 0, bps = 0, u1 = -1, u2 = -1;
	double pxsz[2] = { -1, -1 }, a[2] = { -1, -1 }, b[2] = { -1, -1 };
	int rc = get(cid, "wsbsd.probe.cursor", buf, &sz, &rb, pxsz, a, b, &bpp, &spp, &bps, &u1, &u2);
	printf("get rc=%d size=%u rowbytes=%d pxsz=(%g,%g) param7=(%g,%g) param8=(%g,%g) bpp=%d spp=%d bps=%d frames=%d dur_bits=0x%x\n", rc, sz, rb, pxsz[0], pxsz[1], a[0], a[1], b[0], b[1], bpp, spp, bps, u1, u2);
	printf("src px0 bytes %02x %02x %02x %02x -> stored %02x %02x %02x %02x\n", px[0], px[1], px[2], px[3], buf[0], buf[1], buf[2], buf[3]);
	printf("src px5 bytes %02x %02x %02x %02x -> stored %02x %02x %02x %02x\n", px[20], px[21], px[22], px[23], buf[20], buf[21], buf[22], buf[23]);
	int s2 = 0; rc = gsz(cid, "wsbsd.probe.cursor", &s2);
	printf("datasize rc=%d %d\n", rc, s2);
	/* second registration with 2 frames, global flag and flags&1 (no premultiply) */
	uint8_t *px2 = malloc((size_t)8 * 8 * 2 * 4); memset(px2, 0x80, 8 * 8 * 2 * 4);
	out = -1; ok = reg(8, 8, 8, 8, 0, 0, 0.1f, cid, "wsbsd.probe.cursor2", 0, 0, 1, px2, 32, NULL, 0, 4, 2, &out);
	unsigned sz2 = 4096; uint8_t *b2 = calloc(1, sz2); double p2[2], q2[2], r2[2]; int rb2, bpp2, spp2, bps2, f2 = -1, d2 = -1;
	rc = get(cid, "wsbsd.probe.cursor2", b2, &sz2, &rb2, p2, q2, r2, &bpp2, &spp2, &bps2, &f2, &d2);
	printf("frames reg ok=%d get rc=%d size=%u rowbytes=%d pxsz=(%g,%g) frames=%d dur=0x%x first bytes %02x %02x %02x %02x\n", ok, rc, sz2, rb2, p2[0], p2[1], f2, d2, b2[0], b2[1], b2[2], b2[3]);
	return 0;
}
