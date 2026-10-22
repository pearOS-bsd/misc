/* wsbsd token, first firmware: proves the toolchain and the USB link. Line protocol over USB CDC: PING, INFO, RNG, SHA <text>. */
#include <stdio.h>
#include <string.h>
#include "pico/stdlib.h"
#include "pico/rand.h"
#include "pico/unique_id.h"
#include "pico/sha256.h"

static void hex(const uint8_t *p, size_t n) { for (size_t i = 0; i < n; i++) printf("%02x", p[i]); }
int main(void)
{
	stdio_init_all(); char line[256]; size_t n = 0;
	for (;;) {
		int c = getchar_timeout_us(100000); if (c == PICO_ERROR_TIMEOUT) continue;
		if (c == '\r' || c == '\n') {
			line[n] = 0; n = 0; if (!line[0]) continue;
			if (!strcmp(line, "PING")) printf("PONG wsbsd-token\n");
			else if (!strcmp(line, "INFO")) { pico_unique_board_id_t id; pico_get_unique_board_id(&id); printf("OK id="); hex(id.id, 8); printf(" chip=RP2350\n"); }
			else if (!strcmp(line, "RNG")) { uint8_t r[32]; for (int i = 0; i < 4; i++) { uint64_t v = get_rand_64(); memcpy(r + 8 * i, &v, 8); } printf("OK "); hex(r, 32); printf("\n"); }
			else if (!strncmp(line, "SHA ", 4)) { pico_sha256_state_t st; sha256_result_t res; if (pico_sha256_start_blocking(&st, SHA256_BIG_ENDIAN, true) == PICO_OK) { pico_sha256_update_blocking(&st, (const uint8_t *)line + 4, strlen(line + 4)); pico_sha256_finish(&st, &res); printf("OK "); hex(res.bytes, 32); printf("\n"); } else printf("ERR sha\n"); }
			else printf("ERR unknown\n");
		} else if (n < sizeof line - 1) line[n++] = (char)c;
	}
}
