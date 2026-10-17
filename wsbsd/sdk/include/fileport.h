/* <fileport.h> for the wsbsd SDK: file descriptors as Mach ports do not exist here. */
#ifndef WSBSD_FILEPORT_H
#define WSBSD_FILEPORT_H
#include <mach/mach.h>
typedef mach_port_t fileport_t;
static inline int fileport_makeport(int fd, fileport_t *p) { (void)fd; if (p) *p = MACH_PORT_NULL; return -1; }
static inline int fileport_makefd(fileport_t p) { (void)p; return -1; }
#endif
