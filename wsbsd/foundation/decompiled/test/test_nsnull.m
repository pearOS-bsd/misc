/* test_nsnull.m — exercises OUR NSNull directly. Note: on the macOS host the
 * runtime also loads CoreFoundation's NSNull, so round-tripping through the
 * host NSKeyedUnarchiver would resolve to THAT class; we therefore call our
 * NSSecureCoding methods directly. Full archiver validation is on the BSD stack. */
#import "../src/NSNull.h"
#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>
#import <stdio.h>

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSNull *n = [NSNull null];
        CHECK(n != nil, "null returns an instance");
        CHECK(n == [NSNull null], "singleton identity");
        CHECK([n copy] == n, "copy returns the same immutable singleton");
        CHECK([n conformsToProtocol:@protocol(NSCopying)], "conforms to NSCopying");
        CHECK([n conformsToProtocol:@protocol(NSSecureCoding)], "conforms to NSSecureCoding");
        CHECK([[n description] isEqualToString:@"<null>"], "description is <null>");

        /* usable as a collection sentinel */
        NSArray *a = @[ [NSNull null], @"x" ];
        CHECK(a[0] == [NSNull null], "stored in an array as the shared null");

        /* NSSecureCoding contract, called directly on our class */
        CHECK([NSNull supportsSecureCoding], "supportsSecureCoding YES");
        NSNull *decoded = [[NSNull alloc] initWithCoder:(NSCoder *)nil];
        CHECK(decoded == [NSNull null], "initWithCoder returns the singleton");
        [n encodeWithCoder:(NSCoder *)nil];   /* no-op, must not crash */
        CHECK(1, "encodeWithCoder is a safe no-op");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
