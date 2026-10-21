/* FSEvents over polling: a thread rescans the watched trees every `latency` seconds (at least 0.5) and reports what changed to the stream's dispatch queue. */
#import <Foundation/Foundation.h>
#include <CoreServices/FSEvents.h>
#include <pthread.h>
#include <dirent.h>
#include <sys/stat.h>
#include <unistd.h>

struct __FSEventStream {
	FSEventStreamCallback callback; void *info; NSArray *paths; double latency; uint32_t flags;
	dispatch_queue_t queue; pthread_t thread; volatile int running; int started; FSEventStreamEventId lastId;
	NSMutableDictionary *snapshot;
	NSThread *rlThread; pthread_mutex_t lock;                                          /* ScheduleWithRunLoop: events are delivered on the thread of that run loop; the lock keeps a flush and the poller apart */
};
static FSEventStreamEventId gEventId;                                                  /* the newest event id handed out (FSEventsGetCurrentEventId) */
@interface WsbsdFSDelivery : NSObject { dispatch_block_t _b; } - (id)initWithBlock:(dispatch_block_t)b; - (void)fire; @end
@implementation WsbsdFSDelivery
- (id)initWithBlock:(dispatch_block_t)b { if ((self = [super init])) _b = [b copy]; return self; }
- (void)fire { _b(); }
@end

static void scan(NSString *path, NSMutableDictionary *out)
{
	struct stat st;
	if (lstat([path fileSystemRepresentation], &st) != 0) return;
	[out setObject: [NSString stringWithFormat: @"%lld.%ld:%lld", (long long)st.st_mtime, (long)st.st_mtimespec.tv_nsec, (long long)st.st_size] forKey: path];
	if (!S_ISDIR(st.st_mode)) return;
	DIR *d = opendir([path fileSystemRepresentation]);
	if (!d) return;
	struct dirent *e;
	while ((e = readdir(d))) {
		if (!strcmp(e->d_name, ".") || !strcmp(e->d_name, "..")) continue;
		scan([path stringByAppendingPathComponent: [NSString stringWithUTF8String: e->d_name]], out);
	}
	closedir(d);
}

static void pass(FSEventStreamRef s)
{
	@autoreleasepool {
		pthread_mutex_lock(&s->lock);
		NSMutableDictionary *now = [NSMutableDictionary dictionary];
		for (NSString *p in s->paths) scan(p, now);
		NSMutableArray *changed = [NSMutableArray array]; NSMutableArray *flags = [NSMutableArray array];
		for (NSString *k in now) {
			NSString *old = [s->snapshot objectForKey: k];
			if (!old) { [changed addObject: k]; [flags addObject: @(kFSEventStreamEventFlagItemCreated)]; }
			else if (![old isEqualToString: [now objectForKey: k]]) { [changed addObject: k]; [flags addObject: @(kFSEventStreamEventFlagItemModified)]; }
		}
		for (NSString *k in s->snapshot) if (![now objectForKey: k]) { [changed addObject: k]; [flags addObject: @(kFSEventStreamEventFlagItemRemoved)]; }
		s->snapshot = now;
		size_t n = [changed count];
		FSEventStreamEventFlags *fl = n ? malloc(n * sizeof *fl) : NULL; FSEventStreamEventId *ids = n ? malloc(n * sizeof *ids) : NULL;
		for (size_t i = 0; i < n; i++) { fl[i] = (FSEventStreamEventFlags)[[flags objectAtIndex: i] unsignedIntValue]; ids[i] = ++gEventId; }
		s->lastId = gEventId;
		NSThread *th = s->rlThread; dispatch_queue_t q = s->queue;
		pthread_mutex_unlock(&s->lock);
		if (n && (q || th) && s->callback) {
			NSArray *paths = [changed copy]; FSEventStreamCallback cb = s->callback; void *info = s->info; uint32_t cf = s->flags;
			dispatch_block_t deliver = ^{
				if (cf & kFSEventStreamCreateFlagUseCFTypes) cb(s, info, n, (__bridge void *)paths, fl, ids);
				else {
					const char **c = malloc(n * sizeof *c); for (size_t i = 0; i < n; i++) c[i] = [[paths objectAtIndex: i] fileSystemRepresentation];
					cb(s, info, n, (void *)c, fl, ids); free(c);
				}
				free(fl); free(ids);
			};
			if (th) [[[WsbsdFSDelivery alloc] initWithBlock: deliver] performSelector: @selector(fire) onThread: th withObject: nil waitUntilDone: NO];
			else dispatch_async(q, deliver);
		} else { free(fl); free(ids); }
	}
}
static void *poller(void *arg)
{
	FSEventStreamRef s = arg;
	while (s->running) {
		pass(s);
		for (double t = 0; t < s->latency && s->running; t += 0.1) usleep(100000);
	}
	return NULL;
}

FSEventStreamRef FSEventStreamCreate(CFAllocatorRef a, FSEventStreamCallback cb, FSEventStreamContext *ctx, CFArrayRef paths, FSEventStreamEventId since, CFTimeInterval latency, uint32_t flags)
{
	(void)a; (void)since;
	FSEventStreamRef s = calloc(1, sizeof *s);
	s->callback = cb; s->info = ctx ? ctx->info : NULL; s->paths = [(__bridge NSArray *)paths copy]; s->latency = latency < 0.5 ? 0.5 : latency; s->flags = flags;
	s->snapshot = [NSMutableDictionary dictionary]; pthread_mutex_init(&s->lock, NULL);
	return s;
}
void FSEventStreamScheduleWithRunLoop(FSEventStreamRef s, CFRunLoopRef rl, CFStringRef mode)
{
	(void)mode; if (!s) return;
	s->rlThread = (rl == CFRunLoopGetMain()) ? [NSThread mainThread] : [NSThread currentThread];
}
void FSEventStreamUnscheduleFromRunLoop(FSEventStreamRef s, CFRunLoopRef rl, CFStringRef mode) { (void)rl; (void)mode; if (s) s->rlThread = nil; }
void FSEventStreamFlushSync(FSEventStreamRef s) { if (s && s->started) pass(s); }                 /* looks now instead of waiting for the next scan */
void FSEventStreamFlushAsync(FSEventStreamRef s) { FSEventStreamFlushSync(s); }
FSEventStreamEventId FSEventsGetCurrentEventId(void) { return gEventId; }
FSEventStreamEventId FSEventStreamGetLatestEventId(ConstFSEventStreamRef s) { return s ? s->lastId : 0; }
void FSEventStreamSetDispatchQueue(FSEventStreamRef s, dispatch_queue_t q) { if (s) s->queue = q; }
Boolean FSEventStreamStart(FSEventStreamRef s)
{
	if (!s || s->running) return false;
	for (NSString *p in s->paths) scan(p, s->snapshot);                       /* what exists now is not an event */
	s->running = 1; s->started = 1;
	return pthread_create(&s->thread, NULL, poller, s) == 0;
}
void FSEventStreamStop(FSEventStreamRef s) { if (s && s->running) { s->running = 0; pthread_join(s->thread, NULL); } }
void FSEventStreamInvalidate(FSEventStreamRef s) { FSEventStreamStop(s); if (s) s->queue = NULL; }
void FSEventStreamRelease(FSEventStreamRef s) { if (!s) return; FSEventStreamStop(s); free(s); }

/* ---- ServiceManagement: no launchd, so no helper can be installed ---- */
#include <ServiceManagement/ServiceManagement.h>
Boolean SMJobBless(CFStringRef d, CFStringRef l, AuthorizationRef a, CFErrorRef *e) { (void)d; (void)l; (void)a; if (e) *e = NULL; return false; }
CFDictionaryRef SMJobCopyDictionary(CFStringRef d, CFStringRef l) { (void)d; (void)l; return NULL; }
Boolean SMJobRemove(CFStringRef d, CFStringRef l, AuthorizationRef a, Boolean w, CFErrorRef *e) { (void)d; (void)l; (void)a; (void)w; if (e) *e = NULL; return false; }


/* paths relative to a device: the device's mount point is put in front of each */
#include <sys/mount.h>
#include <sys/stat.h>
FSEventStreamRef FSEventStreamCreateRelativeToDevice(CFAllocatorRef a, FSEventStreamCallback cb, FSEventStreamContext *ctx, dev_t dev, CFArrayRef rel, FSEventStreamEventId since, CFTimeInterval latency, uint32_t flags)
{
	struct statfs *fs; int n = getmntinfo(&fs, MNT_NOWAIT); NSString *root = nil;
	for (int i = 0; i < n; i++) { struct stat st; if (stat(fs[i].f_mntonname, &st) == 0 && st.st_dev == dev) { root = [NSString stringWithUTF8String: fs[i].f_mntonname]; break; } }
	if (!root) return NULL;
	NSMutableArray *abs = [NSMutableArray array]; for (NSString *p in (__bridge NSArray *)rel) [abs addObject: [root stringByAppendingPathComponent: p]];
	return FSEventStreamCreate(a, cb, ctx, (__bridge CFArrayRef)abs, since, latency, flags);
}
