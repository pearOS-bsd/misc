/* copyfile(3): data, mode and times of a file, a symbolic link, or a whole directory tree with COPYFILE_RECURSIVE (extended attributes and ACLs are not copied). */
#include <copyfile.h>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <unistd.h>

struct _copyfile_state { int unused; };
copyfile_state_t copyfile_state_alloc(void) { return calloc(1, sizeof(struct _copyfile_state)); }
int copyfile_state_free(copyfile_state_t s) { free(s); return 0; }

static int copy_fd(int in, int out)
{
	char buf[65536]; ssize_t n;
	while ((n = read(in, buf, sizeof buf)) > 0) { for (ssize_t off = 0; off < n;) { ssize_t w = write(out, buf + off, (size_t)(n - off)); if (w < 0) return -1; off += w; } }
	return n < 0 ? -1 : 0;
}
int fcopyfile(int from_fd, int to_fd, copyfile_state_t state, copyfile_flags_t flags)
{
	(void)state;
	if ((flags & COPYFILE_DATA) && copy_fd(from_fd, to_fd)) return -1;
	if (flags & COPYFILE_STAT) { struct stat st; if (fstat(from_fd, &st) == 0) fchmod(to_fd, st.st_mode & 07777); }
	return 0;
}
static int copy_one(const char *from, const char *to, copyfile_flags_t flags)
{
	struct stat st;
	if ((flags & COPYFILE_NOFOLLOW_SRC ? lstat(from, &st) : stat(from, &st)) != 0) return -1;
	if (S_ISLNK(st.st_mode)) {
		char target[PATH_MAX]; ssize_t n = readlink(from, target, sizeof target - 1); if (n < 0) return -1; target[n] = 0;
		if (flags & COPYFILE_EXCL) { if (symlink(target, to)) return -1; return 0; }
		unlink(to); return symlink(target, to);
	}
	if (S_ISDIR(st.st_mode)) {
		if (!(flags & COPYFILE_RECURSIVE)) { errno = EISDIR; return -1; }
		if (mkdir(to, (st.st_mode & 0777) | 0700) && errno != EEXIST) return -1;
		DIR *d = opendir(from); if (!d) return -1; struct dirent *e; int rc = 0;
		while ((e = readdir(d))) {
			if (!strcmp(e->d_name, ".") || !strcmp(e->d_name, "..")) continue;
			char a[PATH_MAX], b[PATH_MAX];
			if (snprintf(a, sizeof a, "%s/%s", from, e->d_name) >= (int)sizeof a || snprintf(b, sizeof b, "%s/%s", to, e->d_name) >= (int)sizeof b) { rc = -1; errno = ENAMETOOLONG; break; }
			if (copy_one(a, b, flags)) { rc = -1; break; }
		}
		closedir(d);
		if (rc == 0 && (flags & COPYFILE_STAT)) chmod(to, st.st_mode & 07777);
		return rc;
	}
	int in = open(from, O_RDONLY); if (in < 0) return -1;
	int out = open(to, O_WRONLY | O_CREAT | ((flags & COPYFILE_EXCL) ? O_EXCL : O_TRUNC), (st.st_mode & 0777) | 0200); if (out < 0) { int e = errno; close(in); errno = e; return -1; }
	int rc = (flags & COPYFILE_DATA) ? copy_fd(in, out) : 0;
	if (rc == 0 && (flags & COPYFILE_STAT)) { fchmod(out, st.st_mode & 07777); struct timeval tv[2] = { { st.st_atime, 0 }, { st.st_mtime, 0 } }; futimes(out, tv); }
	int e = errno; close(in); if (close(out) && rc == 0) { rc = -1; e = errno; }
	if (rc) errno = e;
	return rc;
}
int copyfile(const char *from, const char *to, copyfile_state_t state, copyfile_flags_t flags)
{
	(void)state;
	if (flags & COPYFILE_CHECK) return flags & (COPYFILE_XATTR | COPYFILE_ACL);
	int rc = copy_one(from, to, flags);
	if (rc == 0 && (flags & COPYFILE_MOVE)) { /* the caller asked for a move: the source goes */ struct stat st; if (lstat(from, &st) == 0 && !S_ISDIR(st.st_mode)) unlink(from); }
	return rc;
}
