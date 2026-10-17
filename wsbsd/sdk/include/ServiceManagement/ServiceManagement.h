/* <ServiceManagement/ServiceManagement.h> for the wsbsd SDK: privileged helper installation through launchd does not exist; SMJobBless reports failure. */
#ifndef WSBSD_SERVICEMANAGEMENT_H
#define WSBSD_SERVICEMANAGEMENT_H
#if defined(__APPLE__)
#include_next <ServiceManagement/ServiceManagement.h>
#else
#include <CoreFoundation/CoreFoundation.h>
#include <Security/Authorization.h>
#pragma clang arc_cf_code_audited begin
extern CFStringRef kSMDomainSystemLaunchd;
extern CFStringRef kSMDomainUserLaunchd;
extern CFStringRef kSMRightBlessPrivilegedHelper;
extern CFStringRef kSMRightModifySystemDaemons;
Boolean SMJobBless(CFStringRef domain, CFStringRef executableLabel, AuthorizationRef auth, CFErrorRef *outError);
CFDictionaryRef SMJobCopyDictionary(CFStringRef domain, CFStringRef jobLabel);
Boolean SMJobRemove(CFStringRef domain, CFStringRef jobLabel, AuthorizationRef auth, Boolean wait, CFErrorRef *outError);
#pragma clang arc_cf_code_audited end
#endif
#endif
