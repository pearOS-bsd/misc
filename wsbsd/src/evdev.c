/* evdev input for the FreeBSD display backends (DRM/KMS and the framebuffer): raw evdev; relative pointer motion is accumulated into an absolute position (tablets give absolute
 * positions), key codes are passed through as evdev codes. */
#ifdef WS_KMS
#include "ws_backend.h"
#include "ws_input.h"
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <dev/evdev/input.h>
/* ---- evdev ---- */
#define MAXDEV 16
struct ws_evdev { int n, fd[MAXDEV]; ws_input in; int in_init; int abs[MAXDEV][2][2]; int has_abs[MAXDEV]; };

ws_evdev *ws_evdev_open(const char *dir)
{
	ws_evdev *e = calloc(1, sizeof *e);
	DIR *d = e ? opendir(dir) : NULL;
	if (!d) { free(e); return NULL; }
	struct dirent *de;
	while ((de = readdir(d)) && e->n < MAXDEV) {
		if (strncmp(de->d_name, "event", 5)) continue;
		char path[512];
		snprintf(path, sizeof path, "%s/%s", dir, de->d_name);
		int fd = open(path, O_RDONLY | O_NONBLOCK | O_CLOEXEC);
		if (fd >= 0) {
			struct input_absinfo ax, ay;                          /* a device with absolute axes (tablet, touch screen) reports positions in its own range */
			if (ioctl(fd, EVIOCGABS(ABS_X), &ax) == 0 && ioctl(fd, EVIOCGABS(ABS_Y), &ay) == 0 && ax.maximum > ax.minimum && ay.maximum > ay.minimum) {
				e->has_abs[e->n] = 1; e->abs[e->n][0][0] = ax.minimum; e->abs[e->n][0][1] = ax.maximum; e->abs[e->n][1][0] = ay.minimum; e->abs[e->n][1][1] = ay.maximum;
			}
			e->fd[e->n++] = fd;
		}
	}
	closedir(d);
	return e;
}

int ws_evdev_count(ws_evdev *e) { return e->n; }
int ws_evdev_fd(ws_evdev *e, int i) { return e->fd[i]; }

/* reads and drops everything pending on an input device (used while another VT is active) */
int ws_evdev_drain(ws_evdev *e, int i)
{
	struct input_event ev[64];
	for (;;) { ssize_t n = read(e->fd[i], ev, sizeof ev); if (n < 0) return errno == EAGAIN ? 0 : -1; if (n == 0) return -1; }
}


int ws_evdev_dispatch(ws_evdev *e, int i, ws_server *srv, int sw, int sh)
{
	struct input_event ev[64];
	if (!e->in_init) { ws_input_init(&e->in, sw, sh); e->in_init = 1; }
	for (;;) {
		ssize_t n = read(e->fd[i], ev, sizeof ev);
		if (n < 0) return errno == EAGAIN ? 0 : -1;
		if (n == 0) return -1;
		for (size_t j = 0; j < (size_t)n / sizeof ev[0]; j++) {
			if (ev[j].type == EV_ABS && e->has_abs[i]) { ws_input_set_abs_range(&e->in, 0, e->abs[i][0][0], e->abs[i][0][1]); ws_input_set_abs_range(&e->in, 1, e->abs[i][1][0], e->abs[i][1][1]); }
			ws_input_feed(&e->in, srv, ev[j].type, ev[j].code, ev[j].value);       /* EV_SYN / EV_KEY / EV_REL / EV_ABS share the numbers of ws_input.h */
		}
	}
}

void ws_evdev_close(ws_evdev *e)
{
	if (!e) return;
	for (int i = 0; i < e->n; i++) close(e->fd[i]);
	free(e);
}
#endif
