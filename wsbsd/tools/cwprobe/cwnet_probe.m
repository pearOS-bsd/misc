/* cwnet_probe (macOS only): builds CWNetwork objects from scan-record dictionaries with the private -initWithScanRecord: of the real CoreWLAN and prints every getter, as a property list.
 *   cwnet_probe keys                 which scan-record keys change which getters (one key at a time, several value shapes)
 *   cwnet_probe eval FILE.plist      evaluates the records of an array of dictionaries and writes the results (an array of dictionaries) to stdout
 * The output is the oracle the FreeBSD CoreWLAN is compared with (sdk/tests/cwnet_golden). clang -fobjc-arc -framework Foundation -framework CoreWLAN cwnet_probe.m */
#import <Foundation/Foundation.h>
#import <CoreWLAN/CoreWLAN.h>
#import <objc/message.h>
@interface CWNetwork (P) - (instancetype)initWithScanRecord:(NSDictionary *)r; @end
@interface CWChannel (P) - (instancetype)initWithInfo:(NSDictionary *)i; - (NSDictionary *)info; - (unsigned long long)flags; - (unsigned long long)channelProperties; @end
static id Norm(id v) { if (!v) return @"<nil>"; if ([v isKindOfClass: [NSData class]]) { NSMutableString *h = [NSMutableString stringWithString: @"<data "]; const unsigned char *b = [(NSData *)v bytes]; for (NSUInteger i = 0; i < [(NSData *)v length]; i++) [h appendFormat: @"%02x", b[i]]; [h appendString: @">"]; return h; } if ([v isKindOfClass: [CWChannel class]]) return [v description] ? @{ @"channelNumber": @([v channelNumber]), @"channelWidth": @([v channelWidth]), @"channelBand": @([v channelBand]) } : @"<nil>"; if ([v isKindOfClass: [NSNumber class]] || [v isKindOfClass: [NSString class]]) return v; return [v description]; }
static NSDictionary *EvalRaw(NSDictionary *rec);
static NSDictionary *Eval(NSDictionary *rec) { @try { return EvalRaw(rec); } @catch (NSException *e) { return @{ @"exception": [e name] }; } }
static NSDictionary *EvalRaw(NSDictionary *rec)
{
	CWNetwork *n = [[CWNetwork alloc] initWithScanRecord: rec]; NSMutableDictionary *out = [NSMutableDictionary dictionary]; if (!n) return @{ @"nil": @YES };
	static NSArray *getters; if (!getters) getters = @[ @"ssid", @"ssidData", @"bssid", @"bssidData", @"wlanChannel", @"rssiValue", @"noiseMeasurement", @"informationElementData", @"countryCode", @"beaconInterval", @"ibss", @"supportsEasyConnect", @"supportsWPS", @"securityType", @"physicalLayerMode", @"isP2P", @"isCarPlayNetwork", @"isPersonalHotspot", @"isPasspoint", @"anqpDomainID", @"hasInterworkingIE", @"accessNetworkType", @"hasInternet", @"isAdditionalStepRequiredForAccess", @"isEmergencyServicesReachable", @"isUnauthenticatedEmergencyServiceAccessible", @"venueGroup", @"venueType", @"hessid", @"aggregateRSSI", @"isUnconfiguredAccessory", @"isUnconfiguredAirPlayAccessory", @"isUnconfiguredAirPrintAccessory", @"isSecureWACDevice", @"accessoryFriendlyName", @"isAppleSWAP", @"isWiFiNetworkChargeablePublicNetwork", @"isWiFiNetworkMetered", @"strongestSupportedSecurity", @"fastestSupportedPHYMode", @"supportsEAP", @"supportsPSK", @"isOpen", @"hasNon6GHzRNRChannel", @"ieData", @"description" ];
	for (NSString *g in getters) { SEL s = NSSelectorFromString(g); if (![n respondsToSelector: s]) continue; NSMethodSignature *ms = [n methodSignatureForSelector: s]; const char *t = [ms methodReturnType]; id v = nil;
		if (t[0] == '@') v = ((id (*)(id, SEL))objc_msgSend)(n, s); else if (t[0] == 'B') v = @(((BOOL (*)(id, SEL))objc_msgSend)(n, s)); else if (t[0] == 'q') v = @(((long long (*)(id, SEL))objc_msgSend)(n, s)); else if (t[0] == 'Q') v = @(((unsigned long long (*)(id, SEL))objc_msgSend)(n, s));
		if ([g isEqual: @"description"]) { v = [[v description] stringByReplacingOccurrencesOfString: [NSString stringWithFormat: @"%p", n] withString: @"PTR"]; if ([v length] > 400) v = [v substringToIndex: 400]; }
		out[g] = Norm(v); }
	for (int i = 0; i < 16; i++) { out[[NSString stringWithFormat: @"supportsSecurity:%d", i]] = @([n supportsSecurity: i]); out[[NSString stringWithFormat: @"supportsPHYMode:%d", i]] = @([n supportsPHYMode: i]); }
	return out;
}
int main(int argc, char **argv)
{
	@autoreleasepool {
		if (argc >= 3 && !strcmp(argv[1], "chan")) {
			NSArray *recs = [NSArray arrayWithContentsOfFile: @(argv[2])]; NSMutableArray *res = [NSMutableArray array];
			for (NSDictionary *r in recs) { @try { CWChannel *c = [[CWChannel alloc] initWithInfo: r]; NSString *d = [[c description] stringByReplacingOccurrencesOfString: [NSString stringWithFormat: @"%p", c] withString: @"PTR"];
				CWChannel *c2 = [c copy]; CWChannel *c3 = [[CWChannel alloc] initWithInfo: r];
				[res addObject: @{ @"channelNumber": @(c.channelNumber), @"channelWidth": @(c.channelWidth), @"channelBand": @(c.channelBand), @"flags": @(c.flags), @"channelProperties": @(c.channelProperties), @"description": d, @"info": [c.info description] ?: @"", @"equal": @([c isEqual: c2]), @"equalNew": @([c isEqualToChannel: c3]), @"hash": @([c hash]) }]; } @catch (NSException *e) { [res addObject: @{ @"exception": [e name] }]; } }
			NSData *d = [NSPropertyListSerialization dataWithPropertyList: res format: NSPropertyListXMLFormat_v1_0 options: 0 error: nil]; fwrite([d bytes], 1, [d length], stdout); return 0; }
		if (argc >= 3 && !strcmp(argv[1], "eval")) {
			NSArray *recs = [NSArray arrayWithContentsOfFile: @(argv[2])]; NSMutableArray *res = [NSMutableArray array]; for (NSDictionary *r in recs) [res addObject: Eval(r)];
			NSData *d = [NSPropertyListSerialization dataWithPropertyList: res format: NSPropertyListXMLFormat_v1_0 options: 0 error: nil]; fwrite([d bytes], 1, [d length], stdout); return 0; }
		NSArray *keys = @[ @"SSID", @"SSID_STR", @"BSSID", @"CHANNEL", @"CHANNEL_FLAGS", @"RSSI", @"NOISE", @"BEACON_INT", @"CAPS", @"IBSS", @"AP_MODE", @"RATES", @"IE", @"RSN_IE", @"WPA_IE", @"IOS_IE", @"APPLE_IE", @"APPLE_DEVICE_IE", @"APPLE_P2P_IE", @"APPLE_SWAP", @"HOTSPOT20_IE", @"HT_CAPS_IE", @"VHT_CAPS", @"HE_CAP", @"WPS_BEACON_IE", @"WPS_PROB_RESP_IE", @"80211D_IE", @"COUNTRY_CODE", @"MFP_CAPABLE", @"MFP_REQUIRED", @"EZCONNECT", @"EZC_FLAGS", @"AP_CAPABLE", @"ANQP_DOMAIN_ID", @"INTERWORKING_ACCESS_NETWORK_TYPE", @"INTERWORKING_ACCESS_INTERNET", @"INTERWORKING_ACCESS_HESSID", @"INTERWORKING_ACCESS_VENTURE_GRP", @"INTERWORKING_ACCESS_VENTURE_TYPE", @"INTERWORKING_ACCESS_ASRA", @"INTERWORKING_ACCESS_ESR", @"INTERWORKING_ACCESS_UESA", @"SCAN_RESULT_OWE_MULTI_SSID", @"AWDL_INFO_EXT", @"WEP40", @"WPA2", @"WEPOPENSYSTEM" ];
		NSArray *vals = @[ @0, @1, @6, @(-60), @"00:11:22:33:44:55", @"x", [NSData dataWithBytes: "\x01\x02\x03" length: 3], [NSData data], @[ @1, @2 ], @{ }, @{ @"IE_KEY_RSN_AUTHSELS": @[ @2 ], @"IE_KEY_RSN_UCIPHERS": @[ @4 ], @"IE_KEY_RSN_MCIPHER": @4 } ];
		NSDictionary *base = Eval(@{ }); printf("base: %lu getters\n", (unsigned long)[base count]);
		for (NSString *k in keys) { NSMutableSet *changed = [NSMutableSet set]; NSMutableArray *shapes = [NSMutableArray array];
			for (id v in vals) { NSDictionary *r = Eval(@{ k: v }); BOOL any = NO; for (NSString *g in r) if (![r[g] isEqual: base[g]]) { [changed addObject: g]; any = YES; } if (any) [shapes addObject: [NSString stringWithFormat: @"%@", [v isKindOfClass: [NSData class]] ? @"data" : [v isKindOfClass: [NSDictionary class]] ? @"dict" : [v isKindOfClass: [NSArray class]] ? @"array" : [v isKindOfClass: [NSString class]] ? @"string" : @"number"]]; }
			if ([changed count]) printf("%-34s -> %s   (types: %s)\n", [k UTF8String], [[[[changed allObjects] sortedArrayUsingSelector: @selector(compare:)] componentsJoinedByString: @","] UTF8String], [[[[NSSet setWithArray: shapes] allObjects] componentsJoinedByString: @","] UTF8String]); }
	}
	return 0;
}
