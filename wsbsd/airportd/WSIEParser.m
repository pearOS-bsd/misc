#import "WSIEParser.h"
@implementation WSIEParser
static NSNumber *N(long long v) { return @(v); }
/* RSN / WPA body: version, group cipher, pairwise count + list, AKM count + list (suite = OUI(3) + type(1)) */
static NSDictionary *ParseRSN(const uint8_t *b, size_t n, BOOL wpa)
{
	size_t o = 0; if (n < 2) return nil; o = 2; NSMutableDictionary *d = [NSMutableDictionary dictionary]; NSString *p = wpa ? @"IE_KEY_WPA_" : @"IE_KEY_RSN_";
	if (o + 4 <= n) { d[[p stringByAppendingString: @"MCIPHER"]] = N(b[o + 3]); o += 4; } else return d;
	if (o + 2 > n) return d; int uc = b[o] | b[o + 1] << 8; o += 2; NSMutableArray *ucs = [NSMutableArray array]; for (int i = 0; i < uc && o + 4 <= n; i++, o += 4) [ucs addObject: N(b[o + 3])]; d[[p stringByAppendingString: @"UCIPHERS"]] = ucs;
	if (o + 2 > n) return d; int ak = b[o] | b[o + 1] << 8; o += 2; NSMutableArray *aks = [NSMutableArray array]; for (int i = 0; i < ak && o + 4 <= n; i++, o += 4) [aks addObject: N(b[o + 3])]; d[[p stringByAppendingString: @"AUTHSELS"]] = aks;
	return d;
}
+ (NSDictionary *)scanRecordKeysForIEData:(NSData *)ie
{
	const uint8_t *p = [ie bytes]; size_t n = [ie length], o = 0; NSMutableDictionary *r = [NSMutableDictionary dictionary]; NSMutableDictionary *interworking = nil; NSMutableDictionary *dev = nil;
	while (o + 2 <= n) {
		uint8_t id = p[o], len = p[o + 1]; if (o + 2 + len > n) break; const uint8_t *b = p + o + 2; o += 2 + len;
		switch (id) {
		case 0: if (len) r[@"SSID"] = [NSData dataWithBytes: b length: len]; break;
		case 7: if (len >= 2) { NSString *cc = [[NSString alloc] initWithBytes: b length: 2 encoding: NSASCIIStringEncoding]; if (cc) r[@"80211D_IE"] = @{ @"IE_KEY_80211D_COUNTRY_CODE": cc }; } break;
		case 45: r[@"HT_CAPS_IE"] = @{ }; break;
		case 48: { NSDictionary *d = ParseRSN(b, len, NO); if (d) r[@"RSN_IE"] = d; } break;
		case 107: { interworking = [NSMutableDictionary dictionary]; if (len >= 1) { interworking[@"INTERWORKING_ACCESS_NETWORK_TYPE"] = N(b[0] & 0x0f); interworking[@"INTERWORKING_ACCESS_INTERNET"] = N((b[0] >> 4) & 1); interworking[@"INTERWORKING_ACCESS_ASRA"] = N((b[0] >> 5) & 1); interworking[@"INTERWORKING_ACCESS_ESR"] = N((b[0] >> 6) & 1); interworking[@"INTERWORKING_ACCESS_UESA"] = N((b[0] >> 7) & 1); }
			if (len == 3 || len == 9) { interworking[@"INTERWORKING_ACCESS_VENTURE_GRP"] = N(b[1]); interworking[@"INTERWORKING_ACCESS_VENTURE_TYPE"] = N(b[2]); }
			if (len >= 7) { const uint8_t *h = b + (len - 6); interworking[@"INTERWORKING_ACCESS_HESSID"] = [NSString stringWithFormat: @"%02x:%02x:%02x:%02x:%02x:%02x", h[0], h[1], h[2], h[3], h[4], h[5]]; } r[@"11U_INTERWORKING_IE"] = interworking; } break;
		case 191: r[@"VHT_CAPS"] = @{ }; break;
		case 255: if (len >= 1 && b[0] == 35) r[@"HE_CAP"] = @{ }; break;
		case 221:
			if (len >= 4 && b[0] == 0x00 && b[1] == 0x50 && b[2] == 0xf2 && b[3] == 0x01) { NSDictionary *d = ParseRSN(b + 4, len - 4, YES); if (d) r[@"WPA_IE"] = d; }
			else if (len >= 4 && b[0] == 0x00 && b[1] == 0x50 && b[2] == 0xf2 && b[3] == 0x04) { r[@"WPS_BEACON_IE"] = @{ }; }
			else if (len >= 4 && b[0] == 0x50 && b[1] == 0x6f && b[2] == 0x9a && b[3] == 0x10) { r[@"HOTSPOT20_IE"] = @{ }; }
			else if (len >= 4 && b[0] == 0x00 && b[1] == 0x17 && b[2] == 0xf2 && b[3] == 0x06) { r[@"IOS_IE"] = @{ }; }     /* the iOS IE: a device sharing its connection */
			else if (len >= 4 && b[0] == 0x00 && b[1] == 0x17 && b[2] == 0xf2 && b[3] == 0x09) { if (!dev) dev = [NSMutableDictionary dictionary]; }
			break;
		}
	}
	if (dev) r[@"APPLE_DEVICE_IE"] = dev;
	return r;
}
+ (NSString *)SSIDStringForData:(NSData *)d { NSString *s = [[NSString alloc] initWithData: d encoding: NSUTF8StringEncoding]; return s; }
@end
