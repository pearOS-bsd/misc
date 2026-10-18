/* libproc of Darwin: process names and paths by pid, from FreeBSD's sysctl */
#ifndef WSBSD_LIBPROC_H
#define WSBSD_LIBPROC_H
#include <sys/types.h>
#ifdef __cplusplus
extern "C" {
#endif
#define PROC_PIDPATHINFO_MAXSIZE 4096
int proc_name(int pid, void *buffer, uint32_t buffersize);
int proc_pidpath(int pid, void *buffer, uint32_t buffersize);
int proc_listallpids(void *buffer, int buffersize);
#ifdef __cplusplus
}
#endif
#endif
