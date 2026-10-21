/* NSString methods on CFStrings (gnustep-corebase's NSCFString): character-set searches, path components, a lowercased mutable string read back with CFStringGetBytes */
#import <Foundation/Foundation.h>
#include <CoreFoundation/CoreFoundation.h>
#include <CoreText/CoreText.h>
static int fails;
#define CHECK(c) do { if (!(c)) { printf("FAIL %s:%d %s\n", __FILE__, __LINE__, #c); fails++; } } while (0)
int main(void)
{
	@autoreleasepool {
		CFStringRef p = CFStringCreateWithCString(NULL, "/tmp/some dir/file.txt", kCFStringEncodingUTF8); NSString *s = (__bridge NSString *)p;
		CHECK([[s lastPathComponent] isEqual: @"file.txt"]); CHECK([[s pathExtension] isEqual: @"txt"]); CHECK([[s stringByDeletingLastPathComponent] isEqual: @"/tmp/some dir"]);
		CHECK([s rangeOfCharacterFromSet: [NSCharacterSet whitespaceCharacterSet]].location == 9);
		CHECK([[(__bridge NSString *)CFSTR("  trim me\n") stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]] isEqual: @"trim me"]);
		CFMutableStringRef m = CFStringCreateMutableCopy(NULL, 0, CFSTR("Alt-Svc")); CFStringLowercase(m, NULL); UInt8 buf[7]; memset(buf, 'Z', sizeof buf);
		CFIndex n = CFStringGetBytes(m, CFRangeMake(0, 7), kCFStringEncodingUTF8, '?', false, buf, 7, NULL); CHECK(n == 7 && !memcmp(buf, "alt-svc", 7));
		CFURLRef u = CFURLCreateWithFileSystemPath(NULL, CFSTR("/tmp"), kCFURLPOSIXPathStyle, true); CFTypeRef v = NULL;
		CHECK(CFURLCopyResourcePropertyForKey(u, kCFURLNameKey, &v, NULL) && v && CFEqual(v, CFSTR("tmp")));
		CHECK(CFURLCopyResourcePropertyForKey(u, kCFURLIsDirectoryKey, &v, NULL) && v == kCFBooleanTrue);
		/* a CFAttributedString is an NSAttributedString: CoreText lays it out */
		CFMutableAttributedStringRef as = CFAttributedStringCreateMutable(NULL, 0); CFAttributedStringReplaceString(as, CFRangeMake(0, 0), CFSTR("12345"));
		CHECK(CFAttributedStringGetLength(as) == 5 && [(__bridge id)as isKindOfClass: [NSAttributedString class]]);
		CFAttributedStringSetAttribute(as, CFRangeMake(1, 2), CFSTR("wsbsd.test"), CFSTR("v")); CFRange er; CFTypeRef av = CFAttributedStringGetAttribute(as, 1, CFSTR("wsbsd.test"), &er); CHECK(av && er.location == 1 && er.length == 2);
		CTLineRef line = CTLineCreateWithAttributedString(as); CHECK(line != NULL && CTLineGetTypographicBounds(line, NULL, NULL, NULL) > 0); if (line) CFRelease(line);
	}
	printf(fails ? "cfstr_tests: %d failed\n" : "cfstr_tests: ok\n", fails); return fails != 0;
}
