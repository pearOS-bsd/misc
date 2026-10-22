/* A simulated Wi-Fi world for airportd: the machine has no radio (CI, QEMU, a laptop with the driver missing). The world is a property list (WSBSD_WIFI_SIM, or the built-in one): the interfaces and the
 * networks in range with their security, password and signal. Scan results are real scan records, so CWNetwork reads them exactly as it reads those of a driver. */
#import <wsbsd/WSAirport.h>
#import "WSWiFiSimBackend.h"

NSString *const WSWiFiStatePower = @"power", *const WSWiFiStateSSID = @"SSID", *const WSWiFiStateBSSID = @"BSSID", *const WSWiFiStateChannel = @"CHANNEL", *const WSWiFiStateChannelFlags = @"CHANNEL_FLAGS",
	*const WSWiFiStateRSSI = @"RSSI", *const WSWiFiStateNoise = @"NOISE", *const WSWiFiStateTxRate = @"TXRATE", *const WSWiFiStateMAC = @"MAC", *const WSWiFiStateCountry = @"COUNTRY", *const WSWiFiStateLinkUp = @"linkUp",
	*const WSWiFiStateScanRecord = @"scanRecord", *const WSWiFiStateOpMode = @"opMode";

static NSError *Err(NSInteger code, NSString *why) { return [NSError errorWithDomain: @"com.apple.wifi.apple80211API.error" code: code userInfo: @{ NSLocalizedFailureReasonErrorKey: why ?: @"error" }]; }

@implementation WSWiFiSimBackend { NSMutableDictionary *_ifaces; NSArray *_networks; NSLock *_lock; }
@synthesize eventHandler;
+ (NSDictionary *)builtInWorld
{
	return @{ @"interfaces": @{ @"en0": @{ @"mac": @"02:57:53:00:00:01", @"country": @"US", @"power": @YES } },
		@"networks": @[
			@{ @"ssid": @"Home", @"bssid": @"02:11:22:33:44:01", @"channel": @6, @"width": @20, @"band": @2, @"rssi": @-48, @"security": @"wpa2", @"password": @"homepass", @"phy": @"ac" },
			@{ @"ssid": @"Home", @"bssid": @"02:11:22:33:44:02", @"channel": @149, @"width": @80, @"band": @5, @"rssi": @-58, @"security": @"wpa2wpa3", @"password": @"homepass", @"phy": @"ax" },
			@{ @"ssid": @"Cafe", @"bssid": @"02:aa:bb:cc:dd:01", @"channel": @11, @"width": @20, @"band": @2, @"rssi": @-71, @"security": @"open", @"phy": @"n" },
			@{ @"ssid": @"Alex's iPhone", @"bssid": @"02:99:88:77:66:01", @"channel": @1, @"width": @20, @"band": @2, @"rssi": @-52, @"security": @"wpa2", @"password": @"hotspot123", @"hotspot": @YES, @"phy": @"n" },
			@{ @"ssid": @"Office", @"bssid": @"02:0f:0f:0f:0f:01", @"channel": @36, @"width": @40, @"band": @5, @"rssi": @-66, @"security": @"wpa3", @"password": @"officepass", @"phy": @"ax" } ] };
}
- (instancetype)initWithWorld:(NSDictionary *)world
{
	if ((self = [super init])) {
		world = world ?: [WSWiFiSimBackend builtInWorld]; _lock = [NSLock new]; _ifaces = [NSMutableDictionary dictionary];
		[world[@"interfaces"] enumerateKeysAndObjectsUsingBlock: ^(NSString *n, NSDictionary *d, BOOL *stop) { _ifaces[n] = [@{ @"mac": d[@"mac"] ?: @"02:00:00:00:00:00", @"country": d[@"country"] ?: @"", @"power": d[@"power"] ?: @YES } mutableCopy]; }];
		NSMutableArray *nets = [NSMutableArray array]; for (NSDictionary *n in world[@"networks"]) [nets addObject: n]; _networks = nets;
	}
	return self;
}
- (instancetype)init { const char *p = getenv("WSBSD_WIFI_SIM"); return [self initWithWorld: p ? [NSDictionary dictionaryWithContentsOfFile: @(p)] : nil]; }
- (NSArray *)interfaceNames { [_lock lock]; NSArray *a = [[_ifaces allKeys] sortedArrayUsingSelector: @selector(compare:)]; [_lock unlock]; return a; }
static unsigned FlagsFor(NSDictionary *n) { int w = [n[@"width"] intValue]; unsigned f = [n[@"band"] intValue] == 5 ? 0x10 : [n[@"band"] intValue] == 6 ? 0x2000 : 0x8; f |= w >= 160 ? 0x800 : w >= 80 ? 0x400 : w >= 40 ? 0x4 : 0x2; return f; }
+ (NSDictionary *)recordForNetwork:(NSDictionary *)n
{
	NSString *sec = n[@"security"] ?: @"open"; NSMutableDictionary *r = [NSMutableDictionary dictionary]; NSString *ssid = n[@"ssid"];
	r[@"SSID_STR"] = ssid; r[@"SSID"] = [ssid dataUsingEncoding: NSUTF8StringEncoding]; r[@"BSSID"] = n[@"bssid"]; r[@"CHANNEL"] = n[@"channel"]; r[@"CHANNEL_FLAGS"] = @(FlagsFor(n)); r[@"RSSI"] = n[@"rssi"] ?: @-70; r[@"NOISE"] = @-92; r[@"BEACON_INT"] = @100; r[@"CAPS"] = @0x431; r[@"AP_MODE"] = @2;
	if ([sec isEqual: @"wpa2"]) r[@"RSN_IE"] = @{ @"IE_KEY_RSN_AUTHSELS": @[ @2 ], @"IE_KEY_RSN_UCIPHERS": @[ @4 ], @"IE_KEY_RSN_MCIPHER": @4 };
	else if ([sec isEqual: @"wpa3"]) r[@"RSN_IE"] = @{ @"IE_KEY_RSN_AUTHSELS": @[ @8 ], @"IE_KEY_RSN_UCIPHERS": @[ @4 ], @"IE_KEY_RSN_MCIPHER": @4 };
	else if ([sec isEqual: @"wpa2wpa3"]) r[@"RSN_IE"] = @{ @"IE_KEY_RSN_AUTHSELS": @[ @2, @8 ], @"IE_KEY_RSN_UCIPHERS": @[ @4 ], @"IE_KEY_RSN_MCIPHER": @4 };
	else if ([sec isEqual: @"wpa"]) r[@"WPA_IE"] = @{ @"IE_KEY_WPA_AUTHSELS": @[ @2 ], @"IE_KEY_WPA_UCIPHERS": @[ @2 ], @"IE_KEY_WPA_MCIPHER": @2 };
	else if ([sec isEqual: @"wpa2ent"]) r[@"RSN_IE"] = @{ @"IE_KEY_RSN_AUTHSELS": @[ @1 ], @"IE_KEY_RSN_UCIPHERS": @[ @4 ], @"IE_KEY_RSN_MCIPHER": @4 };
	NSString *phy = n[@"phy"]; if ([phy isEqual: @"n"] || [phy isEqual: @"ac"] || [phy isEqual: @"ax"]) r[@"HT_CAPS_IE"] = @{ }; if ([phy isEqual: @"ac"] || [phy isEqual: @"ax"]) r[@"VHT_CAPS"] = @{ }; if ([phy isEqual: @"ax"]) r[@"HE_CAP"] = @{ };
	if ([n[@"hotspot"] boolValue]) r[@"IOS_IE"] = @{ };
	return r;
}
- (NSDictionary *)_worldNetworkForRecord:(NSDictionary *)rec { for (NSDictionary *n in _networks) if ([n[@"bssid"] isEqual: rec[@"BSSID"]]) return n; for (NSDictionary *n in _networks) if ([n[@"ssid"] isEqual: rec[@"SSID_STR"]]) return n; return nil; }
- (NSDictionary *)stateForInterface:(NSString *)name
{
	[_lock lock]; NSMutableDictionary *d = _ifaces[name]; NSMutableDictionary *st = nil;
	if (d) { st = [NSMutableDictionary dictionary]; st[WSWiFiStatePower] = d[@"power"]; st[WSWiFiStateMAC] = d[@"mac"]; st[WSWiFiStateCountry] = d[@"country"]; st[WSWiFiStateLinkUp] = @(d[@"current"] != nil && [d[@"power"] boolValue]); st[WSWiFiStateOpMode] = @1;
		NSDictionary *cur = d[@"current"]; if (cur && [d[@"power"] boolValue]) { st[WSWiFiStateScanRecord] = cur; st[WSWiFiStateSSID] = cur[@"SSID"]; st[WSWiFiStateBSSID] = cur[@"BSSID"]; st[WSWiFiStateChannel] = cur[@"CHANNEL"]; st[WSWiFiStateChannelFlags] = cur[@"CHANNEL_FLAGS"]; st[WSWiFiStateRSSI] = cur[@"RSSI"]; st[WSWiFiStateNoise] = cur[@"NOISE"]; st[WSWiFiStateTxRate] = @(([cur[@"RSSI"] intValue] > -60) ? 866.0 : 130.0); } }
	[_lock unlock]; return st;
}
- (void)_emit:(NSString *)event iface:(NSString *)n info:(NSDictionary *)info { void (^h)(NSString *, NSString *, NSDictionary *) = self.eventHandler; if (h) h(event, n, info); }
- (BOOL)setPower:(BOOL)on forInterface:(NSString *)name error:(NSError **)error
{
	[_lock lock]; NSMutableDictionary *d = _ifaces[name]; BOOL changed = NO, hadLink = NO; if (d) { changed = [d[@"power"] boolValue] != on; hadLink = d[@"current"] != nil && [d[@"power"] boolValue]; d[@"power"] = @(on); if (!on) [d removeObjectForKey: @"current"]; } [_lock unlock];
	if (!d) { if (error) *error = Err(-3900, @"no such interface"); return NO; }
	if (changed) { [self _emit: @"power" iface: name info: nil]; if (hadLink && !on) { [self _emit: @"ssid" iface: name info: nil]; [self _emit: @"bssid" iface: name info: nil]; [self _emit: @"link" iface: name info: nil]; } }
	return YES;
}
- (NSArray *)scanInterface:(NSString *)name ssid:(NSData *)ssid error:(NSError **)error
{
	[_lock lock]; NSDictionary *d = _ifaces[name]; BOOL on = [d[@"power"] boolValue]; [_lock unlock];
	if (!d) { if (error) *error = Err(-3900, @"no such interface"); return nil; } if (!on) { if (error) *error = [NSError errorWithDomain: NSPOSIXErrorDomain code: 6 userInfo: nil]; return nil; }
	NSMutableArray *out = [NSMutableArray array]; for (NSDictionary *n in _networks) { if (ssid && ![[n[@"ssid"] dataUsingEncoding: NSUTF8StringEncoding] isEqual: ssid]) continue; [out addObject: [WSWiFiSimBackend recordForNetwork: n]]; }
	[self _emit: @"scanCache" iface: name info: nil]; return out;
}
- (BOOL)associateInterface:(NSString *)name toRecord:(NSDictionary *)record password:(NSString *)password error:(NSError **)error
{
	NSDictionary *net = [self _worldNetworkForRecord: record]; [_lock lock]; NSMutableDictionary *d = _ifaces[name]; BOOL on = [d[@"power"] boolValue]; [_lock unlock];
	if (!d || !on) { if (error) *error = Err(-3900, @"interface off"); return NO; }
	if (!net) { if (error) *error = Err(-3905, @"network not found"); return NO; }
	NSString *sec = net[@"security"] ?: @"open"; if (![sec isEqual: @"open"]) { if (![password isEqual: net[@"password"]]) { if (error) *error = Err(-3900, @"wrong password"); return NO; } }
	NSDictionary *rec = [WSWiFiSimBackend recordForNetwork: net]; [_lock lock]; NSDictionary *old = d[@"current"]; d[@"current"] = rec; [_lock unlock];
	if (![old[@"SSID"] isEqual: rec[@"SSID"]]) [self _emit: @"ssid" iface: name info: nil]; if (![old[@"BSSID"] isEqual: rec[@"BSSID"]]) [self _emit: @"bssid" iface: name info: nil]; [self _emit: @"link" iface: name info: nil]; return YES;
}
- (void)disassociateInterface:(NSString *)name
{
	[_lock lock]; NSMutableDictionary *d = _ifaces[name]; BOOL had = d[@"current"] != nil; [d removeObjectForKey: @"current"]; [_lock unlock];
	if (had) { [self _emit: @"ssid" iface: name info: nil]; [self _emit: @"bssid" iface: name info: nil]; [self _emit: @"link" iface: name info: nil]; }
}
- (NSArray *)supportedChannelsForInterface:(NSString *)name
{
	NSMutableArray *a = [NSMutableArray array]; for (int c = 1; c <= 11; c++) [a addObject: @{ @"CHANNEL": @(c), @"CHANNEL_FLAGS": @(0x2 | 0x8) }];
	static const int five[] = { 36, 40, 44, 48, 149, 153, 157, 161, 165 }; for (size_t i = 0; i < sizeof five / sizeof five[0]; i++) { int c = five[i]; [a addObject: @{ @"CHANNEL": @(c), @"CHANNEL_FLAGS": @(0x2 | 0x10) }]; } return a;
}
@end
