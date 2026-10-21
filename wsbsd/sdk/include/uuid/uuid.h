/* libuuid's API (uuid_generate, uuid_unparse, uuid_parse, ...) over arc4random: version 4 UUIDs */
#ifndef WSBSD_UUID_UUID_H
#define WSBSD_UUID_UUID_H
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
typedef unsigned char uuid_t[16];
typedef char uuid_string_t[37];
static inline void uuid_generate_random(uuid_t out) { arc4random_buf(out, 16); out[6] = (out[6] & 0x0f) | 0x40; out[8] = (out[8] & 0x3f) | 0x80; }
static inline void uuid_generate(uuid_t out) { uuid_generate_random(out); }
static inline void uuid_clear(uuid_t u) { memset(u, 0, 16); }
static inline int uuid_is_null(const uuid_t u) { for (int i = 0; i < 16; i++) if (u[i]) return 0; return 1; }
static inline int uuid_compare(const uuid_t a, const uuid_t b) { return memcmp(a, b, 16); }
static inline void uuid_copy(uuid_t dst, const uuid_t src) { memcpy(dst, src, 16); }
static inline void uuid_unparse_upper(const uuid_t u, char *out)
{
	static const char *h = "0123456789ABCDEF"; int o = 0;
	for (int i = 0; i < 16; i++) { if (i == 4 || i == 6 || i == 8 || i == 10) out[o++] = '-'; out[o++] = h[u[i] >> 4]; out[o++] = h[u[i] & 15]; }
	out[o] = 0;
}
static inline void uuid_unparse_lower(const uuid_t u, char *out)
{
	uuid_unparse_upper(u, out); for (int i = 0; out[i]; i++) if (out[i] >= 'A' && out[i] <= 'F') out[i] += 32;
}
static inline void uuid_unparse(const uuid_t u, char *out) { uuid_unparse_upper(u, out); }
static inline int uuid_parse(const char *in, uuid_t out)
{
	int n = 0; unsigned char b[16];
	for (int i = 0; in[i] && n < 32; i++) {
		if (in[i] == '-') { if (i != 8 && i != 13 && i != 18 && i != 23) return -1; continue; }
		int v = in[i] >= '0' && in[i] <= '9' ? in[i] - '0' : in[i] >= 'a' && in[i] <= 'f' ? in[i] - 'a' + 10 : in[i] >= 'A' && in[i] <= 'F' ? in[i] - 'A' + 10 : -1;
		if (v < 0) return -1; if (n & 1) b[n / 2] |= (unsigned char)v; else b[n / 2] = (unsigned char)(v << 4); n++;
	}
	if (n != 32) return -1; memcpy(out, b, 16); return 0;
}
#endif
