/* Process information the way Darwin's sysctl and libproc give it, from FreeBSD's. */
#include <sys/types.h>
#include <sys/param.h>
#include <sys/sysctl.h>
#undef sysctl
#undef kinfo_proc
#include <sys/user.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <errno.h>
#include <unistd.h>
#define WSBSD_NO_SYSCTL_REDEF
struct wsbsd_dkinfo_proc;
int wsbsd_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen);

static int real_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) { return sysctl(name, namelen, oldp, oldlenp, newp, newlen); }

int wsbsd_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen)
{
	if (namelen == 4 && name[0] == CTL_KERN && name[1] == KERN_PROC && name[2] == KERN_PROC_PID && oldp && oldlenp && *oldlenp >= 1 && *oldlenp != sizeof(struct kinfo_proc)) {
		/* a Darwin caller: its struct is smaller than FreeBSD's; answer in its layout */
		struct kinfo_proc kp; size_t n = sizeof kp;
		if (real_sysctl(name, namelen, &kp, &n, NULL, 0) != 0 || n == 0) { *oldlenp = 0; return 0; }
		struct { struct { int p_pid; char p_comm[20]; int p_stat; int p_flag; } kp_proc; struct { struct { uid_t cr_uid; short cr_ngroups; gid_t cr_groups[16]; } e_ucred; struct { uid_t p_ruid; gid_t p_rgid; } e_pcred; pid_t e_ppid; pid_t e_pgid; } kp_eproc; } d;
		memset(&d, 0, sizeof d);
		d.kp_proc.p_pid = kp.ki_pid; strlcpy(d.kp_proc.p_comm, kp.ki_comm, sizeof d.kp_proc.p_comm); d.kp_proc.p_stat = kp.ki_stat; d.kp_proc.p_flag = (int)kp.ki_flag;
		d.kp_eproc.e_ucred.cr_uid = kp.ki_uid; d.kp_eproc.e_pcred.p_ruid = kp.ki_ruid; d.kp_eproc.e_pcred.p_rgid = kp.ki_rgid; d.kp_eproc.e_ppid = kp.ki_ppid; d.kp_eproc.e_pgid = kp.ki_pgid;
		size_t m = *oldlenp < sizeof d ? *oldlenp : sizeof d; memcpy(oldp, &d, m); *oldlenp = sizeof d; return 0;
	}
	if (namelen == 3 && name[0] == CTL_KERN && (name[1] == 0x7f01 || name[1] == 0x7f02) && oldp && oldlenp) {
		/* argc, the executable path, padding, then the arguments */
		int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_ARGS, name[2] }; size_t cap = *oldlenp > 8 ? *oldlenp - 8 : 0; char *args = malloc(cap + 1); if (!args) { errno = ENOMEM; return -1; }
		size_t n = cap; if (real_sysctl(mib, 4, args, &n, NULL, 0) != 0) { free(args); return -1; }
		int argc = 0; for (size_t i = 0; i < n; i++) if (args[i] == 0) argc++;
		char path[1024] = ""; int pm[4] = { CTL_KERN, KERN_PROC, KERN_PROC_PATHNAME, name[2] }; size_t pn = sizeof path; if (real_sysctl(pm, 4, path, &pn, NULL, 0) != 0) strlcpy(path, args, sizeof path);
		size_t need = 4 + strlen(path) + 1 + 4 + n; if (need > *oldlenp) need = *oldlenp;
		char *o = oldp; memset(o, 0, need); memcpy(o, &argc, 4); size_t p = 4; size_t pl = strlen(path) + 1; if (p + pl <= need) { memcpy(o + p, path, pl); p += pl; } p += 4;
		if (p < need) memcpy(o + p, args, need - p < n ? need - p : n);
		*oldlenp = need; free(args); return 0;
	}
	return real_sysctl(name, namelen, oldp, oldlenp, newp, newlen);
}

int proc_pidpath(int pid, void *buffer, uint32_t buffersize)
{
	int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_PATHNAME, pid }; size_t n = buffersize;
	if (real_sysctl(mib, 4, buffer, &n, NULL, 0) != 0 || n == 0) return 0;
	return (int)strlen((char *)buffer);
}
int proc_name(int pid, void *buffer, uint32_t buffersize)
{
	int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_PID, pid }; struct kinfo_proc kp; size_t n = sizeof kp;
	if (real_sysctl(mib, 4, &kp, &n, NULL, 0) != 0 || n == 0) return 0;
	strlcpy(buffer, kp.ki_comm, buffersize); return (int)strlen((char *)buffer);
}
int proc_listallpids(void *buffer, int buffersize)
{
	int mib[3] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL }; size_t n = 0;
	if (real_sysctl(mib, 3, NULL, &n, NULL, 0) != 0) return 0;
	struct kinfo_proc *all = malloc(n + 4096); if (!all) return 0; n += 4096;
	if (real_sysctl(mib, 3, all, &n, NULL, 0) != 0) { free(all); return 0; }
	int count = (int)(n / sizeof *all), w = 0; pid_t *out = buffer;
	for (int i = 0; i < count && (size_t)(w + 1) * sizeof(pid_t) <= (size_t)buffersize; i++) out[w++] = all[i].ki_pid;
	free(all); return w * (int)sizeof(pid_t);
}
