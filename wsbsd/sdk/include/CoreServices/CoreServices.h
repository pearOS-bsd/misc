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
extern const CFStringRef kUTTypeRTF, kUTTypeHTML, kUTTypeXML, kUTTypeImage, kUTTypePNG, kUTTypeJPEG, kUTTypeGIF, kUTTypeTIFF, kUTTypePDF, kUTTypeSourceCode, kUTTypeUTF8PlainText, kUTTypeURL, kUTTypeData, kUTTypeItem, kUTTypeContent, kUTTypePlainText, kUTTypeText, kUTTypeApplicationBundle, kUTTypeFolder, kUTTypeDirectory, kUTTypeBundle;
/* Launch Services: no application database; the lookups find nothing */
typedef uint32_t LSRolesMask;
enum { kLSRolesNone = 1, kLSRolesViewer = 2, kLSRolesEditor = 4, kLSRolesShell = 8, kLSRolesAll = (int)0xFFFFFFFF };
CFArrayRef LSCopyApplicationURLsForURL(CFURLRef inURL, LSRolesMask inRoleMask);
CFURLRef LSCopyDefaultApplicationURLForURL(CFURLRef inURL, LSRolesMask inRoleMask, CFErrorRef *outError);
/* Spotlight metadata items: no index, no item */
typedef struct __MDItem *MDItemRef;
MDItemRef MDItemCreateWithURL(CFAllocatorRef allocator, CFURLRef url);
MDItemRef MDItemCreate(CFAllocatorRef allocator, CFStringRef path);
CFTypeRef MDItemCopyAttribute(MDItemRef item, CFStringRef name);
CFDictionaryRef MDItemCopyAttributes(MDItemRef item, CFArrayRef names);
extern const CFStringRef kMDItemContentType, kMDItemDisplayName, kMDItemKind, kMDItemFSSize, kMDItemLastUsedDate, kMDItemContentTypeTree;
/* the Process Manager of Carbon: processes are known by pid only */
typedef struct ProcessSerialNumber { uint32_t highLongOfPSN, lowLongOfPSN; } ProcessSerialNumber;
enum { procNotFound = -600 };
OSStatus GetProcessForPID(pid_t pid, ProcessSerialNumber *psn);
OSStatus CopyProcessName(const ProcessSerialNumber *psn, CFStringRef *name);
/* the type codes of the icons of Icon Services (for -[NSWorkspace iconForFileType:] with NSFileTypeForHFSTypeCode) */
enum { kToolbarHomeIcon = 'tHom', kLockedIcon = 'lock', kUnlockedIcon = 'ulck', kToolbarDeleteIcon = 'tDel', kToolbarInfoIcon = 'tInf', kGenericFolderIcon = 'fldr', kGenericApplicationIcon = 'APPL' };
#ifdef __cplusplus
}
#endif
#pragma clang arc_cf_code_audited end
enum { noErr = 0, userCanceledErr = -128, fnfErr = -43, paramErr = -50, permErr = -54 };
#include <CoreServices/FileManager.h>
#endif
#if defined(__has_include)
#if __has_include(<CoreGraphics/CoreGraphics.h>) && !defined(__APPLE__)
#include <CoreGraphics/CoreGraphics.h>   /* on a Mac CoreServices / ApplicationServices bring CoreGraphics and CoreText along */
#endif
#if __has_include(<CoreText/CoreText.h>) && !defined(__APPLE__)
#include <CoreText/CoreText.h>
#include <wsbsd/CoreTextNames.h>
#endif
#endif
#include <CoreServices/Gestalt.h>
#include <CoreServices/LaunchServices.h>
#include <CoreServices/IconsCore.h>
#include <CoreServices/ResourceManager.h>
#include <CoreFoundation/CFUserNotification.h>
#include <CoreFoundation/CFPreferences.h>
#include <CFNetwork/CFNetwork.h>
#include <CoreServices/AppleEvents.h>
#endif
