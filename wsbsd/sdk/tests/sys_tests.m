/* The Darwin system interfaces of the SDK layer: copyfile, uuid, exchangedata, confstr user directories, fcntl F_GETPATH, CommonCrypto digests, Gestalt, FSEvents flush */
#import <Foundation/Foundation.h>
#include <CoreServices/CoreServices.h>
#include <CommonCrypto/CommonDigest.h>
#include <copyfile.h>
#include <uuid/uuid.h>
#include <CoreFoundation/CFPreferences.h>
#include <CFNetwork/CFNetwork.h>
static int fails;
#define CHECK(c) do { if (!(c)) { printf("FAIL %s:%d %s\n", __FILE__, __LINE__, #c); fails++; } } while (0)
static void put(const char *p, const char *s) { FILE *f = fopen(p, "w"); fputs(s, f); fclose(f); }
static NSString *get(const char *p) { return [NSString stringWithContentsOfFile: [NSString stringWithUTF8String: p] encoding: NSUTF8StringEncoding error: NULL]; }
static int events;
static void cb(ConstFSEventStreamRef s, void *info, size_t n, void *paths, const FSEventStreamEventFlags f[], const FSEventStreamEventId ids[]) { events += (int)n; }
int main(void)
{
	@autoreleasepool {
		char dir[] = "/tmp/wsbsd-sys-XXXXXX"; CHECK(mkdtemp(dir) != NULL);
		NSString *d = [NSString stringWithUTF8String: dir]; char a[256], b[256], c[256]; snprintf(a, sizeof a, "%s/a", dir); snprintf(b, sizeof b, "%s/b", dir); snprintf(c, sizeof c, "%s/c", dir);
		put(a, "alpha"); put(b, "beta");
		CHECK(exchangedata(a, b, 0) == 0); CHECK([get(a) isEqual: @"beta"] && [get(b) isEqual: @"alpha"]);
		CHECK(copyfile(a, c, NULL, COPYFILE_ALL) == 0); CHECK([get(c) isEqual: @"beta"]); CHECK(copyfile(a, c, NULL, COPYFILE_ALL | COPYFILE_EXCL) == -1);
		char dd[256]; snprintf(dd, sizeof dd, "%s/tree", dir); mkdir(dd, 0755); snprintf(dd, sizeof dd, "%s/tree/x", dir); put(dd, "x"); char dst[256]; snprintf(dst, sizeof dst, "%s/copy", dir);
		char src[256]; snprintf(src, sizeof src, "%s/tree", dir); CHECK(copyfile(src, dst, NULL, COPYFILE_ALL | COPYFILE_RECURSIVE) == 0); snprintf(dd, sizeof dd, "%s/copy/x", dir); CHECK([get(dd) isEqual: @"x"]);
		int fd = open(a, O_RDONLY); char path[PATH_MAX]; memset(path, 0, sizeof path); CHECK(fcntl(fd, F_GETPATH, path) == 0); CHECK(strstr(path, "/a") != NULL); close(fd);
		char tmp[256]; size_t n = confstr(_CS_DARWIN_USER_TEMP_DIR, tmp, sizeof tmp); CHECK(n > 3 && tmp[strlen(tmp) - 1] == '/' && n == strlen(tmp) + 1);
		uuid_t u, v; char s[37]; uuid_generate(u); uuid_unparse(u, s); CHECK(strlen(s) == 36 && uuid_parse(s, v) == 0 && uuid_compare(u, v) == 0); uuid_clear(v); CHECK(uuid_is_null(v));
		unsigned char md[CC_MD5_DIGEST_LENGTH]; CC_MD5("abc", 3, md); CHECK(md[0] == 0x90 && md[1] == 0x01 && md[15] == 0x72);
		unsigned char sh[CC_SHA1_DIGEST_LENGTH]; CC_SHA1("abc", 3, sh); CHECK(sh[0] == 0xa9 && sh[1] == 0x99 && sh[19] == 0x9d);
		int32_t major = 0; CHECK(Gestalt(gestaltSystemVersionMajor, &major) == 0 && major == 10);
		NSArray *paths = @[ d ]; FSEventStreamRef st = FSEventStreamCreate(NULL, cb, NULL, (__bridge CFArrayRef)paths, kFSEventStreamEventIdSinceNow, 0.5, kFSEventStreamCreateFlagNone);
		FSEventStreamEventId before = FSEventsGetCurrentEventId(); FSEventStreamScheduleWithRunLoop(st, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode); FSEventStreamStart(st);
		snprintf(dd, sizeof dd, "%s/new", dir); put(dd, "n"); FSEventStreamFlushSync(st);
		for (int i = 0; i < 20 && !events; i++) [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
		CHECK(events >= 1); CHECK(FSEventsGetCurrentEventId() > before); FSEventStreamStop(st); FSEventStreamInvalidate(st); FSEventStreamRelease(st);
		CFPreferencesSetAppValue(CFSTR("wsbsd.test.key"), CFSTR("value"), kCFPreferencesCurrentApplication); CFPropertyListRef pv = CFPreferencesCopyAppValue(CFSTR("wsbsd.test.key"), kCFPreferencesCurrentApplication);
		CHECK(pv && CFEqual(pv, CFSTR("value"))); if (pv) CFRelease(pv); Boolean ok = false; CFPreferencesSetAppValue(CFSTR("wsbsd.test.b"), kCFBooleanTrue, kCFPreferencesCurrentApplication); CHECK(CFPreferencesGetAppBooleanValue(CFSTR("wsbsd.test.b"), kCFPreferencesCurrentApplication, &ok) && ok);
		CFPreferencesSetAppValue(CFSTR("wsbsd.test.key"), NULL, kCFPreferencesCurrentApplication); CFPreferencesSetAppValue(CFSTR("wsbsd.test.b"), NULL, kCFPreferencesCurrentApplication); CHECK(CFPreferencesCopyAppValue(CFSTR("wsbsd.test.key"), kCFPreferencesCurrentApplication) == NULL);
		setenv("http_proxy", "http://proxy.example:3128/", 1); setenv("no_proxy", "localhost,.internal", 1); CFDictionaryRef ps = CFNetworkCopySystemProxySettings(); CHECK(ps != NULL);
		CFURLRef u1 = CFURLCreateWithString(NULL, CFSTR("http://example.org/x"), NULL), u2 = CFURLCreateWithString(NULL, CFSTR("http://host.internal/y"), NULL);
		CFArrayRef a1 = CFNetworkCopyProxiesForURL(u1, ps), a2 = CFNetworkCopyProxiesForURL(u2, ps);
		CFDictionaryRef p1 = (CFDictionaryRef)CFArrayGetValueAtIndex(a1, 0), p2 = (CFDictionaryRef)CFArrayGetValueAtIndex(a2, 0);
		CHECK(CFEqual(CFDictionaryGetValue(p1, kCFProxyTypeKey), kCFProxyTypeHTTP) && CFEqual(CFDictionaryGetValue(p1, kCFProxyHostNameKey), CFSTR("proxy.example"))); CHECK(CFEqual(CFDictionaryGetValue(p2, kCFProxyTypeKey), kCFProxyTypeNone));
		CFRelease(a1); CFRelease(a2); CFRelease(u1); CFRelease(u2); CFRelease(ps);
		AppleEvent ev; CHECK(AECreateAppleEvent('aevt', 'odoc', NULL, 0, 0, &ev) == 0); CHECK(AEPutParamPtr(&ev, '----', typeUTF8Text, "hello", 5) == 0);
		AEDesc got; CHECK(AEGetParamDesc(&ev, '----', typeWildCard, &got) == 0 && got.descriptorType == typeUTF8Text && AEGetDescDataSize(&got) == 5); char tb[8] = { 0 }; CHECK(AEGetDescData(&got, tb, 7) == 0 && !strcmp(tb, "hello")); AEDisposeDesc(&got);
		AEDesc uni; CHECK(AEGetParamDesc(&ev, '----', typeUnicodeText, &uni) == 0 && AEGetDescDataSize(&uni) == 10); AEDisposeDesc(&uni); CHECK(AEGetParamDesc(&ev, 'zzzz', typeWildCard, &got) == errAEDescNotFound);
		AEDesc dup; CHECK(AEDuplicateDesc(&ev, &dup) == 0); long cnt = 0; CHECK(AECountItems(&dup, &cnt) == 0 && cnt == 3); AEDisposeDesc(&dup); AEDisposeDesc(&ev);
		[[NSFileManager defaultManager] removeItemAtPath: d error: NULL];
		printf(fails ? "%d failures\n" : "sys tests ok\n", fails);
	}
	return fails != 0;
}
