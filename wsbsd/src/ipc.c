#include "ws_ipc.h"
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>

#ifdef __APPLE__
#define WS_STREAM 1
#define WS_SOCKTYPE SOCK_STREAM
#else
#define WS_STREAM 0
#define WS_SOCKTYPE SOCK_SEQPACKET
#endif

static int addr(const char *path, struct sockaddr_un *sa)
{
	memset(sa, 0, sizeof *sa);
	sa->sun_family = AF_UNIX;
	if (strlen(path) >= sizeof sa->sun_path) return -1;
	strcpy(sa->sun_path, path);
	return 0;
}

int ws_ipc_listen(const char *path)
{
	struct sockaddr_un sa;
	if (addr(path, &sa)) return -1;
	int s = socket(AF_UNIX, WS_SOCKTYPE, 0);
	if (s < 0) return -1;
	unlink(path);
	if (bind(s, (struct sockaddr *)&sa, sizeof sa) < 0 || listen(s, 32) < 0) { close(s); return -1; }
	return s;
}

int ws_ipc_connect(const char *path)
{
	struct sockaddr_un sa;
	if (addr(path, &sa)) return -1;
	int s = socket(AF_UNIX, WS_SOCKTYPE, 0);
	if (s < 0) return -1;
	if (connect(s, (struct sockaddr *)&sa, sizeof sa) < 0) { close(s); return -1; }
	return s;
}

int ws_ipc_send(int sock, const struct iovec *iov, int iovcnt, const int *fds, int nfds)
{
	if (nfds > WS_IPC_MAX_FDS || iovcnt > 7) return -1;
	struct iovec v[8];
	uint32_t total = 0;
	int n = 0;
#if WS_STREAM
	v[n].iov_base = &total; v[n].iov_len = 4; n++;        /* length prefix, filled below */
#endif
	for (int i = 0; i < iovcnt; i++) { v[n++] = iov[i]; total += (uint32_t)iov[i].iov_len; }
	union { struct cmsghdr h; char b[CMSG_SPACE(sizeof(int) * WS_IPC_MAX_FDS)]; } cm;
	struct msghdr m = { .msg_iov = v, .msg_iovlen = n };
	if (nfds > 0) {
		memset(&cm, 0, sizeof cm);
		m.msg_control = cm.b; m.msg_controllen = CMSG_SPACE(sizeof(int) * (size_t)nfds);
		struct cmsghdr *c = CMSG_FIRSTHDR(&m);
		c->cmsg_level = SOL_SOCKET; c->cmsg_type = SCM_RIGHTS; c->cmsg_len = CMSG_LEN(sizeof(int) * (size_t)nfds);
		memcpy(CMSG_DATA(c), fds, sizeof(int) * (size_t)nfds);
	}
#if WS_STREAM
	/* a stream may accept only part of the buffer: send the prefix and first bytes with the fds, then the rest */
	size_t want = 4 + total, done = 0;
	while (done < want) {
		ssize_t r = sendmsg(sock, &m, 0);
		if (r < 0) { if (errno == EINTR) continue; return -1; }
		done += (size_t)r;
		if (done >= want) break;
		size_t skip = (size_t)r;                        /* advance the iovecs, drop the control data */
		m.msg_control = NULL; m.msg_controllen = 0;
		while (skip && m.msg_iovlen) {
			if (skip >= m.msg_iov->iov_len) { skip -= m.msg_iov->iov_len; m.msg_iov++; m.msg_iovlen--; }
			else { m.msg_iov->iov_base = (char *)m.msg_iov->iov_base + skip; m.msg_iov->iov_len -= skip; skip = 0; }
		}
	}
	return 0;
#else
	ssize_t r;
	do r = sendmsg(sock, &m, 0); while (r < 0 && errno == EINTR);
	return r == (ssize_t)total ? 0 : -1;
#endif
}

ssize_t ws_ipc_recv(int sock, void *buf, size_t cap, int *fds, int *nfds)
{
	union { struct cmsghdr h; char b[CMSG_SPACE(sizeof(int) * WS_IPC_MAX_FDS)]; } cm;
	*nfds = 0;
#if WS_STREAM
	uint32_t len = 0;
	struct iovec iv = { &len, 4 };
	struct msghdr m = { .msg_iov = &iv, .msg_iovlen = 1, .msg_control = cm.b, .msg_controllen = sizeof cm.b };
	ssize_t r;
	do r = recvmsg(sock, &m, 0); while (r < 0 && errno == EINTR);
	if (r <= 0) return r;
	for (struct cmsghdr *c = CMSG_FIRSTHDR(&m); c; c = CMSG_NXTHDR(&m, c))
		if (c->cmsg_level == SOL_SOCKET && c->cmsg_type == SCM_RIGHTS) {
			int k = (int)((c->cmsg_len - CMSG_LEN(0)) / sizeof(int));
			if (k > WS_IPC_MAX_FDS) k = WS_IPC_MAX_FDS;
			memcpy(fds, CMSG_DATA(c), sizeof(int) * (size_t)k); *nfds = k;
		}
	size_t got = (size_t)r;
	while (got < 4) { ssize_t q = read(sock, (char *)&len + got, 4 - got); if (q <= 0) return -1; got += (size_t)q; }
	if (len > cap) return -1;
	size_t have = 0;
	while (have < len) { ssize_t q = read(sock, (char *)buf + have, len - have); if (q <= 0) { if (q < 0 && errno == EINTR) continue; return -1; } have += (size_t)q; }
	return (ssize_t)len;
#else
	struct iovec iv = { buf, cap };
	struct msghdr m = { .msg_iov = &iv, .msg_iovlen = 1, .msg_control = cm.b, .msg_controllen = sizeof cm.b };
	ssize_t r;
	do r = recvmsg(sock, &m, 0); while (r < 0 && errno == EINTR);
	if (r <= 0) return r;
	if (m.msg_flags & (MSG_TRUNC | MSG_CTRUNC)) return -1;
	for (struct cmsghdr *c = CMSG_FIRSTHDR(&m); c; c = CMSG_NXTHDR(&m, c))
		if (c->cmsg_level == SOL_SOCKET && c->cmsg_type == SCM_RIGHTS) {
			int k = (int)((c->cmsg_len - CMSG_LEN(0)) / sizeof(int));
			if (k > WS_IPC_MAX_FDS) k = WS_IPC_MAX_FDS;
			memcpy(fds, CMSG_DATA(c), sizeof(int) * (size_t)k); *nfds = k;
		}
	return r;
#endif
}

int ws_ipc_socketpair(int sv[2]) { return socketpair(AF_UNIX, WS_SOCKTYPE, 0, sv); }
