/* ---- DiskArbitration: sessions exist, disks are never announced ---- */
#include <CoreFoundation/CoreFoundation.h>
#include <stdlib.h>
typedef struct __DASession *DASessionRef;
typedef struct __DADisk *DADiskRef;
typedef void (*DADiskAppearedCallback)(DADiskRef disk, void *context);
typedef void (*DADiskDisappearedCallback)(DADiskRef disk, void *context);
/* a session is a CF object so that callers can CFRelease it */
DASessionRef DASessionCreate(CFAllocatorRef a) { return (DASessionRef)CFDictionaryCreateMutable(a, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks); }
void DASessionScheduleWithRunLoop(DASessionRef s, CFRunLoopRef r, CFStringRef m) { (void)s; (void)r; (void)m; }
void DASessionUnscheduleFromRunLoop(DASessionRef s, CFRunLoopRef r, CFStringRef m) { (void)s; (void)r; (void)m; }
void DARegisterDiskAppearedCallback(DASessionRef s, CFDictionaryRef m, DADiskAppearedCallback cb, void *c) { (void)s; (void)m; (void)cb; (void)c; }
void DARegisterDiskDisappearedCallback(DASessionRef s, CFDictionaryRef m, DADiskDisappearedCallback cb, void *c) { (void)s; (void)m; (void)cb; (void)c; }
void DAUnregisterCallback(DASessionRef s, void *cb, void *c) { (void)s; (void)cb; (void)c; }
CFDictionaryRef DADiskCopyDescription(DADiskRef d) { (void)d; return CFDictionaryCreate(NULL, NULL, NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks); }
const char *DADiskGetBSDName(DADiskRef d) { (void)d; return NULL; }
DADiskRef DADiskCreateFromBSDName(CFAllocatorRef a, DASessionRef s, const char *n) { (void)a; (void)s; (void)n; return NULL; }
