#include "car.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>
#include "lzfse/lzfse_internal.h"
#include "lzfse/lzfse.h"

struct CarFile {
	uint8_t *buf; size_t len; int mapped;                    /* the file, mapped (the system catalogue of the symbols is 117 MB: only the pages that are looked at are read) */
	uint32_t nblocks; const uint8_t *index;                  /* the block table: (address, length) pairs, big-endian */
	uint32_t renditions_tree;
	int nkeys; uint32_t keyids[32];                          /* KEYFORMAT */
	int count; uint32_t *keyblk, *valblk;                    /* the leaves of the rendition tree */
};

static uint32_t be32(const uint8_t *p) { return (uint32_t)p[0] << 24 | p[1] << 16 | p[2] << 8 | p[3]; }
static uint32_t le32(const uint8_t *p) { return (uint32_t)p[3] << 24 | p[2] << 16 | p[1] << 8 | p[0]; }
static uint16_t le16(const uint8_t *p) { return (uint16_t)(p[1] << 8 | p[0]); }
static uint16_t be16(const uint8_t *p) { return (uint16_t)(p[0] << 8 | p[1]); }

static const uint8_t *block(const CarFile *c, uint32_t i, size_t *len)
{
	if (i >= c->nblocks) return NULL;
	uint32_t a = be32(c->index + 4 + 8 * (size_t)i), l = be32(c->index + 8 + 8 * (size_t)i);
	if ((size_t)a + l > c->len) return NULL;
	if (len) *len = l; return c->buf + a;
}

/* the entries of a BOM tree: down the first children to the leftmost leaf, then along the leaves' forward links (the inner nodes do not list every child) */
static void collect(CarFile *c, uint32_t node)
{
	size_t n; const uint8_t *b;
	for (int depth = 0; depth < 16; depth++) {
		b = block(c, node, &n); if (!b || n < 16) return;
		if (be16(b)) break;
		node = be32(b + 12);
	}
	for (int guard = 0; node && guard < 100000; guard++) {
		b = block(c, node, &n); if (!b || n < 12) return;
		int cnt = be16(b + 2);
		for (int k = 0; k < cnt && 12 + 8 * (size_t)k + 8 <= n; k++) {
			uint32_t v = be32(b + 12 + 8 * k), key = be32(b + 16 + 8 * k);
			if (c->count % 1024 == 0) { c->keyblk = realloc(c->keyblk, (size_t)(c->count + 1024) * 4); c->valblk = realloc(c->valblk, (size_t)(c->count + 1024) * 4); }
			c->keyblk[c->count] = key; c->valblk[c->count] = v; c->count++;
		}
		node = be32(b + 4);
	}
}

CarFile *car_open(const char *path)
{
	int fd = open(path, O_RDONLY); if (fd < 0) return NULL;
	struct stat st; if (fstat(fd, &st) || st.st_size < 32) { close(fd); return NULL; }
	CarFile *c = calloc(1, sizeof *c); c->len = (size_t)st.st_size;
	void *m = mmap(NULL, c->len, PROT_READ, MAP_PRIVATE, fd, 0); close(fd);
	if (m == MAP_FAILED || memcmp(m, "BOMStore", 8)) { if (m != MAP_FAILED) munmap(m, c->len); free(c); return NULL; }
	c->buf = m; c->mapped = 1;
	uint32_t ioff = be32(c->buf + 16), voff = be32(c->buf + 24);
	c->nblocks = be32(c->buf + ioff); c->index = c->buf + ioff;
	uint32_t nvars = be32(c->buf + voff); const uint8_t *p = c->buf + voff + 4; uint32_t kf = 0, rend = 0;
	for (uint32_t i = 0; i < nvars; i++) {
		uint32_t idx = be32(p); int l = p[4]; const char *nm = (const char *)p + 5;
		if (l == 9 && !memcmp(nm, "KEYFORMAT", 9)) kf = idx; else if (l == 10 && !memcmp(nm, "RENDITIONS", 10)) rend = idx;
		p += 5 + l;
	}
	size_t kl; const uint8_t *k = block(c, kf, &kl);
	if (!k || kl < 12 || memcmp(k, "tmfk", 4)) { car_close(c); return NULL; }
	c->nkeys = (int)le32(k + 8); if (c->nkeys > 32) c->nkeys = 32;
	for (int i = 0; i < c->nkeys; i++) c->keyids[i] = le32(k + 12 + 4 * i);
	size_t tl; const uint8_t *t = block(c, rend, &tl);
	if (!t || tl < 20 || memcmp(t, "tree", 4)) { car_close(c); return NULL; }
	collect(c, be32(t + 8));
	return c;
}
void car_close(CarFile *c) { if (!c) return; if (c->mapped) munmap(c->buf, c->len); else free(c->buf); free(c->keyblk); free(c->valblk); free(c); }
int car_count(const CarFile *c) { return c->count; }

int car_rendition(const CarFile *c, int i, CarRendition *r)
{
	if (i < 0 || i >= c->count) return -1;
	size_t kl, vl; const uint8_t *key = block(c, c->keyblk[i], &kl), *v = block(c, c->valblk[i], &vl);
	if (!key || !v || vl < 184 || memcmp(v, "ISTC", 4)) { if (getenv("CAR_DEBUG")) fprintf(stderr, "rendition %d: key %p val %p len %zu\n", i, (const void *)key, (const void *)v, vl); return -1; }
	memset(r, 0, sizeof *r); for (int k = 0; k < 32; k++) r->attr[k] = -1;
	for (int k = 0; k < c->nkeys && (size_t)(2 * k + 2) <= kl; k++) if (c->keyids[k] < 32) r->attr[c->keyids[k]] = le16(key + 2 * k);
	r->name = (const char *)v + 40; r->width = (int)le32(v + 12); r->height = (int)le32(v + 16); r->scale = (int)le32(v + 20) / 100; r->pixel_format = le32(v + 24); r->layout = le16(v + 36);
	r->csi = v; r->csi_len = vl;
	size_t tl = le32(v + 168); if (184 + tl > vl) return -1;
	r->tlv = v + 184; r->tlv_len = tl; r->payload = v + 184 + tl; r->payload_len = vl - 184 - tl;
	return 0;
}

int car_find(const CarFile *c, const char *name, int state, int value, int scale, CarRendition *out)
{
	for (int i = 0; i < c->count; i++) {
		CarRendition r; if (car_rendition(c, i, &r) || strcmp(r.name, name)) continue;
		if (state >= 0 && r.attr[CAR_STATE] != state) continue;
		if (value >= 0 && r.attr[CAR_VALUE] != value) continue;
		if (scale >= 0 && r.scale != scale) continue;
		*out = r; return 0;
	}
	return -1;
}

const uint8_t *car_tlv(const CarRendition *r, uint32_t tag, size_t *len)
{
	size_t p = 0;
	while (p + 8 <= r->tlv_len) {
		uint32_t t = le32(r->tlv + p), l = le32(r->tlv + p + 4); if (p + 8 + l > r->tlv_len) break;
		if (t == tag) { if (len) *len = l; return r->tlv + p + 8; }
		p += 8 + l;
	}
	return NULL;
}

uint8_t *car_data(const CarRendition *r, size_t *len)
{
	const uint8_t *p = r->payload; size_t n = r->payload_len;
	if (n < 12 || memcmp(p, "DWAR", 4)) return NULL;                                       /* "RAWD": version, length of the stream, then the stream */
	uint32_t ver = le32(p + 4), slen = le32(p + 8); if ((size_t)slen + 12 > n) return NULL;
	if (!ver) { uint8_t *o = malloc(slen + 1); if (o) { memcpy(o, p + 12, slen); *len = slen; } return o; }       /* stored */
	for (size_t cap = (size_t)slen * 4 + 256; cap <= (64u << 20); cap *= 2) {              /* an LZFSE stream; its size is not recorded, CoreUI's own decoder grows the buffer the same way */
		uint8_t *out = malloc(cap); if (!out) return NULL;
		size_t got = lzfse_decode_buffer(out, cap, p + 12, slen, NULL);
		if (got > 0 && got < cap) { if (len) *len = got; return out; }
		free(out);
	}
	return NULL;
}

/* the vector glyphs: the renditions called "<name>.svg" whose part is 59 carry one "BVG " container per weight (key attribute 26: 1 ultralight .. 4 regular .. 9 black); the nearest weight wins */
int car_symbols(const CarFile *c, const char *const *names, int n, int weight, uint8_t **out, size_t *outlen)
{
	int *best = calloc((size_t)n, sizeof *best), found = 0; for (int k = 0; k < n; k++) { best[k] = 99; out[k] = NULL; outlen[k] = 0; }
	for (int i = 0; i < c->count; i++) {
		size_t kl; const uint8_t *key = block(c, c->keyblk[i], &kl); if (!key) continue;
		int part = -1, w = -1;
		for (int k = 0; k < c->nkeys && (size_t)(2 * k + 2) <= kl; k++) { if (c->keyids[k] == CAR_PART) part = le16(key + 2 * k); else if (c->keyids[k] == 26) w = le16(key + 2 * k); }
		if (part != 59 || w < 0) continue;
		CarRendition r; if (car_rendition(c, i, &r)) continue;
		size_t nl = strlen(r.name); if (nl < 5 || strcmp(r.name + nl - 4, ".svg")) continue;
		for (int k = 0; k < n; k++) {
			if (strlen(names[k]) != nl - 4 || strncmp(names[k], r.name, nl - 4)) continue;
			int d = abs(w - weight); if (d >= best[k]) break;
			size_t len; uint8_t *data = car_data(&r, &len); if (!data || len < 4 || memcmp(data, "BVG ", 4)) { free(data); break; }
			if (!out[k]) found++; free(out[k]); out[k] = data; outlen[k] = len; best[k] = d; break;
		}
	}
	free(best); return found;
}
