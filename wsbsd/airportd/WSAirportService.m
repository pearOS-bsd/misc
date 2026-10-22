#import "WSAirportService.h"
#import <objc/runtime.h>

NSString *const WSAirportServiceCoreWLAN = @"com.apple.corewlan-xpc";
NSString *const WSAirportServiceAirportd = @"com.apple.airportd";
static NSError *Err(NSInteger code, NSString *why) { return [NSError errorWithDomain: @"com.apple.wifi.apple80211API.error" code: code userInfo: @{ NSLocalizedFailureReasonErrorKey: why ?: @"error" }]; }

@interface WSClientRecord : NSObject { @public NSXPCConnection *conn; NSMutableSet *events; } @end
@implementation WSClientRecord @end

@implementation WSAirportService {
	id<WSWiFiBackend> _backend; NSString *_prefsPath; dispatch_queue_t _q; NSRecursiveLock *_lock; NSMutableArray *_known; NSMutableArray<WSClientRecord *> *_clients; NSArray<NSXPCListener *> *_listeners;
	BOOL _autoJoin; NSMutableSet *_joining; long long _autoHotspotMode;
}
@synthesize autoJoinEnabled = _autoJoin;
- (instancetype)initWithBackend:(id<WSWiFiBackend>)backend preferences:(NSString *)path
{
	if ((self = [super init])) {
		_backend = backend; _prefsPath = [path copy] ?: @"/Library/Preferences/com.apple.wifi.known-networks.plist"; _q = dispatch_queue_create("com.apple.airportd.server.command.q", DISPATCH_QUEUE_SERIAL); _lock = [NSRecursiveLock new]; _clients = [NSMutableArray array]; _joining = [NSMutableSet set]; _autoJoin = YES;
		NSArray *k = [NSArray arrayWithContentsOfFile: _prefsPath]; _known = [NSMutableArray array]; for (NSDictionary *d in k) [_known addObject: [d mutableCopy]];
		WsbsdXPCInstallDefaultReplies([self class], @protocol(WSAirportXPCRequests));
		__weak WSAirportService *me = self; backend.eventHandler = ^(NSString *ev, NSString *iface, NSDictionary *info) { [me _event: ev interface: iface info: info]; };
	}
	return self;
}
- (void)startListening
{
	NSMutableArray *ls = [NSMutableArray array];
	for (NSString *n in @[ WSAirportServiceCoreWLAN, WSAirportServiceAirportd ]) { NSXPCListener *l = [[NSXPCListener alloc] initWithMachServiceName: n]; [l setDelegate: self]; [l resume]; [ls addObject: l]; }
	_listeners = ls; dispatch_async(_q, ^{ [self _autoJoinAll]; });
}
- (void)stopListening { for (NSXPCListener *l in _listeners) [l invalidate]; _listeners = nil; }
- (BOOL)listener:(NSXPCListener *)l shouldAcceptNewConnection:(NSXPCConnection *)c
{
	[c setExportedInterface: [NSXPCInterface interfaceWithProtocol: @protocol(WSAirportXPCRequests)]]; [c setExportedObject: self]; [c setRemoteObjectInterface: [NSXPCInterface interfaceWithProtocol: @protocol(WSAirportXPCEvents)]];
	WSClientRecord *r = [WSClientRecord new]; r->conn = c; r->events = [NSMutableSet set]; [self _locked: ^{ [_clients addObject: r]; }];
	__weak WSAirportService *me = self; void (^drop)(void) = ^{ [me _drop: r]; }; [c setInvalidationHandler: drop]; [c setInterruptionHandler: drop]; return YES;
}
- (void)_locked:(void (^)(void))b { [_lock lock]; b(); [_lock unlock]; }
- (void)_drop:(WSClientRecord *)r { [self _locked: ^{ [_clients removeObject: r]; }]; }
- (WSClientRecord *)_current { NSXPCConnection *c = [NSXPCConnection currentConnection]; for (WSClientRecord *r in _clients) if (r->conn == c) return r; return nil; }

/* ---- events ---- */
static long long TypeForEvent(NSString *e) { NSDictionary *m = @{ @"power": @1, @"ssid": @2, @"bssid": @3, @"countryCode": @4, @"link": @5, @"linkQuality": @6, @"mode": @7, @"scanCache": @8 }; return [m[e] longLongValue]; }
- (void)_event:(NSString *)ev interface:(NSString *)n info:(NSDictionary *)info
{
	dispatch_async(_q, ^{ [_lock lock];
		long long t = TypeForEvent(ev);
		for (WSClientRecord *r in _clients) { if (![r->events containsObject: @(t)]) continue; id p = [r->conn remoteObjectProxyWithErrorHandler: ^(NSError *e) { }];
			if ([ev isEqual: @"power"]) [p powerStateDidChangeForWiFiInterfaceWithName: n]; else if ([ev isEqual: @"ssid"]) [p ssidDidChangeForWiFiInterfaceWithName: n]; else if ([ev isEqual: @"bssid"]) [p bssidDidChangeForWiFiInterfaceWithName: n];
			else if ([ev isEqual: @"countryCode"]) [p countryCodeDidChangeForWiFiInterfaceWithName: n]; else if ([ev isEqual: @"link"]) [p linkDidChangeForWiFiInterfaceWithName: n]; else if ([ev isEqual: @"mode"]) [p modeDidChangeForWiFiInterfaceWithName: n];
			else if ([ev isEqual: @"scanCache"]) [p scanCacheUpdatedForWiFiInterfaceWithName: n]; else if ([ev isEqual: @"linkQuality"]) [p linkQualityDidChangeForWiFiInterfaceWithName: n rssi: [info[@"rssi"] longLongValue] transmitRate: [info[@"rate"] doubleValue]]; }
		if ([ev isEqual: @"link"] || [ev isEqual: @"power"]) [self _autoJoinAll]; [_lock unlock];
	});
}
- (void)startMonitoringEventWithType:(long long)t reply:(WSReplyVoid)reply { [self _locked: ^{ [[self _current]->events addObject: @(t)]; }]; reply(nil); }
- (void)stopMonitoringEventWithType:(long long)t reply:(WSReplyVoid)reply { [self _locked: ^{ [[self _current]->events removeObject: @(t)]; }]; reply(nil); }
- (void)stopMonitoringAllEventsAndReply:(WSReplyVoid)reply { [self _locked: ^{ [[self _current]->events removeAllObjects]; }]; reply(nil); }

/* ---- queries ---- */
- (NSString *)_name:(CWFRequestParameters *)p { NSString *n = [p interfaceName]; return n ?: [[_backend interfaceNames] firstObject]; }
- (NSDictionary *)_state:(CWFRequestParameters *)p { return [_backend stateForInterface: [self _name: p]]; }
- (void)queryInterfaceNamesWithRequestParams:(id)p reply:(WSReplyObject)reply { reply(nil, [_backend interfaceNames]); }
- (void)queryVirtualInterfaceNamesWithRequestParams:(id)p reply:(WSReplyObject)reply { reply(nil, @[ ]); }
- (void)queryPowerWithRequestParams:(id)p reply:(WSReplyBool)reply { NSDictionary *s = [self _state: p]; reply(s ? nil : Err(-3900, @"no such interface"), [s[WSWiFiStatePower] boolValue]); }
- (void)querySSIDWithRequestParams:(id)p reply:(WSReplyObject)reply { reply(nil, [self _state: p][WSWiFiStateSSID]); }
- (void)queryBSSIDWithRequestParams:(id)p reply:(WSReplyObject)reply { reply(nil, [self _state: p][WSWiFiStateBSSID]); }
- (void)queryRSSIWithRequestParams:(id)p reply:(WSReplyInteger)reply { reply(nil, [[self _state: p][WSWiFiStateRSSI] longLongValue]); }
- (void)queryNoiseWithRequestParams:(id)p reply:(WSReplyInteger)reply { reply(nil, [[self _state: p][WSWiFiStateNoise] longLongValue]); }
- (void)queryTxRateWithRequestParams:(id)p reply:(WSReplyDouble)reply { reply(nil, [[self _state: p][WSWiFiStateTxRate] doubleValue]); }
- (void)queryTxPowerWithRequestParams:(id)p reply:(WSReplyInteger)reply { reply(nil, [self _state: p][WSWiFiStateSSID] ? 1496 : 0); }
- (void)queryCountryCodeWithRequestParams:(id)p reply:(WSReplyObject)reply { reply(nil, [self _state: p][WSWiFiStateCountry]); }
- (void)queryHardwareMACAddressWithRequestParams:(id)p reply:(WSReplyObject)reply { reply(nil, [self _state: p][WSWiFiStateMAC]); }
- (void)queryMACAddressWithRequestParams:(id)p reply:(WSReplyObject)reply { reply(nil, [self _state: p][WSWiFiStateMAC]); }
- (void)queryChannelWithRequestParams:(id)p reply:(WSReplyObject)reply { NSDictionary *s = [self _state: p]; reply(nil, s[WSWiFiStateChannel] ? @{ @"CHANNEL": s[WSWiFiStateChannel], @"CHANNEL_FLAGS": s[WSWiFiStateChannelFlags] ?: @0 } : nil); }
- (void)queryOpModeWithRequestParams:(id)p reply:(WSReplyInteger)reply { reply(nil, [[self _state: p][WSWiFiStateOpMode] longLongValue]); }
- (void)queryPHYModeWithRequestParams:(id)p reply:(WSReplyInteger)reply { NSDictionary *r = [self _state: p][WSWiFiStateScanRecord]; reply(nil, r ? (r[@"HE_CAP"] ? 6 : r[@"VHT_CAPS"] ? 5 : r[@"HT_CAPS_IE"] ? 4 : 3) : 0); }
- (void)queryIsNetworkServiceEnabledWithRequestParams:(id)p reply:(WSReplyBool)reply { reply(nil, [self _state: p] != nil); }
- (void)queryCurrentScanResultWithRequestParams:(id)p reply:(WSReplyObject)reply { reply(nil, [self _state: p][WSWiFiStateScanRecord]); }
- (void)queryHardwareSupportedChannelsWithRequestParams:(id)p reply:(WSReplyObject)reply { reply(nil, [_backend supportedChannelsForInterface: [self _name: p]]); }
- (void)querySupportedChannelsWithCountryCode:(id)cc requestParams:(id)p reply:(WSReplyObject)reply { reply(nil, [_backend supportedChannelsForInterface: [self _name: p]]); }
- (void)queryScanCacheWithChannels:(id)ch ssidList:(id)ssids maxAge:(double)age maxMissCount:(long long)a maxWakeCount:(long long)b maxAutoJoinCount:(long long)c interfaceName:(NSString *)n reply:(WSReplyObject)reply
{ NSError *e = nil; NSArray *r = [_backend scanInterface: n ?: [[_backend interfaceNames] firstObject] ssid: nil error: &e]; reply(e, r); }
- (void)confirmAPIAccessWithRequestType:(long long)t info:(id)info reply:(WSReplyBool)reply { reply(nil, YES); }

/* ---- actions ---- */
- (void)setWiFiPowerState:(BOOL)on interfaceName:(NSString *)n authorization:(id)auth reply:(WSReplyVoid)reply { NSError *e = nil; [_backend setPower: on forInterface: n ?: [[_backend interfaceNames] firstObject] error: &e]; reply(e); }
- (void)performScanWithChannels:(id)ch ssidList:(NSArray *)ssids legacyScanSSID:(id)legacy includeHiddenNetworks:(BOOL)hidden mergeScanResults:(BOOL)merge maxAge:(double)age maxMissCount:(long long)a maxWakeCount:(long long)b maxAutoJoinCount:(long long)c interfaceName:(NSString *)n waitForWiFi:(BOOL)w waitForBluetooth:(BOOL)bt token:(long long)tok priority:(long long)prio reply:(WSReplyObject)reply
{ NSError *e = nil; NSArray *r = [_backend scanInterface: n ?: [[_backend interfaceNames] firstObject] ssid: [ssids firstObject] error: &e]; reply(e, r); }
- (void)associateToWiFiNetwork:(CWNetwork *)net password:(NSString *)pw remember:(BOOL)remember possiblyHidden:(BOOL)hidden interfaceName:(NSString *)n token:(long long)tok priority:(long long)prio authorization:(id)auth reply:(WSReplyVoid)reply
{
	NSString *iface = n ?: [[_backend interfaceNames] firstObject]; NSError *e = nil; BOOL ok = [_backend associateInterface: iface toRecord: [net scanRecord] password: pw error: &e];
	if (ok && remember) [self _locked: ^{ [self _rememberNetwork: net password: pw manual: YES]; }];
	reply(ok ? nil : (e ?: Err(-3900, @"association failed")));
}
- (void)disassociateForInterfaceName:(NSString *)n token:(long long)tok priority:(long long)prio authorization:(id)auth reply:(WSReplyVoid)reply { [_backend disassociateInterface: n ?: [[_backend interfaceNames] firstObject]]; reply(nil); }
- (void)setWiFiChannel:(id)ch interfaceName:(NSString *)n reply:(WSReplyVoid)reply { reply(Err(-3903, @"not supported")); }

/* ---- known networks ---- */
- (void)_save { NSData *d = [NSPropertyListSerialization dataWithPropertyList: _known format: NSPropertyListXMLFormat_v1_0 options: 0 error: nil]; [[NSFileManager defaultManager] createDirectoryAtPath: [_prefsPath stringByDeletingLastPathComponent] withIntermediateDirectories: YES attributes: nil error: nil]; [d writeToFile: _prefsPath atomically: YES]; chmod([_prefsPath fileSystemRepresentation], 0600); }
- (NSMutableDictionary *)_profileFor:(NSData *)ssid { for (NSMutableDictionary *p in _known) if ([p[@"ssid"] isEqual: ssid]) return p; return nil; }
- (void)_rememberNetwork:(CWNetwork *)net password:(NSString *)pw manual:(BOOL)manual
{
	NSData *ssid = [net ssidData]; if (!ssid) return; NSMutableDictionary *p = [self _profileFor: ssid];
	if (!p) { p = [@{ @"ssid": ssid, @"added": [NSDate date] } mutableCopy]; [_known insertObject: p atIndex: 0]; }
	p[@"securityType"] = @([net securityType]); if (pw) p[@"password"] = pw; p[manual ? @"lastManualJoinAt" : @"lastAutoJoinAt"] = [NSDate date]; if ([net isPersonalHotspot]) p[@"hotspot"] = @YES; [self _save];
}
- (CWNetworkProfile *)_profileObject:(NSDictionary *)d
{
	CWMutableNetworkProfile *p = [[CWMutableNetworkProfile alloc] init]; [p setSsidData: d[@"ssid"]]; [p setSecurityType: [d[@"securityType"] unsignedLongLongValue]]; [p setLastAutoJoinAt: d[@"lastAutoJoinAt"]]; [p setLastManualJoinAt: d[@"lastManualJoinAt"]]; [p setAddedAt: d[@"added"]]; [p setDisabled: [d[@"disabled"] boolValue]];
	[p setIsPersonalHotspot: [d[@"hotspot"] boolValue]]; [p setHiddenNetwork: [d[@"hidden"] boolValue]]; return p;
}
- (void)queryAllWiFiProfilesAndReply:(WSReplyObject)reply { __block NSMutableArray *a = [NSMutableArray array]; [self _locked: ^{ for (NSDictionary *d in _known) [a addObject: [self _profileObject: d]]; }]; reply(nil, a); }
- (void)queryConfigurationWithInterfaceName:(NSString *)n reply:(WSReplyObject)reply
{
	__block CWMutableConfiguration *c = [CWMutableConfiguration new]; [self _locked: ^{ NSMutableArray *a = [NSMutableArray array]; for (NSDictionary *d in _known) [a addObject: [self _profileObject: d]]; [c setNetworkProfiles: [NSOrderedSet orderedSetWithArray: a]]; }];
	reply(nil, c);
}
- (void)commitConfiguration:(CWConfiguration *)c interfaceName:(NSString *)n authorization:(id)auth reply:(WSReplyVoid)reply
{
	[self _locked: ^{ NSMutableArray *out = [NSMutableArray array]; for (CWNetworkProfile *p in [c networkProfiles]) { NSMutableDictionary *old = [self _profileFor: [p ssidData]]; NSMutableDictionary *d = old ?: [NSMutableDictionary dictionary];
		d[@"ssid"] = [p ssidData]; d[@"securityType"] = @([p securityType]); if ([p addedAt]) d[@"added"] = [p addedAt]; if ([p lastAutoJoinAt]) d[@"lastAutoJoinAt"] = [p lastAutoJoinAt]; if ([p lastManualJoinAt]) d[@"lastManualJoinAt"] = [p lastManualJoinAt]; d[@"disabled"] = @([p disabled]); d[@"hidden"] = @([p hiddenNetwork]); [out addObject: d]; }
		_known = out; [self _save]; }];
	reply(nil); dispatch_async(_q, ^{ [self _autoJoinAll]; });
}
- (void)removeWiFiProfileWithID:(id)ident event:(long long)ev authorization:(id)auth reply:(WSReplyVoid)reply { reply(nil); }
- (void)setAutoJoinEnabled:(BOOL)on reply:(WSReplyVoid)reply { _autoJoin = on; reply(nil); if (on) dispatch_async(_q, ^{ [self _autoJoinAll]; }); }
- (void)queryAutoHotspotModeAndReply:(WSReplyInteger)reply { reply(nil, _autoHotspotMode); }
- (void)setAutoHotspotMode:(long long)m reply:(WSReplyVoid)reply { _autoHotspotMode = m; reply(nil); }
- (void)queryAutoJoinTemporarilyDisabledAndReply:(id)reply { ((void (^)(NSError *, BOOL, NSDate *))reply)(nil, NO, nil); }
- (void)startAutoJoinForInterfaceName:(NSString *)n reply:(WSReplyVoid)reply { reply(nil); dispatch_async(_q, ^{ [self _autoJoinAll]; }); }

/* ---- auto-join: the known networks in range, the preferred ones first; a Personal Hotspot only when nothing else is in range ---- */
- (void)autoJoinAll { dispatch_async(_q, ^{ [self _autoJoinAll]; }); }
- (void)_autoJoinAll { if (!_autoJoin) return; [_lock lock]; for (NSString *n in [_backend interfaceNames]) [self _autoJoin: n]; [_lock unlock]; }
- (void)_autoJoin:(NSString *)iface
{
	if (getenv("WSBSD_AIRPORT_DEBUG")) fprintf(stderr, "airportd: auto-join %s (known %lu)\n", [iface UTF8String], (unsigned long)[_known count]);
	NSDictionary *st = [_backend stateForInterface: iface]; if (![st[WSWiFiStatePower] boolValue] || [st[WSWiFiStateLinkUp] boolValue] || [_joining containsObject: iface]) return;
	[_joining addObject: iface]; NSError *e = nil; NSArray *records = [_backend scanInterface: iface ssid: nil error: &e]; NSDictionary *chosen = nil; NSMutableDictionary *chosenProfile = nil; BOOL chosenHotspot = YES; NSUInteger chosenRank = NSUIntegerMax; int chosenRSSI = -999;
	for (NSDictionary *rec in records) {
		NSMutableDictionary *p = [self _profileFor: rec[@"SSID"]]; if (!p || [p[@"disabled"] boolValue]) continue; CWNetwork *net = [[CWNetwork alloc] initWithScanRecord: rec]; unsigned long long want = [p[@"securityType"] unsignedLongLongValue];
		if (want && [net securityType] != want && ![net isOpen] ) { if (!([net securityType] & want)) continue; }
		BOOL hot = [net isPersonalHotspot]; NSUInteger rank = [_known indexOfObjectIdenticalTo: p]; int rssi = [rec[@"RSSI"] intValue];
		BOOL better = !chosen || (chosenHotspot && !hot) || (hot == chosenHotspot && (rank < chosenRank || (rank == chosenRank && rssi > chosenRSSI)));
		if (better) { chosen = rec; chosenProfile = p; chosenHotspot = hot; chosenRank = rank; chosenRSSI = rssi; }
	}
	if (getenv("WSBSD_AIRPORT_DEBUG")) fprintf(stderr, "airportd: %lu records, chosen %s error %s\n", (unsigned long)[records count], chosen ? [[chosen[@"SSID_STR"] description] UTF8String] : "none", e ? [[e description] UTF8String] : "-");
	if (chosen) { CWNetwork *net = [[CWNetwork alloc] initWithScanRecord: chosen]; NSString *pw = chosenProfile[@"password"];
		if ([_backend associateInterface: iface toRecord: chosen password: pw error: &e]) { chosenProfile[@"lastAutoJoinAt"] = [NSDate date]; [self _save]; } }
	[_joining removeObject: iface];
}
@end
