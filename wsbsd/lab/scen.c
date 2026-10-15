/* lab scenario runner: executes a small script against the REAL WindowServer and prints raw replies.
 *   new_window NAME X Y W H        creates a window (never ordered in) and names it
 *   order NAME above|below|out     SLSOrderWindow
 *   level NAME N                   SLSSetWindowLevel
 *   raw ID TOKEN...                sends a raw request: tokens ndr | u32:N | i32:N | wid:NAME | cid | f32:X | f64:X | hex:AABB | str:TEXT (4-byte padded) | pad:N
 *   expect-complex                 (ignored)   # lines starting with # are comments
 * Needs PORT_FN in the environment (runtime address of CGSGetConnectionPortById, from portfn). */
#include <dlfcn.h>
#include <servers/bootstrap.h>
#include <mach/mach.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <sys/mman.h>
typedef struct { double x, y, w, h; } R;
typedef void *Region;
static int cid; static mach_port_t srvport;
static struct { char name[32]; uint32_t wid; } wins[32]; static int nwins;
static uint32_t wid_of(const char *n) { for (int i = 0; i < nwins; i++) if (!strcmp(wins[i].name, n)) return wins[i].wid; return 0; }

static void raw(int id, char **tok, int nt)
{
	uint8_t req[0x2000]; memset(req, 0, sizeof req); size_t n = 0x18;
	int complex = 0;
	for (int i = 0; i < nt; i++) {
		char *t = tok[i];
		if (!strncmp(t, "ool:", 4)) {                       /* one out-of-line descriptor: count@0x18, descriptor@0x1c..0x2b, the next token lands at 0x2c */
			size_t hl = strlen(t + 4) / 2; uint8_t *mem = mmap(0, 0x4000, PROT_READ | PROT_WRITE, MAP_ANON | MAP_PRIVATE, -1, 0);
			for (size_t k = 0; k < hl; k++) { unsigned v; sscanf(t + 4 + 2 * k, "%2x", &v); mem[k] = (uint8_t)v; }
			uint32_t one = 1, sz = (uint32_t)hl; uint64_t addr = (uint64_t)(uintptr_t)mem; uint8_t fl[4] = { 0, 1, 0, 1 };
			memcpy(req + 0x18, &one, 4); memcpy(req + 0x1c, &addr, 8); memcpy(req + 0x24, fl, 4); memcpy(req + 0x28, &sz, 4); n = 0x2c; complex = 1;
		}
		else if (!strcmp(t, "ndr")) { static const uint8_t ndr[8] = { 0, 0, 0, 0, 1, 0, 0, 0 }; memcpy(req + n, ndr, 8); n += 8; }
		else if (!strncmp(t, "u32:", 4) || !strncmp(t, "i32:", 4)) { uint32_t v = (uint32_t)strtoll(t + 4, NULL, 0); memcpy(req + n, &v, 4); n += 4; }
		else if (!strncmp(t, "wid:", 4)) { uint32_t v = wid_of(t + 4); memcpy(req + n, &v, 4); n += 4; }
		else if (!strcmp(t, "cid")) { uint32_t v = (uint32_t)cid; memcpy(req + n, &v, 4); n += 4; }
		else if (!strncmp(t, "f32:", 4)) { float v = strtof(t + 4, NULL); memcpy(req + n, &v, 4); n += 4; }
		else if (!strncmp(t, "f64:", 4)) { double v = strtod(t + 4, NULL); memcpy(req + n, &v, 8); n += 8; }
		else if (!strncmp(t, "pad:", 4)) n += (size_t)atoi(t + 4);
		else if (!strncmp(t, "hex:", 4)) { for (const char *s = t + 4; s[0] && s[1]; s += 2) { unsigned v; sscanf(s, "%2x", &v); req[n++] = (uint8_t)v; } }
		else if (!strncmp(t, "str:", 4)) { size_t l = strlen(t + 4); memcpy(req + n, t + 4, l); n += (l + 3) & ~3u; }
	}
	mach_msg_header_t *hd = (mach_msg_header_t *)req;
	mach_port_t reply; mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &reply);
	hd->msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, MACH_MSG_TYPE_MAKE_SEND_ONCE) | (complex ? MACH_MSGH_BITS_COMPLEX : 0);
	hd->msgh_size = (mach_msg_size_t)n; hd->msgh_remote_port = srvport; hd->msgh_local_port = reply; hd->msgh_id = id;
	static uint8_t rep[0x20000]; memset(rep, 0, sizeof rep);
	kern_return_t kr = mach_msg(hd, MACH_SEND_MSG, (mach_msg_size_t)n, 0, MACH_PORT_NULL, 1500, MACH_PORT_NULL);
	if (kr) { printf("raw %d send-error=0x%x\n", id, kr); return; }
	kr = mach_msg((mach_msg_header_t *)rep, MACH_RCV_MSG | MACH_RCV_TIMEOUT, 0, sizeof rep, reply, 1500, MACH_PORT_NULL);
	if (kr) { printf("raw %d recv-error=0x%x\n", id, kr); return; }
	mach_msg_header_t *r = (mach_msg_header_t *)rep;
	printf("raw %d reqsize=%zu -> reply_id=%d bits=%08x size=%u hex=", id, n, r->msgh_id, r->msgh_bits, r->msgh_size);
	for (uint32_t i = 0x18; i < r->msgh_size && i < 0x600; i++) printf("%02x", rep[i]);
	printf("\n");
	mach_port_mod_refs(mach_task_self(), reply, MACH_PORT_RIGHT_RECEIVE, -1);
}

int main(int argc, char **argv)
{
	setvbuf(stdout, NULL, _IONBF, 0);
	dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW);
	dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_NOW);
	int (*mainConn)(void) = dlsym(RTLD_DEFAULT, "SLSMainConnectionID");
	int (*newRect)(const R *, Region *) = dlsym(RTLD_DEFAULT, "CGSNewRegionWithRect");
	int (*newWin)(int, int, float, float, Region, uint32_t *) = dlsym(RTLD_DEFAULT, "SLSNewWindow");
	int (*orderWin)(int, uint32_t, int, uint32_t) = dlsym(RTLD_DEFAULT, "SLSOrderWindow");
	int (*setLevel)(int, uint32_t, int) = dlsym(RTLD_DEFAULT, "SLSSetWindowLevel");
	cid = mainConn();
	mach_port_t (*portbyid)(int) = (mach_port_t (*)(int))strtoull(getenv("PORT_FN") ? getenv("PORT_FN") : "0", NULL, 16);
	srvport = portbyid(cid);
	printf("cid=%d port=%u\n", cid, srvport);
	FILE *f = fopen(argv[1], "r"); char line[4096];
	while (f && fgets(line, sizeof line, f)) {
		line[strcspn(line, "\r\n")] = 0;
		if (!line[0] || line[0] == '#') continue;
		char *tok[64]; int nt = 0;
		for (char *p = strtok(line, " "); p && nt < 64; p = strtok(NULL, " ")) tok[nt++] = p;
		if (!strcmp(tok[0], "new_window") && nt >= 6) {
			R shape = { 0, 0, atof(tok[4]), atof(tok[5]) }; Region r = 0; newRect(&shape, &r);
			uint32_t wid = 0; int e = newWin(cid, 2, (float)atof(tok[2]), (float)atof(tok[3]), r, &wid);
			strncpy(wins[nwins].name, tok[1], 31); wins[nwins++].wid = wid;
			printf("# new_window %s err=%d wid=%u\n", tok[1], e, wid);
		} else if (!strcmp(tok[0], "order") && nt >= 3) {
			int mode = !strcmp(tok[2], "above") ? 1 : !strcmp(tok[2], "below") ? -1 : 0;
			printf("# order %s %s err=%d\n", tok[1], tok[2], orderWin(cid, wid_of(tok[1]), mode, 0));
		} else if (!strcmp(tok[0], "level") && nt >= 3) printf("# level err=%d\n", setLevel(cid, wid_of(tok[1]), atoi(tok[2])));
		else if (!strcmp(tok[0], "port") && nt >= 2) {
			if (!strcmp(tok[1], "conn")) srvport = portbyid(cid);
			else if (!strcmp(tok[1], "server") || !strcmp(tok[1], "event")) {
				const char *cands[] = { "SLSServerPort", "CGSServerPort", "CGSEventServerPort", "SLSEventServerPort", 0 };
				mach_port_t (*fn)(void) = 0; const char *used = "";
				for (int k = 0; cands[k]; k++) { if (!!strcmp(tok[1], "event") != !strstr(cands[k], "Event") && (fn = dlsym(RTLD_DEFAULT, cands[k]))) { used = cands[k]; break; } }
				srvport = fn ? fn() : 0; printf("# port %s via %s = %u\n", tok[1], used, srvport);
			}
			else { mach_port_t p = 0; kern_return_t kr = bootstrap_look_up(bootstrap_port, !strcmp(tok[1], "session") ? "com.apple.windowserver.session" : !strcmp(tok[1], "root") ? "com.apple.windowserver" : "com.apple.windowserver.active", &p); srvport = p; printf("# port %s kr=%d port=%u\n", tok[1], kr, p); }
		}
		else if (!strcmp(tok[0], "raw") && nt >= 2) { printf("# %s\n", tok[0]); raw(atoi(tok[1]), tok + 2, nt - 2); }
	}
	return 0;
}
