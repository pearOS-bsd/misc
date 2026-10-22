/* Differential test of CWNetwork and CWChannel against the real CoreWLAN: sdk/tests/golden/cwlan_golden.plist holds scan records and channel infos with every getter as the real framework on a Mac
 * answered (tools/cwprobe/cwnet_probe). usage: cwlan_golden_test GOLDEN.plist */
#import <Foundation/Foundation.h>
#import <CoreWLAN/CoreWLAN.h>
#import <objc/message.h>
@interface CWNetwork (P) - (instancetype)initWithScanRecord:(NSDictionary *)r; @end
@interface CWChannel (P) - (instancetype)initWithInfo:(NSDictionary *)i; - (NSDictionary *)info; - (unsigned long long)flags; - (unsigned long long)channelProperties; @end
static NSString *NoPtr(NSString *s) { NSMutableString *m = [NSMutableString stringWithString: s]; NSRange r; while ((r = [m rangeOfString: @"0x"]).location != NSNotFound) { NSUInteger e = r.location + 2; while (e < [m length]) { unichar c = [m characterAtIndex: e]; if (!((c >= 48 && c <= 57) || (c >= 97 && c <= 102))) break; e++; } [m replaceCharactersInRange: NSMakeRange(r.location, e - r.location) withString: @"PTR"]; } return m; }
static id Norm(id v)
{
	if (!v) return @"<nil>";
	if ([v isKindOfClass: [NSData class]]) { NSMutableString *h = [NSMutableString stringWithString: @"<data "]; const unsigned char *b = [(NSData *)v bytes]; for (NSUInteger i = 0; i < [(NSData *)v length]; i++) [h appendFormat: @"%02x", b[i]]; [h appendString: @">"]; return h; }
	if ([v isKindOfClass: [CWChannel class]]) return @{ @"channelNumber": @([v channelNumber]), @"channelWidth": @([v channelWidth]), @"channelBand": @([v channelBand]) };
	if ([v isKindOfClass: [NSNumber class]] || [v isKindOfClass: [NSString class]]) return v; return [v description];
}
static NSDictionary *EvalNetwork(NSDictionary *rec)
{
	CWNetwork *n = [[CWNetwork alloc] initWithScanRecord: rec]; NSMutableDictionary *out = [NSMutableDictionary dictionary];
	NSArray *getters = @[ @"ssid", @"ssidData", @"bssid", @"bssidData", @"wlanChannel", @"rssiValue", @"noiseMeasurement", @"informationElementData", @"countryCode", @"beaconInterval", @"ibss", @"supportsEasyConnect", @"supportsWPS", @"securityType", @"physicalLayerMode", @"isP2P", @"isCarPlayNetwork", @"isPersonalHotspot", @"isPasspoint", @"anqpDomainID", @"hasInterworkingIE", @"accessNetworkType", @"hasInternet", @"isAdditionalStepRequiredForAccess", @"isEmergencyServicesReachable", @"isUnauthenticatedEmergencyServiceAccessible", @"venueGroup", @"venueType", @"hessid", @"aggregateRSSI", @"isUnconfiguredAccessory", @"isUnconfiguredAirPlayAccessory", @"isUnconfiguredAirPrintAccessory", @"isSecureWACDevice", @"accessoryFriendlyName", @"isAppleSWAP", @"isWiFiNetworkChargeablePublicNetwork", @"isWiFiNetworkMetered", @"strongestSupportedSecurity", @"fastestSupportedPHYMode", @"supportsEAP", @"supportsPSK", @"isOpen", @"hasNon6GHzRNRChannel", @"ieData", @"description" ];
	for (NSString *g in getters) { SEL s = NSSelectorFromString(g); if (![n respondsToSelector: s]) continue; NSMethodSignature *ms = [n methodSignatureForSelector: s]; const char *t = [ms methodReturnType]; id v = nil;
		if (t[0] == '@') v = ((id (*)(id, SEL))objc_msgSend)(n, s); else if (t[0] == 'B' || t[0] == 'c' || t[0] == 'C') v = @((int)((BOOL (*)(id, SEL))objc_msgSend)(n, s) ? 1 : 0); else if (t[0] == 'q') v = @(((long long (*)(id, SEL))objc_msgSend)(n, s)); else if (t[0] == 'Q') v = @(((unsigned long long (*)(id, SEL))objc_msgSend)(n, s));
		if ([g isEqual: @"description"]) { v = [[v description] stringByReplacingOccurrencesOfString: [NSString stringWithFormat: @"%p", n] withString: @"PTR"]; if ([v length] > 400) v = [v substringToIndex: 400]; CWChannel *c = [n wlanChannel]; if (c) v = [v stringByReplacingOccurrencesOfString: [NSString stringWithFormat: @"%p", c] withString: @"PTR"]; }
		out[g] = Norm(v); }
	for (int i = 0; i < 16; i++) { out[[NSString stringWithFormat: @"supportsSecurity:%d", i]] = @([n supportsSecurity: i]); out[[NSString stringWithFormat: @"supportsPHYMode:%d", i]] = @([n supportsPHYMode: i]); }
	return out;
}
static id Dec(id v)
{
	if ([v isKindOfClass: [NSDictionary class]]) { if ([v count] == 1 && v[@"$data"]) { NSString *h = v[@"$data"]; NSMutableData *d = [NSMutableData data]; for (NSUInteger i = 0; i + 1 < [h length]; i += 2) { unsigned x; sscanf([[h substringWithRange: NSMakeRange(i, 2)] UTF8String], "%2x", &x); unsigned char b = (unsigned char)x; [d appendBytes: &b length: 1]; } return d; }
		NSMutableDictionary *o = [NSMutableDictionary dictionary]; for (id k in v) o[k] = Dec(v[k]); return o; }
	if ([v isKindOfClass: [NSArray class]]) { NSMutableArray *o = [NSMutableArray array]; for (id x in v) [o addObject: Dec(x)]; return o; }
	return v;
}
int main(int argc, char **argv)
{
	@autoreleasepool {
		NSData *raw = [NSData dataWithContentsOfFile: @(argc > 1 ? argv[1] : "sdk/tests/golden/cwlan_golden.json")]; NSDictionary *g = raw ? Dec([NSJSONSerialization JSONObjectWithData: raw options: 0 error: nil]) : nil; if (!g) { printf("cannot read the golden file\n"); return 2; }
		int nets = 0, netBad = 0, chans = 0, chanBad = 0; NSMutableDictionary *badFields = [NSMutableDictionary dictionary];
		for (NSDictionary *item in g[@"network"]) { NSDictionary *got = EvalNetwork(item[@"rec"]), *want = item[@"out"]; nets++; BOOL bad = NO;
			for (NSString *k in want) { id a = got[k], b = want[k]; if (!a) continue; if ([k isEqual: @"description"]) { a = NoPtr(a); b = NoPtr(b); } if (![a isEqual: b]) { bad = YES; badFields[k] = @([badFields[k] intValue] + 1); if ([badFields[k] intValue] == 1) printf("network %s: ours %s real %s (record %s)\n", [k UTF8String], [[a description] UTF8String], [[b description] UTF8String], [[[item[@"rec"] description] substringToIndex: MIN(160, [[item[@"rec"] description] length])] UTF8String]); } }
			if (bad) netBad++; }
		for (NSDictionary *item in g[@"channel"]) { CWChannel *c = [[CWChannel alloc] initWithInfo: item[@"rec"]]; NSDictionary *w = item[@"out"]; chans++; BOOL bad = NO;
			NSString *d = NoPtr([c description]);
			NSDictionary *got = @{ @"channelNumber": @([c channelNumber]), @"channelWidth": @([c channelWidth]), @"channelBand": @([c channelBand]), @"flags": @([c flags]), @"description": d, @"hash": @([c hash]), @"channelProperties": @([c channelProperties]) };
			for (NSString *k in got) { if (![got[k] isEqual: w[k]]) { bad = YES; badFields[[@"chan." stringByAppendingString: k]] = @([badFields[[@"chan." stringByAppendingString: k]] intValue] + 1); if ([badFields[[@"chan." stringByAppendingString: k]] intValue] == 1) printf("channel %s: ours %s real %s (%s)\n", [k UTF8String], [[got[k] description] UTF8String], [[w[k] description] UTF8String], [[[item[@"rec"] description] stringByReplacingOccurrencesOfString: @"\n" withString: @" "] UTF8String]); } }
			if (bad) chanBad++; }
		printf("%d networks (%d differ), %d channels (%d differ)\n", nets, netBad, chans, chanBad); if (netBad || chanBad) printf("fields: %s\n", [[badFields description] UTF8String]);
		printf(netBad || chanBad ? "cwlan_golden_test: differences\n" : "cwlan_golden_test: ok\n"); return netBad || chanBad;
	}
}
