/* Sets each property of a CWMutableNetworkProfile to a few values and prints what else changes (getters, description lines, equality, hash). Run on the Mac and on wsbsd, diff the outputs. */
#import <Foundation/Foundation.h>
#import <CoreWLAN/CoreWLAN.h>
@interface CWNetworkProfile (Priv) - (instancetype)initWithExternalForm:(NSDictionary *)d; @end
static NSString *F(id v);
static NSString *F(id v) { if (!v) return @"nil"; if ([v isKindOfClass: [NSDictionary class]]) { NSMutableString *r = [NSMutableString stringWithString: @"{"]; for (id k in [[v allKeys] sortedArrayUsingSelector: @selector(compare:)]) [r appendFormat: @"%@=%@;", k, F(v[k])]; return [r stringByAppendingString: @"}"]; } if ([v isKindOfClass: [NSNumber class]]) return [NSString stringWithFormat: @"n%@", v]; if ([v isKindOfClass: [NSDate class]]) return [NSString stringWithFormat: @"date(%.0f)", [v timeIntervalSinceReferenceDate]]; if ([v isKindOfClass: [NSData class]]) { NSMutableString *s = [NSMutableString stringWithFormat: @"data%lu:", (unsigned long)[v length]]; const unsigned char *b = [v bytes]; for (NSUInteger i = 0; i < [v length]; i++) [s appendFormat: @"%02x", b[i]]; return s; }
	if ([v isKindOfClass: [NSSet class]]) return [NSString stringWithFormat: @"set[%@]", [[[v allObjects] sortedArrayUsingSelector: @selector(compare:)] componentsJoinedByString: @","]]; if ([v isKindOfClass: [NSArray class]]) return [NSString stringWithFormat: @"arr[%@]", [v componentsJoinedByString: @","]]; return [[v description] stringByReplacingOccurrencesOfString: @"\n" withString: @" "]; }
static NSArray *Props(void) { return @[ @"lastAutoJoinAt", @"lastManualJoinAt", @"captiveNetworkStatus", @"captiveNetwork", @"wasCaptiveNetwork", @"temporarilyDisabled", @"systemMode", @"hiddenNetwork", @"securityType", @"autoLogin", @"captiveBypass", @"disabled", @"isPasspoint", @"domainName", @"displayName", @"roamingConsortiumList", @"naiRealmList", @"isServiceProviderRoamingEnabled", @"possiblyHiddenNetwork", @"collocatedGroup", @"channelHistory", @"roamingProfileType", @"transitionDisabledFlags", @"standalone6G", @"isPersonalHotspot", @"bssidList", @"shareMode", @"userRole", @"payloadUUID", @"addedBy", @"addedAt", @"wasHiddenBefore", @"captiveSheetTimestamp", @"userPreferredOrderTimestamp", @"updatedAt", @"discoveredAt", @"networkGroupID", @"networkGroupPriority", @"userPreferredNetworkNames", @"userPreferredPasspointDomains", @"privacyProxyEnabled", @"movingAttribute", @"publicAttribute", @"lowDataMode", @"ssidData", @"security", @"lastConnected", @"ssid", @"identifier" ]; }
static NSDictionary *Snap(CWNetworkProfile *p) { NSMutableDictionary *d = [NSMutableDictionary dictionary]; for (NSString *k in Props()) { @try { d[k] = F([p valueForKey: k]); } @catch (id e) { d[k] = @"<exc>"; } } return d; }
static NSArray *Lines(CWNetworkProfile *p) { return [[p description] componentsSeparatedByString: @"\n"]; }
static NSArray *Values(NSString *k) {
	NSSet *dates = [NSSet setWithObjects: @"lastAutoJoinAt", @"lastManualJoinAt", @"addedAt", @"wasHiddenBefore", @"captiveSheetTimestamp", @"userPreferredOrderTimestamp", @"updatedAt", @"discoveredAt", nil];
	if ([dates containsObject: k]) return @[ [NSDate dateWithTimeIntervalSinceReferenceDate: 600000000], [NSDate dateWithTimeIntervalSinceReferenceDate: 700000000] ];
	if ([@[ @"domainName", @"displayName", @"payloadUUID", @"networkGroupID" ] containsObject: k]) return @[ @"x.example", @"" ];
	if ([@[ @"roamingConsortiumList", @"naiRealmList", @"bssidList" ] containsObject: k]) return @[ @[ @"a", @"b" ], @[] ];
	if ([k isEqual: @"collocatedGroup"]) return @[ [NSSet setWithObject: @"c"] ];
	if ([k isEqual: @"channelHistory"]) return @[ [NSSet set] ];
	if ([@[ @"userPreferredNetworkNames", @"userPreferredPasspointDomains" ] containsObject: k]) return @[ @{ @"k": @"v" } ];
	if ([k isEqual: @"ssidData"]) return @[ [@"Other" dataUsingEncoding: NSUTF8StringEncoding], [NSData data], [NSData dataWithBytes: "\xff\xfe\x01" length: 3] ];
	if ([k isEqual: @"security"]) { NSMutableArray *a = [NSMutableArray array]; for (int i = -1; i <= 16; i++) [a addObject: @(i)]; return a; }
	if ([k isEqual: @"securityType"]) { NSMutableArray *a = [NSMutableArray array]; for (int i = 0; i <= 70; i++) [a addObject: @(i)]; for (int i = 120; i <= 135; i++) [a addObject: @(i)]; return a; }
	if ([@[ @"captiveNetwork", @"wasCaptiveNetwork", @"temporarilyDisabled", @"systemMode", @"hiddenNetwork", @"autoLogin", @"captiveBypass", @"disabled", @"isPasspoint", @"isServiceProviderRoamingEnabled", @"possiblyHiddenNetwork", @"standalone6G", @"isPersonalHotspot", @"privacyProxyEnabled" ] containsObject: k]) return @[ @1, @0 ];
	return @[ @1, @0, @2, @3, @5 ];
}
int main(void) { @autoreleasepool {
	CWMutableNetworkProfile *base = [CWMutableNetworkProfile new]; base.ssidData = [@"Home" dataUsingEncoding: NSUTF8StringEncoding]; NSDictionary *bs = Snap(base); NSArray *bl = Lines(base);
	printf("BASE ef %s\n", [F([base valueForKey: @"externalForm"]) UTF8String]); printf("BASE\n"); for (NSString *k in [[bs allKeys] sortedArrayUsingSelector: @selector(compare:)]) printf("  %s = %s\n", [k UTF8String], [bs[k] UTF8String]); for (NSString *l in bl) printf("  | %s\n", [l UTF8String]);
	for (NSString *k in Props()) { if ([@[ @"lastConnected", @"ssid", @"identifier" ] containsObject: k]) continue;
		for (id v in Values(k)) {
			CWMutableNetworkProfile *p = [CWMutableNetworkProfile new]; p.ssidData = [@"Home" dataUsingEncoding: NSUTF8StringEncoding];
			@try { [p setValue: v forKey: k]; } @catch (id e) { printf("SET %s=%s EXC\n", [k UTF8String], [F(v) UTF8String]); continue; }
			NSDictionary *s = Snap(p); NSMutableString *out = [NSMutableString string];
			for (NSString *g in Props()) if (![s[g] isEqual: bs[g]]) [out appendFormat: @"  %@: %@\n", g, s[g]];
			{ NSDictionary *e0 = [base valueForKey: @"externalForm"], *e1 = nil; @try { e1 = [p valueForKey: @"externalForm"]; } @catch (id x) { [out appendString: @"  ef EXC\n"]; }
			  for (id ek in [[(e1 ?: @{}) allKeys] sortedArrayUsingSelector: @selector(compare:)]) if (![F(e1[ek]) isEqual: F(e0[ek])]) [out appendFormat: @"  ef+ %@=%@\n", ek, F(e1[ek])];
			  for (id ek in [[(e0 ?: @{}) allKeys] sortedArrayUsingSelector: @selector(compare:)]) if (e1 && !e1[ek]) [out appendFormat: @"  ef- %@\n", ek];
			  @try { CWNetworkProfile *r = [[CWMutableNetworkProfile alloc] initWithExternalForm: e1]; [out appendFormat: @"  ef-roundtrip %d\n", [F([r valueForKey: @"externalForm"]) isEqual: F(e1)]]; } @catch (id x) { [out appendString: @"  ef-roundtrip EXC\n"]; } }
			NSArray *l = Lines(p); for (NSUInteger i = 0; i < [l count] && i < [bl count]; i++) if (![l[i] isEqual: bl[i]]) [out appendFormat: @"  | %@\n", l[i]];
			if ([l count] != [bl count]) [out appendFormat: @"  lines %lu\n", (unsigned long)[l count]];
			[out appendFormat: @"  eq=%d hash=%d copyeq=%d\n", [p isEqual: base], [p hash] == [base hash], ({ int ce = -1; @try { ce = [[p copy] isEqual: p]; } @catch (id e) { ce = -2; } ce; })];
			printf("SET %s=%s\n%s", [k UTF8String], [F(v) UTF8String], [out UTF8String]); } }
} return 0; }
