/* CWWiFiClient: the connection to airportd (service com.apple.corewlan-xpc) and the receiver of its events; CWInterface objects talk through it. */
#import <wsbsd/WSAirport.h>
#import <objc/runtime.h>
#import <objc/message.h>

NSString *const WSAirportServiceCoreWLAN = @"com.apple.corewlan-xpc";
NSString *const WSAirportServiceAirportd = @"com.apple.airportd";

static CWFRequestParameters *Params(NSString *interfaceName)
{
	CWFRequestParameters *p = [[[CWFRequestParameters alloc] init] autorelease]; [p setInterfaceName: interfaceName]; [p setUUID: [NSUUID UUID]]; return p;
}

@implementation CWXPCClient (Impl)
- (NSXPCConnection *)xpcConnection { return _xpcConnection; }
- (void)setXpcConnection:(NSXPCConnection *)c { if (_xpcConnection != c) { [_xpcConnection release]; _xpcConnection = [c retain]; } }
- (void)dealloc { [_xpcConnection invalidate]; [_xpcConnection release]; [super dealloc]; }
@end

@implementation CWWiFiClient (Impl)
static CWWiFiClient *gShared;
+ (CWWiFiClient *)sharedWiFiClient { static dispatch_once_t once; dispatch_once(&once, ^{ gShared = [[CWWiFiClient alloc] init]; }); return gShared; }
+ (CWWiFiClient *)legacyWiFiClient { return [self sharedWiFiClient]; }
+ (NSArray *)interfaceNames { return [[self sharedWiFiClient] interfaceNames]; }
+ (NSArray *)virtualInterfaceNames { return nil; }
- (instancetype)init
{
	if ((self = [super init])) {
		_eventList = [[NSMutableSet alloc] init]; _eventQueue = dispatch_queue_create("com.apple.corewlan.events", DISPATCH_QUEUE_SERIAL); _mutex = dispatch_queue_create("com.apple.corewlan.client", DISPATCH_QUEUE_SERIAL); _interfaceMap = [[NSMutableDictionary alloc] init];
		_xpcClient = [[CWXPCClient alloc] init]; NSXPCConnection *c = [[NSXPCConnection alloc] initWithMachServiceName: WSAirportServiceCoreWLAN options: 0];
		[c setRemoteObjectInterface: [NSXPCInterface interfaceWithProtocol: @protocol(WSAirportXPCRequests)]]; [c setExportedInterface: [NSXPCInterface interfaceWithProtocol: @protocol(WSAirportXPCEvents)]]; [c setExportedObject: self];
		CWWiFiClient *me = self; [c setInterruptionHandler: ^{ [me _connectionInterrupted]; }]; [c setInvalidationHandler: ^{ [me _connectionInvalidated]; }]; [c resume]; [_xpcClient setXpcConnection: c]; [c release];
	}
	return self;
}
- (instancetype)initWithXPCClientType:(long long)t { return [self init]; }
- (instancetype)initForWiFiUserAgent { return [self init]; }
- (void)_connectionInterrupted { id d = _delegate; if ([d respondsToSelector: @selector(clientConnectionInterrupted)]) dispatch_async(_eventQueue, ^{ [d clientConnectionInterrupted]; }); }
- (void)_connectionInvalidated { id d = _delegate; if ([d respondsToSelector: @selector(clientConnectionInvalidated)]) dispatch_async(_eventQueue, ^{ [d clientConnectionInvalidated]; }); }
- (void)dealloc { [_eventList release]; [_xpcClient release]; [_interfaceMap release]; [super dealloc]; }
- (id)_proxy { return [[[_xpcClient xpcConnection] synchronousRemoteObjectProxyWithErrorHandler: ^(NSError *e) { }] retain]; }
- (NSArray *)interfaceNames
{
	__block NSArray *r = nil; id proxy = [self _proxy];
	[proxy queryInterfaceNamesWithRequestParams: Params(nil) reply: ^(NSError *e, NSArray *names) { r = [names retain]; }]; [proxy release];
	return [r autorelease];
}
- (NSArray *)interfaces { NSMutableArray *a = [NSMutableArray array]; for (NSString *n in [self interfaceNames]) { CWInterface *i = [self interfaceWithName: n]; if (i) [a addObject: i]; } return a; }
- (CWInterface *)interface { NSArray *n = [self interfaceNames]; return [n count] ? [self interfaceWithName: n[0]] : nil; }
- (CWInterface *)interfaceWithName:(NSString *)name
{
	if (!name) return [self interface]; if (![[self interfaceNames] containsObject: name]) return nil;
	return [[[CWInterface alloc] initWithInterfaceName: name xpcClient: _xpcClient legacy: _legacy] autorelease];
}
- (CWInterface *)interfaceWithRole:(long long)r { return [self interface]; }
- (BOOL)startMonitoringEventWithType:(CWEventType)type error:(NSError **)error
{
	__block NSError *err = nil; id proxy = [self _proxy]; if (type == CWEventTypeNone || type == CWEventTypeUnknown) { [proxy release]; if (error) *error = [NSError errorWithDomain: CWErrorDomain code: kCWInvalidParameterErr userInfo: nil]; return NO; }
	[proxy startMonitoringEventWithType: type reply: ^(NSError *e) { err = [e retain]; }]; [proxy release]; [_eventList addObject: @(type)]; if (error) *error = [err autorelease]; return err == nil;
}
- (BOOL)stopMonitoringEventWithType:(CWEventType)type error:(NSError **)error
{
	__block NSError *err = nil; id proxy = [self _proxy]; [proxy stopMonitoringEventWithType: type reply: ^(NSError *e) { err = [e retain]; }]; [proxy release]; [_eventList removeObject: @(type)]; if (error) *error = [err autorelease]; return err == nil;
}
- (BOOL)stopMonitoringAllEventsAndReturnError:(NSError **)error
{
	__block NSError *err = nil; id proxy = [self _proxy]; [proxy stopMonitoringAllEventsAndReply: ^(NSError *e) { err = [e retain]; }]; [proxy release]; [_eventList removeAllObjects]; if (error) *error = [err autorelease]; return err == nil;
}
- (id)delegate { return _delegate; } - (void)setDelegate:(id)d { _delegate = d; }
- (BOOL)legacy { return _legacy; } - (void)setLegacy:(BOOL)l { _legacy = l; }
- (void)_post:(NSString *)name object:(NSString *)iface userInfo:(NSDictionary *)ui { dispatch_async(dispatch_get_main_queue(), ^{ [[NSNotificationCenter defaultCenter] postNotificationName: name object: iface userInfo: ui]; }); }
#define EVENT(sel, notif) - (void)sel:(NSString *)n { id d = _delegate; if ([d respondsToSelector: @selector(sel:)]) dispatch_async(_eventQueue, ^{ [d sel: n]; }); [self _post: notif object: n userInfo: nil]; }
EVENT(ssidDidChangeForWiFiInterfaceWithName, CWSSIDDidChangeNotification)
EVENT(bssidDidChangeForWiFiInterfaceWithName, CWBSSIDDidChangeNotification)
EVENT(powerStateDidChangeForWiFiInterfaceWithName, CWPowerDidChangeNotification)
EVENT(modeDidChangeForWiFiInterfaceWithName, CWModeDidChangeNotification)
EVENT(linkDidChangeForWiFiInterfaceWithName, CWLinkDidChangeNotification)
EVENT(countryCodeDidChangeForWiFiInterfaceWithName, CWCountryCodeDidChangeNotification)
EVENT(scanCacheUpdatedForWiFiInterfaceWithName, CWScanCacheDidUpdateNotification)
- (void)linkQualityDidChangeForWiFiInterfaceWithName:(NSString *)n rssi:(long long)rssi transmitRate:(double)rate
{
	id d = _delegate; if ([d respondsToSelector: @selector(linkQualityDidChangeForWiFiInterfaceWithName:rssi:transmitRate:)]) dispatch_async(_eventQueue, ^{ [d linkQualityDidChangeForWiFiInterfaceWithName: n rssi: rssi transmitRate: rate]; });
	[self _post: CWLinkQualityDidChangeNotification object: n userInfo: @{ CWLinkQualityNotificationRSSIKey: @(rssi), CWLinkQualityNotificationTransmitRateKey: @(rate) }];
}
- (long long)autoHotspotMode { __block long long r = 0; id proxy = [self _proxy]; [proxy queryAutoHotspotModeAndReply: ^(NSError *e, long long m) { r = m; }]; [proxy release]; return r; }
- (BOOL)setAutoHotspotMode:(long long)m error:(NSError **)error { __block NSError *err = nil; id proxy = [self _proxy]; [proxy setAutoHotspotMode: m reply: ^(NSError *e) { err = [e retain]; }]; [proxy release]; if (error) *error = [err autorelease]; return err == nil; }
- (BOOL)autoJoinTemporarilyDisabled { __block BOOL r = NO; id proxy = [self _proxy]; [proxy queryAutoJoinTemporarilyDisabledAndReply: ^(NSError *e, BOOL v, NSDate *until) { r = v; }]; [proxy release]; return r; }
- (NSDate *)autoJoinTemporarilyDisabledUntilDate { __block NSDate *r = nil; id proxy = [self _proxy]; [proxy queryAutoJoinTemporarilyDisabledAndReply: ^(NSError *e, BOOL v, NSDate *until) { r = [until retain]; }]; [proxy release]; return [r autorelease]; }
- (BOOL)setAutoJoinEnabled:(BOOL)on error:(NSError **)error { __block NSError *err = nil; id proxy = [self _proxy]; [proxy setAutoJoinEnabled: on reply: ^(NSError *e) { err = [e retain]; }]; [proxy release]; if (error) *error = [err autorelease]; return err == nil; }
- (BOOL)setAutoJoinTemporarilyDisabled:(BOOL)d error:(NSError **)error { __block NSError *err = nil; id proxy = [self _proxy]; [proxy setAutoJoinTemporarilyDisabled: d untilDate: nil reply: ^(NSError *e) { err = [e retain]; }]; [proxy release]; if (error) *error = [err autorelease]; return err == nil; }
- (NSArray *)queryAllWiFiProfilesAndReturnError:(NSError **)error { __block NSArray *r = nil; id proxy = [self _proxy]; [proxy queryAllWiFiProfilesAndReply: ^(NSError *e, NSArray *p) { r = [p retain]; }]; [proxy release]; return [r autorelease]; }
@end
