/* Golden vectors: serialised regions produced by the live macOS 27.0 region code (see docs/SPEC-SLS-WIRE.md section 5). */
#include "ws_region.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int fails;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); fails++; } } while (0)

typedef struct { const char *name; ws_rect in[4]; int n; uint32_t words[32]; int nw; ws_rect bounds; } vec;
#define E 0x7fffffff
static const vec V[] = {
	{ "0,0 100x50",        { {0,0,100,50} }, 1, { 0x80000000,2, 0,4,0,0x64,0x32,2,E }, 9, {0,0,100,50} },
	{ "10,20 300x200",     { {10,20,300,200} }, 1, { 0x80000000,2, 0x14,4,0xa,0x136,0xdc,2,E }, 9, {10,20,300,200} },
	{ "-5,-5 1x1",         { {-5,-5,1,1} }, 1, { 0x80000000,2, 0xfffffffb,4,0xfffffffb,0xfffffffc,0xfffffffc,2,E }, 9, {-5,-5,1,1} },
	{ "0,0 640x420",       { {0,0,640,420} }, 1, { 0x80000000,2, 0,4,0,0x280,0x1a4,2,E }, 9, {0,0,640,420} },
	{ "two apart (gap band)", { {0,0,50,50},{100,100,30,30} }, 2, { 0x80000000,2, 0,4,0,0x32,0x32,2,0x64,4,0x64,0x82,0x82,2,E }, 15, {0,0,130,130} },
	{ "two runs one band", { {0,0,10,10},{20,0,10,10} }, 2, { 0x80000000,2, 0,6,0,0xa,0x14,0x1e,0xa,2,E }, 11, {0,0,30,10} },
	{ "L shape",           { {0,0,10,10},{0,10,30,10} }, 2, { 0x80000000,2, 0,4,0,0xa,0xa,4,0,0x1e,0x14,2,E }, 13, {0,0,30,20} },
	{ "three runs",        { {0,0,5,5},{10,0,5,5},{20,0,5,5} }, 3, { 0x80000000,2, 0,8,0,5,0xa,0xf,0x14,0x19,5,2,E }, 13, {0,0,25,5} },
	{ "stepped",           { {0,0,10,10},{5,5,10,10} }, 2, { 0x80000000,2, 0,4,0,0xa,5,4,0,0xf,0xa,4,5,0xf,0xf,2,E }, 17, {0,0,15,15} },
	{ "outward rounding",  { {0,0,11,11} }, 1, { 0x80000000,2, 0,4,0,0xb,0xb,2,E }, 9, {0,0,11,11} },
	{ "adjacent merge",    { {0,0,10,5},{0,5,10,5} }, 2, { 0x80000000,2, 0,4,0,0xa,0xa,2,E }, 9, {0,0,10,10} },
};

int main(void)
{
	for (unsigned i = 0; i < sizeof V / sizeof V[0]; i++) {
		const vec *v = &V[i];
		uint8_t want[128];
		memcpy(want, v->words, (size_t)v->nw * 4);
		uint8_t got[256];
		size_t gl = ws_region_serialize(v->in, v->n, got, sizeof got);
		if (gl != (size_t)v->nw * 4 || memcmp(got, want, gl)) { printf("serialize mismatch: %s (len %zu want %d)\n", v->name, gl, v->nw * 4); fails++; }
		ws_rect *r; int n; ws_rect b;
		int rc = ws_region_parse(want, (uint32_t)v->nw * 4, &r, &n, &b);
		if (rc || memcmp(&b, &v->bounds, sizeof b)) { printf("parse/bounds mismatch: %s (rc %d bounds %d,%d %dx%d)\n", v->name, rc, b.x, b.y, b.w, b.h); fails++; }
		free(r);
	}
	/* empty region */
	{
		uint32_t e[3] = { 0x80000000u, 2, E };
		uint8_t out[32];
		CHECK(ws_region_serialize(NULL, 0, out, sizeof out) == 12 && memcmp(out, e, 12) == 0);
		ws_rect *r; int n; ws_rect b;
		CHECK(ws_region_parse((uint8_t *)e, 12, &r, &n, &b) == 0 && n == 0 && r == NULL);
	}
	/* malformed input is rejected */
	{
		uint32_t bad1[3] = { 0x80000000u, 3, E };                      /* wrong version */
		uint32_t bad2[6] = { 0x80000000u, 2, 0, 4, 0, 5 };             /* truncated */
		uint32_t bad3[9] = { 0x80000000u, 2, 0, 4, 9, 3, 5, 2, E };    /* x1 <= x0 */
		ws_rect *r; int n; ws_rect b;
		CHECK(ws_region_parse((uint8_t *)bad1, 12, &r, &n, &b) < 0);
		CHECK(ws_region_parse((uint8_t *)bad2, 24, &r, &n, &b) < 0);
		CHECK(ws_region_parse((uint8_t *)bad3, 36, &r, &n, &b) < 0);
		CHECK(ws_region_parse((uint8_t *)bad1, 11, &r, &n, &b) < 0);
	}
	printf(fails ? "%d failures\n" : "region tests passed (all golden vectors match)\n", fails);
	return fails != 0;
}
