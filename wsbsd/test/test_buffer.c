/* The row stride and allocation rules of the IOSurface contract, as probed on macOS 27.0 (IOSurfaceCreate, BGRA, 4 bytes per element). */
#include "ws_buffer.h"
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static int fails;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); fails++; } } while (0)

int main(void)
{
	static const struct { int w, h; size_t stride, alloc; } V[] = {
		{ 100, 50, 512, 32768 }, { 101, 50, 512, 32768 }, { 640, 480, 2560, 1228800 },
		{ 1920, 1080, 7680, 8306688 }, { 1, 1, 128, 16384 }, { 300, 10, 1280, 16384 },
	};
	for (unsigned i = 0; i < sizeof V / sizeof V[0]; i++) {
		size_t s = ws_buffer_stride_for(V[i].w, 4);
		if (s != V[i].stride || ws_buffer_alloc_size(s, V[i].h) != V[i].alloc) {
			printf("mismatch %dx%d: stride %zu (want %zu), alloc %zu (want %zu)\n", V[i].w, V[i].h, s, V[i].stride, ws_buffer_alloc_size(s, V[i].h), V[i].alloc);
			fails++;
		}
	}
	CHECK(ws_buffer_bytes_per_pixel(WS_FOURCC_ARGB8888) == 4 && ws_buffer_bytes_per_pixel(0x12345678) == 0);
	/* a shared-memory buffer: aligned stride, mapped, writable, and the same pages are visible through a second mapping */
	ws_buffer b;
	CHECK(ws_buffer_create_shm(&b, 100, 50, WS_FOURCC_ARGB8888) == 0);
	CHECK(b.stride[0] == 512 && b.cpu && b.cpu->stride == 512 && b.cpu->w == 100 && b.cpu->h == 50 && b.modifier == 0 && b.nplanes == 1 && b.kind == WS_BUF_SHM);
	if (b.cpu) {
		b.cpu->px[3] = 0x7f;
		ws_buffer c; ws_buffer_init(&c);
		c.kind = WS_BUF_SHM; c.w = 100; c.h = 50; c.fourcc = WS_FOURCC_ARGB8888; c.nplanes = 1; c.stride[0] = 512; c.fd[0] = dup(b.fd[0]);
		CHECK(ws_buffer_map(&c) == 0 && c.cpu && c.cpu->px[3] == 0x7f);
		ws_buffer_close(&c);
	}
	ws_buffer_close(&b);
	/* invalid descriptions are refused */
	CHECK(ws_buffer_create_shm(&b, 0, 10, WS_FOURCC_ARGB8888) < 0 && ws_buffer_create_shm(&b, 10, 10, 0x12345678) < 0 && ws_buffer_create_shm(&b, 20000, 10, WS_FOURCC_ARGB8888) < 0);
	ws_buffer bad; ws_buffer_init(&bad); bad.w = 100; bad.h = 50; bad.fourcc = WS_FOURCC_ARGB8888; bad.nplanes = 1; bad.stride[0] = 100;   /* stride below w*4 */
	CHECK(ws_buffer_map(&bad) < 0);
	printf(fails ? "%d failures\n" : "buffer contract tests passed (stride and allocation rules match IOSurface)\n", fails);
	return fails != 0;
}
