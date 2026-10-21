/* <crt_externs.h>: the process environment of Darwin */
#ifndef WSBSD_CRT_EXTERNS_H
#define WSBSD_CRT_EXTERNS_H
extern char **environ;
static inline char ***_NSGetEnviron(void) { return &environ; }
#endif
