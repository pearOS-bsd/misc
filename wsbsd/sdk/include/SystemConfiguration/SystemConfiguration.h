#ifndef WSBSD_SYSTEMCONFIGURATION_H
#define WSBSD_SYSTEMCONFIGURATION_H
#include <CoreFoundation/CoreFoundation.h>
#include <CFNetwork/CFNetwork.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct __SCDynamicStore *SCDynamicStoreRef;
CFDictionaryRef SCDynamicStoreCopyProxies(SCDynamicStoreRef store);     /* the proxies of the environment, see CFNetwork.h */
#ifdef __cplusplus
}
#endif
#endif
