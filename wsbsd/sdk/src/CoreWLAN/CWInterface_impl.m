/* CWInterface: one Wi-Fi interface. Every getter is one request to airportd (the table of which request answers which getter was recorded on a Mac with lldb, docs/corewlan/CWInterface-xpc-trace.txt). */
#import <wsbsd/WSAirport.h>
#import <objc/runtime.h>

static CWFRequestParameters *Params(NSString *interfaceName)
{
	CWFRequestParameters *p = [[[CWFRequestParameters alloc] init] autorelease]; [p setInterfaceName: interfaceName]; [p setUUID: [NSUUID UUID]]; return p;
}

@implementation CWInterface (Impl)
+ (NSSet *)interfaceNames { NSArray *a = [[CWWiFiClient sharedWiFiClient] interfaceNames]; return a ? [NSSet setWithArray: a] : nil; }
+ (instancetype)interface { return [[CWWiFiClient sharedWiFiClient] interface]; }
+ (instancetype)interfaceWithName:(NSString *)n { return [[CWWiFiClient sharedWiFiClient] interfaceWithName: n]; }
+ (NSSet *)supportedInterfaces { return [self interfaceNames]; }
- (instancetype)initWithInterfaceName:(NSString *)n { CWWiFiClient *c = [CWWiFiClient sharedWiFiClient]; [self release]; return [[c interfaceWithName: n] retain]; }
- (instancetype)initWithInterfaceName:(NSString *)n xpcClient:(CWXPCClient *)x legacy:(BOOL)l { if ((self = [super init])) { _interfaceName = [n copy]; _xpcClient = [x retain]; _legacy = l; } return self; }
- (void)dealloc { [_interfaceName release]; [_xpcClient release]; [_capabilities release]; [super dealloc]; }
- (NSString *)interfaceName { return _interfaceName; } - (NSString *)name { return _interfaceName; }
- (BOOL)legacy { return _legacy; } - (CWXPCClient *)xpcClient { return _xpcClient; }
- (id)_proxy { return [[[_xpcClient xpcConnection] synchronousRemoteObjectProxyWithErrorHandler: ^(NSError *e) { }] retain]; }
- (id)_objectFor:(SEL)sel { __block id r = nil; id proxy = [self _proxy]; WSReplyObject reply = ^(NSError *e, id v) { r = [v retain]; }; ((void (*)(id, SEL, id, id))objc_msgSend)(proxy, sel, Params(_interfaceName), reply); [proxy release]; return [r autorelease]; }
- (long long)_intFor:(SEL)sel { __block long long r = 0; id proxy = [self _proxy]; WSReplyInteger reply = ^(NSError *e, long long v) { r = v; }; ((void (*)(id, SEL, id, id))objc_msgSend)(proxy, sel, Params(_interfaceName), reply); [proxy release]; return r; }
- (BOOL)_boolFor:(SEL)sel { __block BOOL r = NO; id proxy = [self _proxy]; WSReplyBool reply = ^(NSError *e, BOOL v) { r = v; }; ((void (*)(id, SEL, id, id))objc_msgSend)(proxy, sel, Params(_interfaceName), reply); [proxy release]; return r; }
- (double)_doubleFor:(SEL)sel { __block double r = 0; id proxy = [self _proxy]; WSReplyDouble reply = ^(NSError *e, double v) { r = v; }; ((void (*)(id, SEL, id, id))objc_msgSend)(proxy, sel, Params(_interfaceName), reply); [proxy release]; return r; }

- (BOOL)powerOn { return [self _boolFor: @selector(queryPowerWithRequestParams:reply:)]; } - (BOOL)power { return [self powerOn]; }
- (NSData *)ssidData { return [self _objectFor: @selector(querySSIDWithRequestParams:reply:)]; }
- (NSString *)ssid { NSData *d = [self ssidData]; if (![d length]) return nil; return [[[NSString alloc] initWithData: d encoding: NSUTF8StringEncoding] autorelease]; }
- (NSString *)bssid { NSString *s = [self _objectFor: @selector(queryBSSIDWithRequestParams:reply:)]; return [s length] ? s : nil; }
- (NSData *)bssidData { NSString *s = [self bssid]; unsigned v[6]; if (!s || sscanf([s UTF8String], "%x:%x:%x:%x:%x:%x", &v[0], &v[1], &v[2], &v[3], &v[4], &v[5]) != 6) return nil; unsigned char b[6]; for (int i = 0; i < 6; i++) b[i] = (unsigned char)v[i]; return [NSData dataWithBytes: b length: 6]; }
- (long long)rssiValue { return [self _intFor: @selector(queryRSSIWithRequestParams:reply:)]; } - (long long)rssi { return [self rssiValue]; } - (long long)aggregateRSSI { return [self rssiValue]; }
- (long long)noiseMeasurement { return [self _intFor: @selector(queryNoiseWithRequestParams:reply:)]; } - (long long)noise { return [self noiseMeasurement]; } - (long long)aggregateNoise { return [self noiseMeasurement]; }
- (double)transmitRate { return [self _doubleFor: @selector(queryTxRateWithRequestParams:reply:)]; } - (double)txRate { return [self transmitRate]; }
- (long long)transmitPower { return [self _intFor: @selector(queryTxPowerWithRequestParams:reply:)]; }
- (NSString *)countryCode { NSString *s = [self _objectFor: @selector(queryCountryCodeWithRequestParams:reply:)]; return [s length] ? s : nil; } - (NSString *)countryCodeInternal { return [self countryCode]; }
- (NSString *)hardwareAddress { return [self _objectFor: @selector(queryHardwareMACAddressWithRequestParams:reply:)]; } - (NSString *)macAddress { return [self _objectFor: @selector(queryMACAddressWithRequestParams:reply:)]; }
- (CWChannel *)wlanChannel { NSDictionary *d = [self _objectFor: @selector(queryChannelWithRequestParams:reply:)]; return [d count] ? [[[CWChannel alloc] initWithInfo: d] autorelease] : nil; }
- (long long)activePHYMode { return [self _intFor: @selector(queryPHYModeWithRequestParams:reply:)]; } - (long long)physicalLayerMode { return [self activePHYMode]; }
- (long long)interfaceMode { long long op = [self _intFor: @selector(queryOpModeWithRequestParams:reply:)]; return (op & 8) ? kCWInterfaceModeHostAP : (op & 2) ? kCWInterfaceModeIBSS : (op & 1) ? kCWInterfaceModeStation : kCWInterfaceModeNone; }
- (BOOL)serviceActive { return [self _boolFor: @selector(queryIsNetworkServiceEnabledWithRequestParams:reply:)]; }
- (CWNetwork *)lastNetworkJoined { NSDictionary *r = [self _objectFor: @selector(queryCurrentScanResultWithRequestParams:reply:)]; return [r count] ? [[[CWNetwork alloc] initWithScanRecord: r] autorelease] : nil; }
- (long long)security { CWNetwork *n = [self lastNetworkJoined]; return n ? [n strongestSupportedSecurity] : kCWSecurityNone; }
- (NSSet *)_channelsFor:(BOOL)hardware
{
	__block NSArray *a = nil; id proxy = [self _proxy]; WSReplyObject reply = ^(NSError *e, id v) { a = [v retain]; };
	if (hardware) [proxy queryHardwareSupportedChannelsWithRequestParams: Params(_interfaceName) reply: reply]; else [proxy querySupportedChannelsWithCountryCode: [self countryCode] requestParams: Params(_interfaceName) reply: reply];
	[proxy release]; NSMutableSet *s = [NSMutableSet set]; for (NSDictionary *d in [a autorelease]) [s addObject: [[[CWChannel alloc] initWithInfo: d] autorelease]]; return s;
}
- (NSSet *)availableWLANChannels { return [self _channelsFor: YES]; } - (NSSet *)hwSupportedWLANChannels { return [self _channelsFor: YES]; }
- (NSSet *)supportedISMChannels { return [self _channelsFor: NO]; } - (NSSet *)supportedWLANChannels { return [self _channelsFor: NO]; }
- (CWConfiguration *)configuration
{
	__block CWConfiguration *r = nil; id proxy = [self _proxy]; [proxy queryConfigurationWithInterfaceName: _interfaceName reply: ^(NSError *e, CWConfiguration *c) { r = [c retain]; }]; [proxy release]; return [r autorelease];
}
- (BOOL)commitConfiguration:(CWConfiguration *)c authorization:(id)auth error:(NSError **)error
{
	__block NSError *err = nil; id proxy = [self _proxy]; [proxy commitConfiguration: c interfaceName: _interfaceName authorization: nil reply: ^(NSError *e) { err = [e retain]; }]; [proxy release]; if (error) *error = [err autorelease]; return err == nil;
}
- (BOOL)setPower:(BOOL)on error:(NSError **)error
{
	__block NSError *err = nil; id proxy = [self _proxy]; [proxy setWiFiPowerState: on interfaceName: _interfaceName authorization: nil reply: ^(NSError *e) { err = [e retain]; }]; [proxy release]; if (error) *error = [err autorelease]; return err == nil;
}
- (BOOL)setWLANChannel:(CWChannel *)c error:(NSError **)error
{
	__block NSError *err = nil; id proxy = [self _proxy]; [proxy setWiFiChannel: [c info] interfaceName: _interfaceName reply: ^(NSError *e) { err = [e retain]; }]; [proxy release]; if (error) *error = [err autorelease]; return err == nil;
}
- (NSSet *)scanForNetworksWithSSID:(NSData *)ssid includeHidden:(BOOL)hidden error:(NSError **)error
{
	__block NSArray *records = nil; __block NSError *err = nil; id proxy = [self _proxy];
	[proxy performScanWithChannels: nil ssidList: ssid ? @[ ssid ] : nil legacyScanSSID: nil includeHiddenNetworks: hidden mergeScanResults: NO maxAge: 0 maxMissCount: 0 maxWakeCount: 0 maxAutoJoinCount: 0 interfaceName: _interfaceName waitForWiFi: NO waitForBluetooth: NO token: 0 priority: 0
		reply: ^(NSError *e, NSArray *r) { err = [e retain]; records = [r retain]; }];
	[proxy release]; [err autorelease]; [records autorelease];
	if (err) { if (error) *error = err; return nil; }
	NSMutableSet *s = [NSMutableSet set]; for (NSDictionary *r in records) [s addObject: [[[CWNetwork alloc] initWithScanRecord: r] autorelease]]; return s;
}
- (NSSet *)scanForNetworksWithSSID:(NSData *)ssid error:(NSError **)error { return [self scanForNetworksWithSSID: ssid includeHidden: NO error: error]; }
- (NSSet *)scanForNetworksWithName:(NSString *)name includeHidden:(BOOL)hidden error:(NSError **)error { return [self scanForNetworksWithSSID: name ? [name dataUsingEncoding: NSUTF8StringEncoding] : nil includeHidden: hidden error: error]; }
- (NSSet *)scanForNetworksWithName:(NSString *)name error:(NSError **)error { return [self scanForNetworksWithName: name includeHidden: NO error: error]; }
- (NSSet *)cachedScanResults
{
	__block NSArray *records = nil; id proxy = [self _proxy];
	[proxy queryScanCacheWithChannels: nil ssidList: nil maxAge: 0 maxMissCount: 0 maxWakeCount: 0 maxAutoJoinCount: 0 interfaceName: _interfaceName reply: ^(NSError *e, NSArray *r) { records = [r retain]; }]; [proxy release]; [records autorelease];
	if (!records) return nil; NSMutableSet *s = [NSMutableSet set]; for (NSDictionary *r in records) [s addObject: [[[CWNetwork alloc] initWithScanRecord: r] autorelease]]; return s;
}
- (BOOL)associateToNetwork:(CWNetwork *)network password:(NSString *)password forceBSSID:(BOOL)force remember:(BOOL)remember possiblyHidden:(BOOL)hidden error:(NSError **)error
{
	__block NSError *err = nil; id proxy = [self _proxy];
	[proxy associateToWiFiNetwork: network password: password remember: remember possiblyHidden: hidden interfaceName: _interfaceName token: 0 priority: 0 authorization: nil reply: ^(NSError *e) { err = [e retain]; }]; [proxy release]; if (error) *error = [err autorelease]; else [err release]; return err == nil;
}
- (BOOL)associateToNetwork:(CWNetwork *)network password:(NSString *)password forceBSSID:(BOOL)force remember:(BOOL)remember error:(NSError **)error { return [self associateToNetwork: network password: password forceBSSID: force remember: remember possiblyHidden: NO error: error]; }
- (BOOL)associateToNetwork:(CWNetwork *)network password:(NSString *)password error:(NSError **)error { return [self associateToNetwork: network password: password forceBSSID: NO remember: YES possiblyHidden: NO error: error]; }
- (void)disassociate
{
	id proxy = [self _proxy]; [proxy disassociateForInterfaceName: _interfaceName token: 0 priority: 0 authorization: nil reply: ^(NSError *e) { }]; [proxy release];
}
- (NSString *)description { return [NSString stringWithFormat: @"<%@: %p> [interfaceName=%@]", NSStringFromClass([self class]), self, _interfaceName]; }
@end
