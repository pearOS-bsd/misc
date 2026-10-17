/* <CoreServices/CoreServices.h> for the wsbsd SDK: Apple's Cocoa umbrella reaches it; here it carries the pieces portable sources use. */
#ifndef WSBSD_CORESERVICES_H
#define WSBSD_CORESERVICES_H
#if defined(__APPLE__)
#include_next <CoreServices/CoreServices.h>
#else
#include <CoreServices/FSEvents.h>
#include <stdint.h>
typedef int32_t OSStatus;
typedef uint32_t OSType;
typedef int16_t OSErr;
struct UTCDateTime;
#include <CoreFoundation/CoreFoundation.h>
#pragma clang arc_cf_code_audited begin
#ifdef __cplusplus
extern "C" {
#endif
/* seconds since 1 Jan 1904 (the classic Mac epoch) to CFAbsoluteTime (1 Jan 2001) and back */
int32_t UCConvertSecondsToCFAbsoluteTime(uint32_t seconds, CFAbsoluteTime *absoluteTime);
int32_t UCConvertCFAbsoluteTimeToSeconds(CFAbsoluteTime absoluteTime, uint32_t *seconds);
Boolean UTTypeEqual(CFStringRef inUTI1, CFStringRef inUTI2);
CFDictionaryRef UTTypeCopyDeclaration(CFStringRef inUTI);
OSStatus UCConvertUTCDateTimeToCFAbsoluteTime(const struct UTCDateTime *iUTCDate, CFAbsoluteTime *oCFTime);
OSStatus UCConvertCFAbsoluteTimeToUTCDateTime(CFAbsoluteTime iCFTime, struct UTCDateTime *oUTCDate);
Boolean UTTypeConformsTo(CFStringRef inUTI, CFStringRef inConformsToUTI);
CFStringRef UTTypeCopyPreferredTagWithClass(CFStringRef inUTI, CFStringRef inTagClass);
CFStringRef UTTypeCreatePreferredIdentifierForTag(CFStringRef inTagClass, CFStringRef inTag, CFStringRef inConformingToUTI);
CFStringRef UTTypeCopyDescription(CFStringRef inUTI);
extern const CFStringRef kUTTypeDescriptionKey, kUTTypeConformsToKey, kUTTypeIdentifierKey, kUTTypeTagSpecificationKey;
extern const CFStringRef kUTTagClassFilenameExtension;
extern const CFStringRef kUTTagClassMIMEType;
extern const CFStringRef kUTTypeData, kUTTypeItem, kUTTypeContent, kUTTypePlainText, kUTTypeText, kUTTypeApplicationBundle, kUTTypeFolder, kUTTypeDirectory, kUTTypeBundle;
#ifdef __cplusplus
}
#endif
#pragma clang arc_cf_code_audited end
enum { noErr = 0, userCanceledErr = -128, fnfErr = -43, paramErr = -50, permErr = -54 };
#include <CoreServices/FileManager.h>
#endif
#endif
