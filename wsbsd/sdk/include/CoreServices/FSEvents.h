/* <CoreServices/FSEvents.h> for the wsbsd SDK: the file system event streams, implemented by polling (sdk/src/FSEvents.m): the watched trees are scanned every
 * `latency` seconds (at least half a second) and the differences are reported. */
#ifndef WSBSD_FSEVENTS_H
#define WSBSD_FSEVENTS_H
#include <stdint.h>
#include <CoreFoundation/CoreFoundation.h>
#include <dispatch/dispatch.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct __FSEventStream *FSEventStreamRef;
typedef const struct __FSEventStream *ConstFSEventStreamRef;
typedef uint64_t FSEventStreamEventId;
typedef uint32_t FSEventStreamEventFlags;
typedef struct { CFIndex version; void *info; const void *(*retain)(const void *); void (*release)(const void *); CFStringRef (*copyDescription)(const void *); } FSEventStreamContext;
typedef void (*FSEventStreamCallback)(ConstFSEventStreamRef streamRef, void *clientCallBackInfo, size_t numEvents, void *eventPaths,
                                       const FSEventStreamEventFlags eventFlags[], const FSEventStreamEventId eventIds[]);
#define kFSEventStreamEventIdSinceNow 0xFFFFFFFFFFFFFFFFULL
enum { kFSEventStreamCreateFlagNone = 0, kFSEventStreamCreateFlagUseCFTypes = 1, kFSEventStreamCreateFlagNoDefer = 2, kFSEventStreamCreateFlagWatchRoot = 4,
       kFSEventStreamCreateFlagIgnoreSelf = 8, kFSEventStreamCreateFlagFileEvents = 0x10 };
enum { kFSEventStreamEventFlagNone = 0, kFSEventStreamEventFlagMustScanSubDirs = 1, kFSEventStreamEventFlagUserDropped = 2, kFSEventStreamEventFlagKernelDropped = 4, kFSEventStreamEventFlagEventIdsWrapped = 8, kFSEventStreamEventFlagHistoryDone = 0x10, kFSEventStreamEventFlagRootChanged = 0x20, kFSEventStreamEventFlagMount = 0x40, kFSEventStreamEventFlagUnmount = 0x80, kFSEventStreamEventFlagItemCreated = 0x100, kFSEventStreamEventFlagItemRemoved = 0x200,
       kFSEventStreamEventFlagItemModified = 0x1000, kFSEventStreamEventFlagItemIsFile = 0x10000, kFSEventStreamEventFlagItemIsDir = 0x20000 };
FSEventStreamRef FSEventStreamCreate(CFAllocatorRef allocator, FSEventStreamCallback callback, FSEventStreamContext *context, CFArrayRef pathsToWatch,
                                     FSEventStreamEventId sinceWhen, CFTimeInterval latency, uint32_t flags);
FSEventStreamRef FSEventStreamCreateRelativeToDevice(CFAllocatorRef allocator, FSEventStreamCallback callback, FSEventStreamContext *context, dev_t deviceToWatch, CFArrayRef pathsToWatchRelativeToDevice,
                                                   FSEventStreamEventId sinceWhen, CFTimeInterval latency, uint32_t flags);
void FSEventStreamScheduleWithRunLoop(FSEventStreamRef streamRef, CFRunLoopRef runLoop, CFStringRef runLoopMode);
void FSEventStreamUnscheduleFromRunLoop(FSEventStreamRef streamRef, CFRunLoopRef runLoop, CFStringRef runLoopMode);
void FSEventStreamFlushSync(FSEventStreamRef streamRef);
void FSEventStreamFlushAsync(FSEventStreamRef streamRef);
FSEventStreamEventId FSEventsGetCurrentEventId(void);
FSEventStreamEventId FSEventStreamGetLatestEventId(ConstFSEventStreamRef streamRef);
void FSEventStreamSetDispatchQueue(FSEventStreamRef streamRef, dispatch_queue_t q);
Boolean FSEventStreamStart(FSEventStreamRef streamRef);
void FSEventStreamStop(FSEventStreamRef streamRef);
void FSEventStreamInvalidate(FSEventStreamRef streamRef);
void FSEventStreamRelease(FSEventStreamRef streamRef);
#ifdef __cplusplus
}
#endif
#endif
