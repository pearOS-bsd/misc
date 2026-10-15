#include "pty.h"
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <termios.h>
#ifdef __APPLE__
#include <util.h>
#else
#include <libutil.h>
#endif

void pty_set_size(int fd, int cols, int rows)
{
	struct winsize ws; memset(&ws, 0, sizeof ws); ws.ws_col = (unsigned short)cols; ws.ws_row = (unsigned short)rows;
	ioctl(fd, TIOCSWINSZ, &ws);
}

int pty_spawn(const char *shell, int cols, int rows, pid_t *pid)
{
	struct winsize ws; memset(&ws, 0, sizeof ws); ws.ws_col = (unsigned short)cols; ws.ws_row = (unsigned short)rows;
	int master;
	pid_t p = forkpty(&master, NULL, NULL, &ws);
	if (p < 0) return -1;
	if (p == 0) {
		setenv("TERM", "xterm-256color", 1); setenv("COLORTERM", "truecolor", 1);
		if (!shell || !*shell) shell = getenv("SHELL");
		if (!shell || !*shell) shell = "/bin/sh";
		const char *base = strrchr(shell, '/'); base = base ? base + 1 : shell;
		char arg0[128]; snprintf(arg0, sizeof arg0, "-%s", base);          /* a login shell */
		execl(shell, arg0, (char *)NULL);
		_exit(127);
	}
	fcntl(master, F_SETFL, fcntl(master, F_GETFL) | O_NONBLOCK);
	*pid = p;
	return master;
}
