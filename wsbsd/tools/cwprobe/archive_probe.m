#import <Foundation/Foundation.h>
#import <CoreWLAN/CoreWLAN.h>
int main(void) { @autoreleasepool {
	CWMutableNetworkProfile *p = [CWMutableNetworkProfile new]; p.ssidData = [@"Home" dataUsingEncoding: NSUTF8StringEncoding]; p.security = kCWSecurityWPA2Personal;
	NSError *e = nil; NSData *a = [NSKeyedArchiver archivedDataWithRootObject: p requiringSecureCoding: YES error: &e]; printf("archive %s %s\n", a ? "ok" : "fail", [[e description] UTF8String] ?: "");
	NSData *s1 = [NSKeyedArchiver archivedDataWithRootObject: @"x" requiringSecureCoding: YES error: &e]; printf("string %lu %s\n", (unsigned long)[s1 length], [[e description] UTF8String] ?: "");
	NSData *s2 = [NSKeyedArchiver archivedDataWithRootObject: p requiringSecureCoding: NO error: &e]; printf("profile nosecure %lu %s\n", (unsigned long)[s2 length], [[e description] UTF8String] ?: "");
	printf("supports %d\n", [CWMutableNetworkProfile supportsSecureCoding]);
	@try { NSMutableData *m = [NSMutableData data]; NSKeyedArchiver *k = [[NSKeyedArchiver alloc] initForWritingWithMutableData: m]; [k setRequiresSecureCoding: YES]; [k encodeObject: p forKey: @"root"]; [k finishEncoding]; printf("len %lu\n", (unsigned long)[m length]); NSKeyedUnarchiver *u = [[NSKeyedUnarchiver alloc] initForReadingWithData: m]; [u setRequiresSecureCoding: YES]; id b = [u decodeObjectOfClass: [CWNetworkProfile class] forKey: @"root"]; printf("back %s eq %d ssid %s id %s\n", b ? object_getClassName(b) : "nil", [b isEqual: p], [[[b ssidData] description] UTF8String] ?: "nil", [[b valueForKey: @"identifier"] UTF8String] ?: "nil"); printf("%s\n", [[b description] UTF8String]); } @catch (id x) { printf("exc %s\n", [[x description] UTF8String]); }
} return 0; }
