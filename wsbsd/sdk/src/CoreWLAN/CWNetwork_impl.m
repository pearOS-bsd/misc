/* CWNetwork: a network is a scan record, the dictionary the Wi-Fi driver returns for a BSS (keys of Apple80211: SSID, SSID_STR, BSSID, CHANNEL, CHANNEL_FLAGS, RSSI, NOISE, BEACON_INT, AP_MODE, IE,
 * RSN_IE, WPA_IE, IOS_IE, 11U_INTERWORKING_IE, ...). Every getter is derived from it with the rules measured on the real framework by tools/cwprobe (random scan records, thousands, all getters compared;
 * sdk/tests/cwlan_golden_test.m runs them again here). */
#import <CoreWLAN/CoreWLAN_Generated.h>

static BOOL Truthy(id v) { return [v isKindOfClass: [NSNumber class]] && [v boolValue]; }
static long long Num(id v) { return [v isKindOfClass: [NSNumber class]] ? [v longLongValue] : 0; }
static NSArray *Ints(id v) { return [v isKindOfClass: [NSArray class]] ? v : @[ ]; }
static BOOL Has(NSArray *a, long long x) { for (id o in a) if ([o isKindOfClass: [NSNumber class]] && [o longLongValue] == x) return YES; return NO; }
static unsigned long long SecurityType(NSDictionary *r)
{
	unsigned long long st = 0; NSDictionary *rs = r[@"RSN_IE"], *wp = r[@"WPA_IE"];
	if ([r[@"SCAN_RESULT_OWE_MULTI_SSID"] isKindOfClass: [NSNumber class]] && ([r[@"SCAN_RESULT_OWE_MULTI_SSID"] longLongValue] == 1 || [r[@"SCAN_RESULT_OWE_MULTI_SSID"] longLongValue] == 2)) return 16384 | 2;
	if ([rs isKindOfClass: [NSDictionary class]]) {
		for (id a in Ints(rs[@"IE_KEY_RSN_AUTHSELS"])) switch (Num(a)) {
			case 2: case 4: case 6: st |= 128; break;
			case 1: case 3: case 5: st |= 2048; break;
			case 8: case 9: case 24: case 25: st |= 4096; break;
			case 12: case 13: st |= 8192; break;
			case 18: st |= 16384; break;
		}
		if (Has(Ints(rs[@"IE_KEY_RSN_UCIPHERS"]), 2) || Num(rs[@"IE_KEY_RSN_MCIPHER"]) == 2) { if (st & (128 | 4096)) st |= 64; else if (st & 8192) st |= 1024; }
	}
	if ([wp isKindOfClass: [NSDictionary class]]) st |= Has(Ints(wp[@"IE_KEY_WPA_AUTHSELS"]), 1) ? 1024 : 64;
	return st ? st : 2;
}
static unsigned SupportMask(unsigned long long st)
{
	unsigned m = 0; static const struct { unsigned long long bit; unsigned set; } t[] = { { 2, 1u << 0 | 1u << 15 }, { 64, 1u << 2 | 1u << 3 | 1u << 5 }, { 128, 1u << 3 | 1u << 4 | 1u << 5 | 1u << 13 }, { 1024, 1u << 7 | 1u << 8 | 1u << 10 },
		{ 2048, 1u << 8 | 1u << 9 | 1u << 10 }, { 4096, 1u << 5 | 1u << 11 | 1u << 13 }, { 8192, 1u << 10 | 1u << 12 }, { 16384, 1u << 14 | 1u << 15 } };
	for (size_t i = 0; i < sizeof t / sizeof t[0]; i++) if (st & t[i].bit) m |= t[i].set; return m;
}
static long long BestPHY(NSDictionary *r) { return r[@"HE_CAP"] ? 6 : r[@"VHT_CAPS"] ? 5 : r[@"HT_CAPS_IE"] ? 4 : 0; }
static NSString *SecurityName(unsigned long long st)
{
	switch (st) { case 2: return @"Open"; case 64: return @"WPA Personal"; case 128: return @"WPA2 Personal"; case 192: return @"WPA/WPA2 Personal"; case 1024: return @"WPA Enterprise"; case 2048: return @"WPA2 Enterprise"; case 3072: return @"WPA/WPA2 Enterprise";
		case 4096: return @"WPA3 Personal"; case 4224: return @"WPA2/WPA3 Personal"; case 8192: return @"WPA3 Enterprise"; case 16384: return @"OWE"; case 16386: return @"OPEN/OWE"; } return nil;
}

@implementation CWNetwork (Impl)
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithScanRecord:(NSDictionary *)r { if ((self = [super init])) _scanRecord = [r copy]; return self; }
- (instancetype)initWithCoreWiFiScanResult:(id)r { [self release]; return nil; }
- (instancetype)initWithCoder:(NSCoder *)c { if ((self = [super init])) _scanRecord = [[c decodeObjectOfClasses: [NSSet setWithObjects: [NSDictionary class], [NSArray class], [NSString class], [NSNumber class], [NSData class], [NSDate class], nil] forKey: @"_scanRecord"] copy]; return self; }
- (void)encodeWithCoder:(NSCoder *)c { [c encodeObject: _scanRecord forKey: @"_scanRecord"]; }
- (id)copyWithZone:(NSZone *)z { return [[CWNetwork allocWithZone: z] initWithScanRecord: _scanRecord]; }
- (NSDictionary *)scanRecord { return _scanRecord; }
- (void)setScanRecord:(NSDictionary *)r { if (_scanRecord != r) { [_scanRecord release]; _scanRecord = [r copy]; } }
- (void)dealloc { [_scanRecord release]; [super dealloc]; }
- (NSString *)ssid { return _scanRecord[@"SSID_STR"]; }
- (NSData *)ssidData { return _scanRecord[@"SSID"]; }
- (NSData *)bssidData { NSString *s = [self bssid]; if (!s) return nil; unsigned char b[6]; unsigned v[6]; if (sscanf([s UTF8String], "%x:%x:%x:%x:%x:%x", &v[0], &v[1], &v[2], &v[3], &v[4], &v[5]) != 6) return nil; for (int i = 0; i < 6; i++) b[i] = (unsigned char)v[i]; return [NSData dataWithBytes: b length: 6]; }
- (NSString *)bssid
{
	NSString *s = _scanRecord[@"BSSID"]; if (![s isKindOfClass: [NSString class]]) return nil; NSArray *p = [s componentsSeparatedByString: @":"]; if ([p count] != 6) return nil; unsigned v[6];
	for (int i = 0; i < 6; i++) { NSScanner *sc = [NSScanner scannerWithString: p[i]]; unsigned x; if (![sc scanHexInt: &x] || ![sc isAtEnd] || [p[i] length] == 0 || [p[i] length] > 2) return nil; v[i] = x; }
	return [NSString stringWithFormat: @"%02x:%02x:%02x:%02x:%02x:%02x", v[0], v[1], v[2], v[3], v[4], v[5]];
}
- (CWChannel *)wlanChannel
{
	id n = _scanRecord[@"CHANNEL"]; if (!n) return nil; NSMutableDictionary *d = [NSMutableDictionary dictionaryWithObject: n forKey: @"CHANNEL"]; id f = _scanRecord[@"CHANNEL_FLAGS"]; if (f) d[@"CHANNEL_FLAGS"] = f;
	return [[[CWChannel alloc] initWithInfo: d] autorelease];
}
- (long long)rssiValue { return Num(_scanRecord[@"RSSI"]); } - (long long)aggregateRSSI { return Num(_scanRecord[@"RSSI"]); }
- (long long)noiseMeasurement { return Num(_scanRecord[@"NOISE"]); } - (long long)beaconInterval { return Num(_scanRecord[@"BEACON_INT"]); }
- (BOOL)ibss { return Num(_scanRecord[@"AP_MODE"]) == 1; } - (BOOL)isIBSS { return [self ibss]; }
- (NSData *)informationElementData { return _scanRecord[@"IE"]; } - (NSData *)ieData { return _scanRecord[@"IE"]; }
- (NSString *)countryCode { return [_scanRecord[@"80211D_IE"] objectForKey: @"IE_KEY_80211D_COUNTRY_CODE"]; }
- (BOOL)supportsWPS { return _scanRecord[@"WPS_BEACON_IE"] != nil || _scanRecord[@"WPS_PROB_RESP_IE"] != nil; }
- (BOOL)supportsEasyConnect { return NO; } - (BOOL)hasNon6GHzRNRChannel { return NO;}
- (BOOL)isP2P { return _scanRecord[@"APPLE_P2P_IE"] != nil; }
- (BOOL)isPersonalHotspot { return _scanRecord[@"IOS_IE"] != nil; }
- (BOOL)isPasspoint { return _scanRecord[@"HOTSPOT20_IE"] != nil; }
- (BOOL)isAppleSWAP { long long v = Num(_scanRecord[@"APPLE_SWAP"]); return v == 1 || v == 2 || Truthy(_scanRecord[@"APPLE_SWAP"]); }
- (NSDictionary *)_dev { return [_scanRecord[@"APPLE_DEVICE_IE"] isKindOfClass: [NSDictionary class]] ? _scanRecord[@"APPLE_DEVICE_IE"] : @{ }; }
- (BOOL)isCarPlayNetwork { return Truthy([self _dev][@"APPLE_DEVICE_IE_FEATURE_SUPPORTS_CARPLAY"]); }
- (NSString *)accessoryFriendlyName { return [self _dev][@"APPLE_DEVICE_IE_FRIENDLY_NAME"]; }
- (BOOL)isUnconfiguredAccessory { NSDictionary *d = [self _dev]; return Truthy(d[@"APPLE_DEVICE_IE_FEATURE_UNCONFIGURED"]) && (Truthy(d[@"APPLE_DEVICE_IE_FEATURE_SUPPORTS_MFI_CONFIG_V1"]) || Truthy(d[@"APPLE_DEVICE_IE_FEATURE_SUPPORTS_HOMEKIT"])); }
- (BOOL)isUnconfiguredAirPlayAccessory { return [self isUnconfiguredAccessory] && Truthy([self _dev][@"APPLE_DEVICE_IE_FEATURE_SUPPORTS_AIRPLAY"]); }
- (BOOL)isUnconfiguredAirPrintAccessory { return [self isUnconfiguredAccessory] && Truthy([self _dev][@"APPLE_DEVICE_IE_FEATURE_SUPPORTS_AIRPRINT"]); }
- (BOOL)isSecureWACDevice { NSDictionary *d = [self _dev]; return Truthy(d[@"APPLE_DEVICE_IE_FEATURE_SUPPORTS_SECURE_WAC"]) && Truthy(d[@"APPLE_DEVICE_IE_FEATURE_SUPPORTS_HOMEKIT"]); }
- (NSDictionary *)_iw { return [_scanRecord[@"11U_INTERWORKING_IE"] isKindOfClass: [NSDictionary class]] ? _scanRecord[@"11U_INTERWORKING_IE"] : nil; }
- (BOOL)hasInterworkingIE { return _scanRecord[@"11U_INTERWORKING_IE"] != nil; }
- (long long)accessNetworkType { return Num([self _iw][@"INTERWORKING_ACCESS_NETWORK_TYPE"]); }
- (BOOL)hasInternet { return Truthy([self _iw][@"INTERWORKING_ACCESS_INTERNET"]); }
- (NSString *)hessid { return [self _iw][@"INTERWORKING_ACCESS_HESSID"]; }
- (long long)venueGroup { return Num([self _iw][@"INTERWORKING_ACCESS_VENTURE_GRP"]); } - (long long)venueType { return Num([self _iw][@"INTERWORKING_ACCESS_VENTURE_TYPE"]); }
- (BOOL)isAdditionalStepRequiredForAccess { return Truthy([self _iw][@"INTERWORKING_ACCESS_ASRA"]); }
- (BOOL)isEmergencyServicesReachable { return Truthy([self _iw][@"INTERWORKING_ACCESS_ESR"]); }
- (BOOL)isUnauthenticatedEmergencyServiceAccessible { return Truthy([self _iw][@"INTERWORKING_ACCESS_UESA"]); }
- (long long)anqpDomainID { return 0; }
- (BOOL)isWiFiNetworkChargeablePublicNetwork { return [self accessNetworkType] == 2 && [self _iw] != nil; }
- (BOOL)isWiFiNetworkMetered { return [self isPersonalHotspot] || [self isCarPlayNetwork] || [self isWiFiNetworkChargeablePublicNetwork]; }
- (unsigned long long)securityType { return SecurityType(_scanRecord); }
- (BOOL)supportsSecurity:(long long)s { return s >= 0 && s < 32 && (SupportMask(SecurityType(_scanRecord)) >> s & 1); }
- (BOOL)isOpen { return SecurityType(_scanRecord) == 2; }
- (BOOL)supportsPSK { return (SecurityType(_scanRecord) & (64 | 128 | 4096)) != 0; }
- (BOOL)supportsEAP { return (SecurityType(_scanRecord) & 0x2f00) != 0; }
- (long long)strongestSupportedSecurity
{
	unsigned m = SupportMask(SecurityType(_scanRecord)); static const int order[] = { 9, 7, 11, 4, 2, 1, 14 };
	for (int i = 0; i < 7; i++) if (m >> order[i] & 1) return order[i]; return (m >> 12 & 1) ? 12 : 0;
}
- (BOOL)supportsPHYMode:(long long)p { long long b = BestPHY(_scanRecord); return b != 0 && p == b; }
- (long long)fastestSupportedPHYMode { return BestPHY(_scanRecord); }
- (unsigned long long)physicalLayerMode { long long b = BestPHY(_scanRecord); return b ? 1ull << b : 0; }
- (NSString *)description
{
	CWChannel *c = [self wlanChannel];
	return [NSString stringWithFormat: @"<%@: %p> [ssid=%@, bssid=%@, security=%@, rssi=%ld, channel=%@, ibss=%u]", NSStringFromClass([self class]), self, [self ssid], [self bssid], SecurityName(SecurityType(_scanRecord)), (long)[self rssiValue], c, (unsigned)[self ibss]];
}
@end
