/* <DiskArbitration/DiskArbitration.h> for the wsbsd SDK: disk arrival notifications of macOS. A session can be created and scheduled, but no disk ever
 * "appears": programs that list drives through it find none (the volumes are mounted, not announced). */
#ifndef WSBSD_DISKARBITRATION_H
#define WSBSD_DISKARBITRATION_H
#if defined(__APPLE__)
#include_next <DiskArbitration/DiskArbitration.h>
#else
#include <CoreFoundation/CoreFoundation.h>
#pragma clang arc_cf_code_audited begin
typedef struct __DASession *DASessionRef;
typedef struct __DADisk *DADiskRef;
typedef void (*DADiskAppearedCallback)(DADiskRef disk, void *context);
typedef void (*DADiskDisappearedCallback)(DADiskRef disk, void *context);
extern const CFStringRef kDADiskDescriptionVolumeNameKey, kDADiskDescriptionVolumeNetworkKey, kDADiskDescriptionMediaNameKey, kDADiskDescriptionMediaWholeKey,
                   kDADiskDescriptionMediaBSDNameKey, kDADiskDescriptionBusNameKey, kDADiskDescriptionMediaSizeKey, kDADiskDescriptionMediaWritableKey,
                   kDADiskDescriptionVolumePathKey, kDADiskDescriptionDeviceModelKey;
DASessionRef DASessionCreate(CFAllocatorRef allocator);
void DASessionScheduleWithRunLoop(DASessionRef session, CFRunLoopRef runLoop, CFStringRef runLoopMode);
void DASessionUnscheduleFromRunLoop(DASessionRef session, CFRunLoopRef runLoop, CFStringRef runLoopMode);
void DARegisterDiskAppearedCallback(DASessionRef session, CFDictionaryRef match, DADiskAppearedCallback callback, void *context);
void DARegisterDiskDisappearedCallback(DASessionRef session, CFDictionaryRef match, DADiskDisappearedCallback callback, void *context);
void DAUnregisterCallback(DASessionRef session, void *callback, void *context);
CFDictionaryRef DADiskCopyDescription(DADiskRef disk);
const char *DADiskGetBSDName(DADiskRef disk);
DADiskRef DADiskCreateFromBSDName(CFAllocatorRef allocator, DASessionRef session, const char *name);
#pragma clang arc_cf_code_audited end
#endif
#endif
