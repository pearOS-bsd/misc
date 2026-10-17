#ifndef WSBSD_SECURITY_H
#define WSBSD_SECURITY_H
#if defined(__APPLE__)
#include_next <Security/Security.h>
#else
#include <Security/Authorization.h>
#endif
#endif
