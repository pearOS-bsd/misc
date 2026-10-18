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
#include <sys/stat.h>
#include <dev/evdev/input.h>
/* ---- evdev ---- */
#define MAXDEV 16
struct ws_evdev { int n, fd[MAXDEV]; dev_t rdev[MAXDEV]; char dir[256]; ws_input in; int in_init; int abs[MAXDEV][2][2]; int has_abs[MAXDEV]; };

static int add_device(ws_evdev *e, const char *path)
{
	struct stat st; if (stat(path, &st) < 0) return -1;
	for (int i = 0; i < e->n; i++) if (e->fd[i] >= 0 && e->rdev[i] == st.st_rdev) return -1;       /* already open */
	int fd = open(path, O_RDONLY | O_NONBLOCK | O_CLOEXEC); if (fd < 0) return -1;
	int slot = -1; for (int i = 0; i < e->n; i++) if (e->fd[i] < 0) { slot = i; break; }
	if (slot < 0) { if (e->n >= MAXDEV) { close(fd); return -1; } slot = e->n++; }
	struct input_absinfo ax, ay; e->has_abs[slot] = 0;                  /* a device with absolute axes (tablet, touch screen) reports positions in its own range */
	if (ioctl(fd, EVIOCGABS(ABS_X), &ax) == 0 && ioctl(fd, EVIOCGABS(ABS_Y), &ay) == 0 && ax.maximum > ax.minimum && ay.maximum > ay.minimum) {
		e->has_abs[slot] = 1; e->abs[slot][0][0] = ax.minimum; e->abs[slot][0][1] = ax.maximum; e->abs[slot][1][0] = ay.minimum; e->abs[slot][1][1] = ay.maximum;
	}
	e->fd[slot] = fd; e->rdev[slot] = st.st_rdev; return slot;
}

int ws_evdev_rescan(ws_evdev *e)
{
	DIR *d = opendir(e->dir); if (!d) return -1;
	struct dirent *de; int first = -1;
	while ((de = readdir(d))) {
		if (strncmp(de->d_name, "event", 5)) continue;
		char path[512]; snprintf(path, sizeof path, "%s/%s", e->dir, de->d_name);
		int s = add_device(e, path); if (s >= 0 && (first < 0 || s < first)) first = s;
	}
	closedir(d); return first;
}

ws_evdev *ws_evdev_open(const char *dir)
{
	ws_evdev *e = calloc(1, sizeof *e);
	if (!e) return NULL;
	snprintf(e->dir, sizeof e->dir, "%s", dir);
	DIR *d = opendir(dir);
	if (!d) { free(e); return NULL; }
	closedir(d);
	for (int i = 0; i < MAXDEV; i++) e->fd[i] = -1;
	ws_evdev_rescan(e);
	return e;
}

int ws_evdev_count(ws_evdev *e) { return e->n; }
void ws_evdev_forget(ws_evdev *e, int i) { if (i >= 0 && i < e->n && e->fd[i] >= 0) { close(e->fd[i]); e->fd[i] = -1; e->rdev[i] = 0; } }
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
	for (int i = 0; i < e->n; i++) if (e->fd[i] >= 0) close(e->fd[i]);
	free(e);
}
#endif
