#ifndef PTY_H
#define PTY_H
#include <sys/types.h>
/* Starts the user's shell on a new pseudo terminal. Returns the master descriptor (non-blocking) and the child's pid, -1 on failure. */
int pty_spawn(const char *shell, int cols, int rows, pid_t *pid);
void pty_set_size(int fd, int cols, int rows);
/* The foreground process of the terminal: its name (comm) and, when the system tells, its working directory (empty strings otherwise). */
void pty_foreground(int master, pid_t fallback, char *name, size_t nsize, char *cwd, size_t csize);
#endif
