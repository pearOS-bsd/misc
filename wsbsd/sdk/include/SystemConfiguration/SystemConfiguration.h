#ifndef WSBSD_SYSTEMCONFIGURATION_H
#define WSBSD_SYSTEMCONFIGURATION_H
#include <CoreFoundation/CoreFoundation.h>
#include <CFNetwork/CFNetwork.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct __SCDynamicStore *SCDynamicStoreRef;
typedef const struct __SCNetworkReachability *SCNetworkReachabilityRef;
typedef uint32_t SCNetworkReachabilityFlags;
enum { kSCNetworkReachabilityFlagsTransientConnection = 1 << 0, kSCNetworkReachabilityFlagsReachable = 1 << 1, kSCNetworkReachabilityFlagsConnectionRequired = 1 << 2, kSCNetworkReachabilityFlagsIsDirect = 1 << 17 };
SCNetworkReachabilityRef SCNetworkReachabilityCreateWithName(CFAllocatorRef allocator, const char *nodename);
SCNetworkReachabilityRef SCNetworkReachabilityCreateWithAddress(CFAllocatorRef allocator, const void *address);
Boolean SCNetworkReachabilityGetFlags(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags *flags);
CFDictionaryRef SCDynamicStoreCopyProxies(SCDynamicStoreRef store);     /* the proxies of the environment, see CFNetwork.h */
#ifdef __cplusplus
}
#endif
#endif
