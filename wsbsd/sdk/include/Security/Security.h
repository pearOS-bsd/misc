#ifndef WSBSD_SECURITY_H
#define WSBSD_SECURITY_H
#if defined(__APPLE__)
#include_next <Security/Security.h>
#else
#include <Security/Authorization.h>
#include <CoreFoundation/CoreFoundation.h>
/* code signing and keychain results: there is no code signature on this system, every request answers "not available" */
#ifdef __cplusplus
extern "C" {
#endif
typedef int32_t OSStatus_wsbsd_compat;
typedef struct __SecCode *SecCodeRef;
typedef struct __SecStaticCode *SecStaticCodeRef;
typedef uint32_t SecCSFlags;
enum { errSecSuccess = 0, errSecNotAvailable = -25291, errSecItemNotFound = -25300, errSecParam = -50, errSecUnimplemented = -4, errSecAuthFailed = -25293 };
enum { kSecCSDefaultFlags = 0, kSecCSDynamicInformation = 1 << 3, kSecCSSigningInformation = 1 << 1, kSecCSRequirementInformation = 1 << 2 };
extern const CFStringRef kSecCodeInfoEntitlementsDict, kSecCodeInfoEntitlements, kSecCodeInfoIdentifier;
int32_t SecCodeCopySelf(SecCSFlags flags, SecCodeRef *self);
int32_t SecCodeCopySigningInformation(SecCodeRef code, SecCSFlags flags, CFDictionaryRef *information);
#ifdef __cplusplus
}
#endif
#endif
#endif
