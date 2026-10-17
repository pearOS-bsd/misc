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
};

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

static void *poller(void *arg)
{
	FSEventStreamRef s = arg;
	while (s->running) {
		@autoreleasepool {
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
			if ([changed count] && s->queue && s->callback) {
				size_t n = [changed count];
				FSEventStreamEventFlags *fl = malloc(n * sizeof *fl); FSEventStreamEventId *ids = malloc(n * sizeof *ids);
				for (size_t i = 0; i < n; i++) { fl[i] = (FSEventStreamEventFlags)[[flags objectAtIndex: i] unsignedIntValue]; ids[i] = ++s->lastId; }
				NSArray *paths = [changed copy]; FSEventStreamCallback cb = s->callback; void *info = s->info; uint32_t cf = s->flags;
				dispatch_async(s->queue, ^{
					if (cf & kFSEventStreamCreateFlagUseCFTypes) cb(s, info, n, (__bridge void *)paths, fl, ids);
					else {
						const char **c = malloc(n * sizeof *c); for (size_t i = 0; i < n; i++) c[i] = [[paths objectAtIndex: i] fileSystemRepresentation];
						cb(s, info, n, (void *)c, fl, ids); free(c);
					}
					free(fl); free(ids);
				});
			}
		}
		for (double t = 0; t < s->latency && s->running; t += 0.1) usleep(100000);
	}
	return NULL;
}

FSEventStreamRef FSEventStreamCreate(CFAllocatorRef a, FSEventStreamCallback cb, FSEventStreamContext *ctx, CFArrayRef paths, FSEventStreamEventId since, CFTimeInterval latency, uint32_t flags)
{
	(void)a; (void)since;
	FSEventStreamRef s = calloc(1, sizeof *s);
	s->callback = cb; s->info = ctx ? ctx->info : NULL; s->paths = [(__bridge NSArray *)paths copy]; s->latency = latency < 0.5 ? 0.5 : latency; s->flags = flags;
	s->snapshot = [NSMutableDictionary dictionary];
	return s;
}
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
CFStringRef kSMDomainSystemLaunchd, kSMDomainUserLaunchd, kSMRightBlessPrivilegedHelper, kSMRightModifySystemDaemons;
__attribute__((constructor)) static void initSMConstants(void)
{
	kSMDomainSystemLaunchd = CFSTR("com.apple.ServiceManagement.systemdomain"); kSMDomainUserLaunchd = CFSTR("com.apple.ServiceManagement.userdomain");
	kSMRightBlessPrivilegedHelper = CFSTR("com.apple.ServiceManagement.blesshelper"); kSMRightModifySystemDaemons = CFSTR("com.apple.ServiceManagement.daemons.modify");
}
Boolean SMJobBless(CFStringRef d, CFStringRef l, AuthorizationRef a, CFErrorRef *e) { (void)d; (void)l; (void)a; if (e) *e = NULL; return false; }
CFDictionaryRef SMJobCopyDictionary(CFStringRef d, CFStringRef l) { (void)d; (void)l; return NULL; }
Boolean SMJobRemove(CFStringRef d, CFStringRef l, AuthorizationRef a, Boolean w, CFErrorRef *e) { (void)d; (void)l; (void)a; (void)w; if (e) *e = NULL; return false; }

