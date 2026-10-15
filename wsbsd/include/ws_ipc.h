/* Message transport: one datagram per Mach-style message, file descriptors via SCM_RIGHTS, zero allocation.
 * FreeBSD: AF_UNIX SOCK_SEQPACKET. macOS (test builds only): SOCK_STREAM with a 4-byte length prefix. */
#ifndef WS_IPC_H
#define WS_IPC_H
#include <stddef.h>
#include <sys/types.h>
#include <sys/uio.h>

#define WS_IPC_MAX_FDS 4
#define WS_IPC_RECV_CAP (0x12060 + 0x40000)     /* subsystem max message + room for out-of-line payloads */

const char *ws_default_socket_path(void);                    /* $XDG_RUNTIME_DIR/wsd.sock or /tmp/wsd-<uid>.sock */
int ws_ipc_listen(const char *path);
int ws_ipc_connect(const char *path);
/* Sends iov as one message; fds (nfds <= WS_IPC_MAX_FDS) ride along. Returns 0 or -1. */
int ws_ipc_send(int sock, const struct iovec *iov, int iovcnt, const int *fds, int nfds);
/* Receives one message into buf (cap bytes). Returns its length, 0 on orderly close, -1 on error / would block (errno set).
 * Received descriptors are returned in fds, their count in *nfds. */
ssize_t ws_ipc_recv(int sock, void *buf, size_t cap, int *fds, int *nfds);
/* A connected pair of message sockets of the transport type (used for the per-connection event channel). */
int ws_ipc_socketpair(int sv[2]);
#endif
