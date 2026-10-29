#include <stdio.h>
#include <pwd.h>
#include <sys/types.h>
#include <sys/sysctl.h>
#include <unistd.h>
#ifdef __FreeBSD__
#include <sys/user.h>
#include <libutil.h>
#endif
#ifdef __APPLE__
#include <libproc.h>
#endif
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
		{ const char *cwd = getenv("TERMINAL_CWD"); if (cwd && *cwd) { if (chdir(cwd) == 0) setenv("PWD", cwd, 1); unsetenv("TERMINAL_CWD"); } }       /* a window opened for a folder (Finder: New Terminal at Folder) */
		setenv("TERM", "xterm-256color", 1); setenv("COLORTERM", "truecolor", 1);
		if (!shell || !*shell) { struct passwd *pw = getpwuid(getuid()); if (pw && pw->pw_shell && *pw->pw_shell) shell = pw->pw_shell; }      /* the user's login shell, as the Mac's Terminal does */
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

void pty_foreground(int master, pid_t fallback, char *name, size_t nsize, char *cwd, size_t csize)
{
	name[0] = 0; cwd[0] = 0; pid_t pg = master >= 0 ? tcgetpgrp(master) : -1; if (pg <= 0) pg = fallback; if (pg <= 0) return;
#ifdef __FreeBSD__
	struct kinfo_proc kp; size_t len = sizeof kp; int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_PID, (int)pg };
	if (sysctl(mib, 4, &kp, &len, NULL, 0) == 0 && len) snprintf(name, nsize, "%s", kp.ki_comm);
	int n = 0; struct kinfo_file *kf = kinfo_getfile(pg, &n);
	if (kf) { for (int i = 0; i < n; i++) if (kf[i].kf_fd == KF_FD_TYPE_CWD) { snprintf(cwd, csize, "%s", kf[i].kf_path); break; } free(kf); }
#elif defined(__APPLE__)
	proc_name(pg, name, (uint32_t)nsize);
	struct proc_vnodepathinfo vi; if (proc_pidinfo(pg, PROC_PIDVNODEPATHINFO, 0, &vi, sizeof vi) > 0) snprintf(cwd, csize, "%s", vi.pvi_cdir.vip_path);
#endif
}
