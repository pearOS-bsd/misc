/* <sys/sysctl.h>: FreeBSD's, plus the Darwin spellings applications use for process information: KERN_PROCARGS, a kinfo_proc with kp_proc / kp_eproc, answered by wsbsd_sysctl (sdk/src/ProcCompat.c) */
#ifndef WSBSD_SYSCTL_H
#define WSBSD_SYSCTL_H
#include_next <sys/sysctl.h>
#if defined(__FreeBSD__)
#include <sys/types.h>
#include <sys/param.h>
#include <sys/user.h>
#ifdef __cplusplus
extern "C" {
#endif
#define KERN_PROCARGS 0x7f01            /* Darwin: {CTL_KERN, KERN_PROCARGS, pid}: argc, executable path, the arguments */
#define KERN_PROCARGS2 0x7f02
struct wsbsd_dkinfo_proc {
	struct { int p_pid; char p_comm[20]; int p_stat; int p_flag; } kp_proc;
	struct { struct { uid_t cr_uid; short cr_ngroups; gid_t cr_groups[16]; } e_ucred; struct { uid_t p_ruid; gid_t p_rgid; } e_pcred; pid_t e_ppid; pid_t e_pgid; } kp_eproc;
};
#define kinfo_proc wsbsd_dkinfo_proc
int wsbsd_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen);
#define sysctl wsbsd_sysctl
#ifdef __cplusplus
}
#endif
#endif
#endif
