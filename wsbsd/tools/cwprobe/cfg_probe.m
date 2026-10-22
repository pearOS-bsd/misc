#import <Foundation/Foundation.h>
#import <CoreWLAN/CoreWLAN.h>
static NSData *S(const char *s) { return [NSData dataWithBytes: s length: strlen(s)]; }
static void Show(NSString *tag, id o) {
	printf("== %s\n", [tag UTF8String]);
	printf("class %s\ndesc: %s\nhash-self-equal %d\n", object_getClassName(o), [[o description] UTF8String], [o isEqual: [o copy]]);
	NSData *a = [NSKeyedArchiver archivedDataWithRootObject: o requiringSecureCoding: NO error: NULL]; printf("archive %s\n", a ? "ok" : "fail");
	id back = a ? [NSKeyedUnarchiver unarchivedObjectOfClass: [o class] fromData: a error: NULL] : nil; printf("roundtrip equal %d\n", back ? [back isEqual: o] : -1);
}
int main(void) { @autoreleasepool {
	CWMutableNetworkProfile *p1 = [CWMutableNetworkProfile new]; p1.ssidData = S("Home"); p1.security = kCWSecurityWPA2Personal;
	CWMutableNetworkProfile *p2 = [CWMutableNetworkProfile new]; p2.ssidData = S("Cafe"); p2.security = kCWSecurityNone;
	CWMutableNetworkProfile *p3 = [CWMutableNetworkProfile new]; p3.ssidData = S("Home"); p3.security = kCWSecurityWPA3Personal;
	Show(@"empty config", [CWConfiguration configuration]);
	CWMutableConfiguration *m = [CWMutableConfiguration new];
	Show(@"empty mutable", m);
	m.networkProfiles = [NSOrderedSet orderedSetWithObjects: p1, p2, nil]; Show(@"two profiles", m);
	m.rememberJoinedNetworks = NO; m.requireAdministratorForPower = YES; m.requireAdministratorForAssociation = YES; m.requireAdministratorForIBSSMode = YES; Show(@"flags", m);
	CWMutableConfiguration *n = [m mutableCopy]; printf("copy equal %d hash eq %d\n", [n isEqual: m], [n hash] == [m hash]);
	n.networkProfiles = [NSOrderedSet orderedSetWithObjects: p2, p1, nil]; printf("reordered equal %d\n", [n isEqualToConfiguration: m]);
	n.networkProfiles = [NSOrderedSet orderedSetWithObjects: p1, p2, p3, nil]; printf("three count %lu\n", (unsigned long)n.networkProfiles.count);
	CWConfiguration *im = [m copy]; printf("copy class %s mutable %d\n", object_getClassName(im), [im isKindOfClass: [CWMutableConfiguration class]]);
	printf("preferred? %d\n", [m respondsToSelector: @selector(preferredNetworks)]);
	printf("hash1 %d hash2 %d\n", [[CWConfiguration configuration] hash] == [[CWConfiguration configuration] hash], [m hash] == [[m copy] hash]);
	printf("p1 equal p3 %d p1 hash eq p3 %d\n", [p1 isEqual: p3], [p1 hash] == [p3 hash]);
	CWMutableNetworkProfile *q = [p1 mutableCopy]; q.ssidData = S("Home"); printf("p1 eq q %d\n", [p1 isEqual: q]);
	Show(@"profile", p1);
} return 0; }
