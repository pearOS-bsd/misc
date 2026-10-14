/* lab probe: sends raw SkyLight requests to the REAL WindowServer over this process's connection port and prints the raw replies (golden vectors).
 *   mach_probe LIST      each line "<id> <hex body after the 0x18 header>" (the name column after a '#'-less space is ignored when it is not hex)
 *   mach_probe --one ID [HEX]
 * One process per request (a request that hangs or kills the connection only costs that process). Needs the private connection-port lookup, whose
 * address is resolved through lldb on this machine. */
#include <dlfcn.h>
#include <mach/mach.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <sys/wait.h>
#include <unistd.h>

static uintptr_t resolve(const char *sym, uintptr_t main_rt, uintptr_t main_file)
{
	char cmd[400], line[400]; uintptr_t addr = 0;
	snprintf(cmd, sizeof cmd, "sudo lldb -b -p %d -o 'image lookup -n %s' -o detach 2>&1 | grep -m1 'Address: SkyLight'", getppid() ? (int)getpid() : 0, sym);
	FILE *p = popen(cmd, "r");
	if (p && fgets(line, sizeof line, p)) { char *q = strstr(line, "SkyLight[0x"); if (q) { uintptr_t f = strtoull(q + 10, NULL, 16); addr = main_rt - main_file + f; } }
	if (p) pclose(p);
	return addr;
}

static int one(int id, const char *hex)
{
	void *h = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW);
	int (*mainconn)(void) = dlsym(h, "SLSMainConnectionID");
	int cid = mainconn();
	uintptr_t port_fn_addr = strtoull(getenv("PORT_FN") ? getenv("PORT_FN") : "0", NULL, 16);
	mach_port_t (*portbyid)(int) = (mach_port_t (*)(int))port_fn_addr;
	mach_port_t srv = portbyid(cid);
	if (!srv) { printf("id=%d no-connection-port\n", id); return 1; }
	uint8_t req[0x400]; memset(req, 0, sizeof req);
	size_t n = 0x18;
	for (const char *s = hex; s && s[0] && s[1] && n < sizeof req; s += 2) { unsigned v; if (sscanf(s, "%2x", &v) != 1) break; req[n++] = (uint8_t)v; }
	mach_msg_header_t *hd = (mach_msg_header_t *)req;
	mach_port_t reply; mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &reply);
	hd->msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, MACH_MSG_TYPE_MAKE_SEND_ONCE);
	hd->msgh_size = (mach_msg_size_t)n; hd->msgh_remote_port = srv; hd->msgh_local_port = reply; hd->msgh_id = id;
	uint8_t rep[0x20000]; memset(rep, 0, sizeof rep);
	kern_return_t kr = mach_msg((mach_msg_header_t *)req, MACH_SEND_MSG, (mach_msg_size_t)n, 0, MACH_PORT_NULL, 3000, MACH_PORT_NULL);
	if (kr) { printf("id=%d send-error=0x%x\n", id, kr); return 1; }
	kr = mach_msg((mach_msg_header_t *)rep, MACH_RCV_MSG | MACH_RCV_TIMEOUT, 0, sizeof rep, reply, 3000, MACH_PORT_NULL);
	if (kr) { printf("id=%d recv-error=0x%x\n", id, kr); return 1; }
	mach_msg_header_t *r = (mach_msg_header_t *)rep;
	printf("id=%d reqsize=%zu reply_id=%d bits=%08x size=%u hex=", id, n, r->msgh_id, r->msgh_bits, r->msgh_size);
	for (uint32_t i = 0x18; i < r->msgh_size && i < 0x400; i++) printf("%02x", rep[i]);
	printf("\n");
	return 0;
}

int main(int argc, char **argv)
{
	setvbuf(stdout, NULL, _IONBF, 0);
	if (argc >= 3 && !strcmp(argv[1], "--one")) return one(atoi(argv[2]), argc > 3 ? argv[3] : "");
	/* parent: resolve the private lookup through lldb, then one child per request */
	void *h = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW);
	uintptr_t mainrt = (uintptr_t)dlsym(h, "SLSMainConnectionID");
	char cmd[400], line[400]; uintptr_t mainfile = 0, portfile = 0;
	snprintf(cmd, sizeof cmd, "sudo lldb -b -p %d -o 'image lookup -n SLSMainConnectionID' -o 'image lookup -r -n CGSGetConnectionPortById' -o detach > /tmp/lldb_resolve.txt 2>&1", (int)getpid());
	system(cmd);                                   /* attaching interrupts blocking reads of this process, so the output goes through a file */
	FILE *p = fopen("/tmp/lldb_resolve.txt", "r"); int k = 0;
	while (p && fgets(line, sizeof line, p)) { char *q = strstr(line, "Address: SkyLight[0x"); if (q) { unsigned long v = strtoull(q + 20, NULL, 16); if (k++ == 0) mainfile = v; else portfile = v; } }
	if (p) fclose(p);
	if (!mainfile || !portfile) { printf("cannot resolve symbols (%lx %lx)\n", (unsigned long)mainfile, (unsigned long)portfile); system("cat /tmp/lldb_resolve.txt | head -30"); return 1; }
	char env[64]; snprintf(env, sizeof env, "%lx", (unsigned long)(mainrt - mainfile + portfile)); setenv("PORT_FN", env, 1);
	FILE *f = fopen(argv[1], "r"); char buf[2048];
	while (f && fgets(buf, sizeof buf, f)) {
		int id; char hex[1900] = "", w[64];
		if (sscanf(buf, "%d %63s", &id, w) < 1) continue;
		if (sscanf(buf, "%*d %1899s", hex) == 1 && strspn(hex, "0123456789abcdefABCDEF") != strlen(hex)) hex[0] = 0;   /* a name, not a body */
		pid_t pid = fork();
		if (!pid) { alarm(6); char ids[16]; snprintf(ids, sizeof ids, "%d", id); execl(argv[0], argv[0], "--one", ids, hex, (char *)0); _exit(1); }
		int st; waitpid(pid, &st, 0);
		if (WIFSIGNALED(st)) printf("id=%d child-signal=%d\n", id, WTERMSIG(st));
	}
	return 0;
}
