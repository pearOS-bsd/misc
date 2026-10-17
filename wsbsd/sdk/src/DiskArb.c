/* ---- DiskArbitration: sessions exist, disks are never announced ---- */
#include <CoreFoundation/CoreFoundation.h>
#include <stdlib.h>
typedef struct __DASession *DASessionRef;
typedef struct __DADisk *DADiskRef;
typedef void (*DADiskAppearedCallback)(DADiskRef disk, void *context);
typedef void (*DADiskDisappearedCallback)(DADiskRef disk, void *context);
CFStringRef kDADiskDescriptionVolumeNameKey, kDADiskDescriptionVolumeNetworkKey, kDADiskDescriptionMediaNameKey, kDADiskDescriptionMediaWholeKey, kDADiskDescriptionMediaBSDNameKey,
            kDADiskDescriptionBusNameKey, kDADiskDescriptionMediaSizeKey, kDADiskDescriptionMediaWritableKey, kDADiskDescriptionVolumePathKey, kDADiskDescriptionDeviceModelKey;
__attribute__((constructor)) static void initDAConstants(void)
{
	kDADiskDescriptionVolumeNameKey = CFSTR("DAVolumeName"); kDADiskDescriptionVolumeNetworkKey = CFSTR("DAVolumeNetwork"); kDADiskDescriptionMediaNameKey = CFSTR("DAMediaName");
	kDADiskDescriptionMediaWholeKey = CFSTR("DAMediaWhole"); kDADiskDescriptionMediaBSDNameKey = CFSTR("DAMediaBSDName"); kDADiskDescriptionBusNameKey = CFSTR("DABusName");
	kDADiskDescriptionMediaSizeKey = CFSTR("DAMediaSize"); kDADiskDescriptionMediaWritableKey = CFSTR("DAMediaWritable"); kDADiskDescriptionVolumePathKey = CFSTR("DAVolumePath");
	kDADiskDescriptionDeviceModelKey = CFSTR("DADeviceModel");
}
DASessionRef DASessionCreate(CFAllocatorRef a) { (void)a; return (DASessionRef)calloc(1, 16); }
void DASessionScheduleWithRunLoop(DASessionRef s, CFRunLoopRef r, CFStringRef m) { (void)s; (void)r; (void)m; }
void DASessionUnscheduleFromRunLoop(DASessionRef s, CFRunLoopRef r, CFStringRef m) { (void)s; (void)r; (void)m; }
void DARegisterDiskAppearedCallback(DASessionRef s, CFDictionaryRef m, DADiskAppearedCallback cb, void *c) { (void)s; (void)m; (void)cb; (void)c; }
void DARegisterDiskDisappearedCallback(DASessionRef s, CFDictionaryRef m, DADiskDisappearedCallback cb, void *c) { (void)s; (void)m; (void)cb; (void)c; }
void DAUnregisterCallback(DASessionRef s, void *cb, void *c) { (void)s; (void)cb; (void)c; }
CFDictionaryRef DADiskCopyDescription(DADiskRef d) { (void)d; return NULL; }
const char *DADiskGetBSDName(DADiskRef d) { (void)d; return NULL; }
DADiskRef DADiskCreateFromBSDName(CFAllocatorRef a, DASessionRef s, const char *n) { (void)a; (void)s; (void)n; return NULL; }
