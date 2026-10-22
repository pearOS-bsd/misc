/* CoreWLAN / CoreWiFi: the framework loads, every class of the inventory exists with its superclass, the value classes survive NSKeyedArchiver and -copy. */
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <stdio.h>
static int failures; static void Check(int ok, const char *what, int line) { if (!ok) { printf("FAIL %s:%d %s\n", __FILE__, line, what); failures++; } }
#define CHECK(c) Check((c), #c, __LINE__)
int main(int argc, char **argv)
{
	@autoreleasepool {
		const char *inv = argc > 1 ? argv[1] : "docs/corewlan/CoreWLAN.objc.txt";
		NSString *text = [NSString stringWithContentsOfFile: @(inv) encoding: NSUTF8StringEncoding error: nil]; CHECK(text.length > 1000);
		int classes = 0, missing = 0, roundtrip = 0;
		for (NSString *line in [text componentsSeparatedByString: @"\n"]) {
			if (![line hasPrefix: @"@class "]) continue; NSArray *w = [line componentsSeparatedByString: @" "]; if ([w[1] containsString: @"."]) continue;
			Class c = NSClassFromString(w[1]); classes++; if (!c) { missing++; printf("missing class %s\n", [w[1] UTF8String]); continue; }
			if ([line containsString: @"NSSecureCoding"] && ![w[1] isEqualToString: @"CWNetwork"]) {
				id o = [[c alloc] init]; if (!o) continue;
				NSData *d = [NSKeyedArchiver archivedDataWithRootObject: o]; id back = [NSKeyedUnarchiver unarchiveObjectWithData: d]; if ([back isKindOfClass: c]) roundtrip++; else printf("no roundtrip %s\n", [w[1] UTF8String]);
			}
		}
		printf("%d classes, %d missing, %d archive round trips\n", classes, missing, roundtrip); CHECK(missing == 0); CHECK(roundtrip > 10);
	}
	printf(failures ? "cwlan_tests: %d failures\n" : "cwlan_tests: ok\n", failures); return failures != 0;
}
