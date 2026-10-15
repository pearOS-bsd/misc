/* Capsicum sandbox (FreeBSD): once the listening socket, the event queue and the display / input devices are open, wsd enters capability mode: no new file or path can be opened, no
 * new sockets created by name, nothing outside the descriptors it already holds can be touched. Clients still connect (accept is allowed), shared memory is created with SHM_ANON. */
#include "wsd_priv.h"
#include <stdio.h>
#ifdef __FreeBSD__
#include <sys/capsicum.h>
#include <errno.h>
#include <string.h>
#endif

/* returns 0 when the process is sandboxed, -1 when this system has no Capsicum (or entering failed) */
int wsd_sandbox_enter(int listen_fd, int kq)
{
#ifdef __FreeBSD__
	cap_rights_t r;
	cap_rights_init(&r, CAP_ACCEPT, CAP_EVENT, CAP_FSTAT, CAP_GETSOCKOPT, CAP_SETSOCKOPT, CAP_FCNTL, CAP_READ, CAP_WRITE, CAP_RECV, CAP_SEND, CAP_GETPEERNAME, CAP_GETSOCKNAME, CAP_SHUTDOWN);
	if (cap_rights_limit(listen_fd, &r) < 0) { fprintf(stderr, "wsd: cap_rights_limit(listen): %s\n", strerror(errno)); return -1; }
	cap_rights_t k; cap_rights_init(&k, CAP_EVENT, CAP_KQUEUE_CHANGE, CAP_KQUEUE_EVENT, CAP_FSTAT);
	if (cap_rights_limit(kq, &k) < 0) { fprintf(stderr, "wsd: cap_rights_limit(kqueue): %s\n", strerror(errno)); return -1; }
	if (cap_enter() < 0) { fprintf(stderr, "wsd: cap_enter: %s\n", strerror(errno)); return -1; }
	return 0;
#else
	(void)listen_fd; (void)kq;
	fprintf(stderr, "wsd: -S: this system has no Capsicum, running unsandboxed\n");
	return -1;
#endif
}
