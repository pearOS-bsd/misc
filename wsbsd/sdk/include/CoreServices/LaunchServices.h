/* Launch Services: opening URLs with their default applications goes through NSWorkspace (sdk/src/AppKitCompat2.m); there are no HFS type and creator codes, so an item's info has none */
#ifndef WSBSD_LAUNCHSERVICES_H
#define WSBSD_LAUNCHSERVICES_H
#include <stdint.h>
#include <CoreFoundation/CoreFoundation.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef uint32_t LSRequestedInfo, LSItemInfoFlags;      /* LSRolesMask and the roles are in CoreServices.h */
enum { kLSRequestExtension = 1, kLSRequestTypeCreator = 4, kLSRequestAllInfo = 0xFFFFFFFFu };
typedef struct { LSItemInfoFlags flags; uint32_t filetype; uint32_t creator; CFStringRef extension; } LSItemInfoRecord;
enum { kClippingTextType = 0x63706c74 };
int32_t LSOpenURLsWithRole(CFArrayRef inURLs, LSRolesMask inRole, const void *inAEParam, const void *inAppParams, CFArrayRef *outLaunchedURLs, CFIndex inMaxLaunchedURLs);
int32_t LSCopyItemInfoForURL(CFURLRef inURL, LSRequestedInfo inWhichInfo, LSItemInfoRecord *outItemInfo);
#ifdef __cplusplus
}
#endif
#endif
