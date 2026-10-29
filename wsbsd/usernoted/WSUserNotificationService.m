#import "WSUserNotificationService.h"
#import <wsbsd/NSXPCConnection.h>
#import <Foundation/NSXPCConnection.h>

@interface WSUNClient : NSObject { @public NSXPCConnection *conn; NSString *bundle, *name, *path, *role; BOOL foreground; } @end
@implementation WSUNClient @end

@implementation WSUserNotificationService
{ NSString *_dir; NSMutableDictionary *_db; NSMutableArray *_clients; NSMutableArray *_pending; NSXPCListener *_listener; BOOL _focus; NSMutableDictionary *_responses; NSMutableDictionary *_badged; }
- (instancetype)initWithDirectory:(NSString *)dir
{
	if (!(self = [super init])) return nil;
	_dir = [dir copy]; [[NSFileManager defaultManager] createDirectoryAtPath: _dir withIntermediateDirectories: YES attributes: nil error: NULL];
	_db = [NSMutableDictionary dictionaryWithContentsOfFile: [_dir stringByAppendingPathComponent: @"db.plist"]] ?: [NSMutableDictionary dictionary];
	if (!_db[@"auth"]) _db[@"auth"] = [NSMutableDictionary dictionary]; else _db[@"auth"] = [_db[@"auth"] mutableCopy];
	if (!_db[@"delivered"]) _db[@"delivered"] = [NSMutableArray array]; else _db[@"delivered"] = [_db[@"delivered"] mutableCopy];
	_focus = [_db[@"focus"] boolValue]; _clients = [NSMutableArray array]; _pending = [NSMutableArray array]; _responses = [NSMutableDictionary dictionary];
	return self;
}
- (void)startListening { [NSTimer scheduledTimerWithTimeInterval: 5 target: self selector: @selector(_badgeTimer:) userInfo: nil repeats: YES]; _listener = [[NSXPCListener alloc] initWithMachServiceName: WSUserNotificationServiceName]; [_listener setDelegate: self]; [_listener resume]; }
- (void)_save { _db[@"focus"] = @(_focus); [_db writeToFile: [_dir stringByAppendingPathComponent: @"db.plist"] atomically: YES]; }
- (BOOL)listener:(NSXPCListener *)l shouldAcceptNewConnection:(NSXPCConnection *)c
{
	[c setExportedInterface: [NSXPCInterface interfaceWithProtocol: @protocol(WSUserNotificationRequests)]]; [c setExportedObject: self]; [c setRemoteObjectInterface: [NSXPCInterface interfaceWithProtocol: @protocol(WSUserNotificationEvents)]];
	WSUNClient *r = [WSUNClient new]; r->conn = c; @synchronized (self) { [_clients addObject: r]; }
	__weak WSUserNotificationService *me = self; __weak WSUNClient *wr = r; void (^drop)(void) = ^{ WSUserNotificationService *s = me; WSUNClient *k = wr; if (s && k) @synchronized (s) { [s->_clients removeObject: k]; } };
	[c setInvalidationHandler: drop]; [c setInterruptionHandler: drop]; return YES;
}
- (WSUNClient *)_me { NSXPCConnection *c = [NSXPCConnection currentConnection]; @synchronized (self) { for (WSUNClient *r in _clients) if (r->conn == c) return r; } return nil; }
- (void)registerClientWithInfo:(NSDictionary *)info reply:(void (^)(BOOL))reply
{
	WSUNClient *r = [self _me]; if (r) { r->bundle = info[@"bundle"]; r->name = info[@"name"]; r->path = info[@"path"]; r->role = info[@"role"] ?: @"app"; r->foreground = [info[@"foreground"] boolValue]; }
	if (reply) reply(r != nil);
	NSArray *queued = nil; @synchronized (self) { queued = _responses[r->bundle]; [_responses removeObjectForKey: r->bundle ?: @""]; }       /* responses to a banner clicked while the application was not running */
	for (NSArray *q in queued) [[r->conn remoteObjectProxy] didReceiveResponse: q[0] action: q[1]];
}
- (void)setForeground:(BOOL)fg { WSUNClient *r = [self _me]; if (r) r->foreground = fg; }
/* the applications of the system and of this project need no question (the Mac does not ask for its own either); the others are authorised when they ask, unless WSBSD_UN_AUTH=deny */
- (BOOL)_trusted:(NSString *)b { return [b hasPrefix: @"com.apple."] || [b hasPrefix: @"org.wsbsd."]; }
- (NSInteger)_status:(NSString *)b { NSDictionary *a = _db[@"auth"][b]; if (a) return [a[@"status"] integerValue]; return [self _trusted: b] ? 2 : 0; }
- (void)requestAuthorization:(NSUInteger)options reply:(void (^)(BOOL))reply
{
	WSUNClient *r = [self _me]; NSString *b = r->bundle ?: @""; NSInteger s;
	@synchronized (self) { s = [self _status: b]; if (s == 0) { s = getenv("WSBSD_UN_AUTH") && !strcmp(getenv("WSBSD_UN_AUTH"), "deny") ? 1 : 2; ((NSMutableDictionary *)_db[@"auth"])[b] = @{ @"status": @(s), @"options": @(options) }; [self _save]; } }
	if (reply) reply(s == 2);
}
- (void)authorizationStatusWithReply:(void (^)(NSInteger, NSUInteger))reply { WSUNClient *r = [self _me]; NSString *b = r->bundle ?: @""; NSInteger s; NSUInteger o = 7; @synchronized (self) { s = [self _status: b]; o = [_db[@"auth"][b][@"options"] unsignedIntegerValue] ?: 7; } if (reply) reply(s, o); }

- (NSMutableDictionary *)_record:(NSDictionary *)n for:(WSUNClient *)r
{
	NSMutableDictionary *m = [n mutableCopy]; m[@"bundle"] = r->bundle ?: @""; m[@"appName"] = r->name ?: r->bundle ?: @""; m[@"appPath"] = r->path ?: @""; m[@"uid"] = [NSString stringWithFormat: @"%@|%@", m[@"bundle"], n[@"id"] ?: [[NSUUID UUID] UUIDString]];
	if (!m[@"id"]) m[@"id"] = [[m[@"uid"] componentsSeparatedByString: @"|"] lastObject]; m[@"date"] = [NSDate date]; m[@"repeats"] = n[@"repeats"] ?: @NO; return m;
}
- (void)postNotification:(NSDictionary *)n reply:(void (^)(NSString *))reply
{
	WSUNClient *r = [self _me]; NSString *b = r->bundle ?: @""; if ([self _status: b] != 2) { if (reply) reply(@"notifications are not allowed"); return; }
	NSMutableDictionary *m = [self _record: n for: r]; NSNumber *iv = n[@"interval"];
	if (!iv) { [self _fire: m]; if (reply) reply(nil); return; }
	@synchronized (self) { [self _removePendingUID: m[@"uid"]]; [_pending addObject: m]; }
	[self performSelectorOnMainThread: @selector(_schedule:) withObject: m waitUntilDone: NO];
	if (reply) reply(nil);
}
- (void)_schedule:(NSDictionary *)m { [NSTimer scheduledTimerWithTimeInterval: MAX(0.01, [m[@"interval"] doubleValue]) target: self selector: @selector(_due:) userInfo: m repeats: [m[@"repeats"] boolValue]]; }
- (void)_due:(NSTimer *)t
{
	NSDictionary *m = [t userInfo]; BOOL still; @synchronized (self) { still = [_pending containsObject: m]; if (still && ![m[@"repeats"] boolValue]) [_pending removeObject: m]; }
	if (!still) { [t invalidate]; return; } NSMutableDictionary *c = [m mutableCopy]; c[@"date"] = [NSDate date]; [self _fire: c];
}
- (void)_removePendingUID:(NSString *)uid { for (NSInteger i = (NSInteger)_pending.count - 1; i >= 0; i--) if ([_pending[i][@"uid"] isEqual: uid]) [_pending removeObjectAtIndex: i]; }
/* the arbitration: the application in the foreground decides (willPresent), Focus keeps the banner away, the shell draws */
- (void)_fire:(NSMutableDictionary *)m
{
	WSUNClient *app = nil; NSMutableArray *shells = [NSMutableArray array]; @synchronized (self) { for (WSUNClient *c in _clients) { if ([c->role isEqual: @"shell"]) [shells addObject: c]; else if ([c->bundle isEqual: m[@"bundle"]] && c->foreground) app = c; } }
	void (^finish)(NSUInteger) = ^(NSUInteger options) {          // 1 badge, 2 sound, 4 alert (banner), 8 list, 16 banner
		BOOL banner = (options & (4 | 16)) != 0 && !self->_focus, list = (options & (4 | 8)) != 0 || self->_focus;
		if (list) @synchronized (self) { NSMutableArray *d = self->_db[@"delivered"]; for (NSInteger i = (NSInteger)d.count - 1; i >= 0; i--) if ([d[i][@"uid"] isEqual: m[@"uid"]]) [d removeObjectAtIndex: i]; [d insertObject: m atIndex: 0]; [self _save]; [self _syncBadges: NO]; }
		for (WSUNClient *s in shells) { if (banner) [[s->conn remoteObjectProxy] presentBanner: m]; if (list) [[s->conn remoteObjectProxy] listChanged]; }
	};
	if (app) {
		__block BOOL done = NO; NSLock *lk = [NSLock new]; void (^once)(NSUInteger) = ^(NSUInteger o) { [lk lock]; BOOL first = !done; done = YES; [lk unlock]; if (first) finish(o); };
		[[app->conn remoteObjectProxy] willPresentNotification: m reply: ^(NSUInteger o) { once(o); }];
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_global_queue(0, 0), ^{ once(4); });        // a silent delegate: the default is the alert
	} else finish(4);
}
- (NSArray *)_ofBundle:(NSString *)b in:(NSArray *)a { NSMutableArray *o = [NSMutableArray array]; for (NSDictionary *n in a) if ([n[@"bundle"] isEqual: b]) [o addObject: n]; return o; }
- (void)deliveredWithReply:(void (^)(NSArray *))reply { WSUNClient *r = [self _me]; NSArray *a; @synchronized (self) { a = [self _ofBundle: r->bundle in: _db[@"delivered"]]; } if (reply) reply(a); }
- (void)pendingWithReply:(void (^)(NSArray *))reply { WSUNClient *r = [self _me]; NSArray *a; @synchronized (self) { a = [self _ofBundle: r->bundle in: _pending]; } if (reply) reply(a); }
/* the Dock badge of an application: the number of its notifications in the list (what the Mac shows when the application may badge its icon); the Dock listens for com.wsbsd.dock.badge (the application's path and the count). Sent when a count changes, and every 5 s for all of them again (the Dock may have started later) */
- (void)_syncBadges:(BOOL)force
{
	@synchronized (self) {
		if (!_badged) _badged = [NSMutableDictionary dictionary];
		NSMutableDictionary *counts = [NSMutableDictionary dictionary];
		for (NSDictionary *n in _db[@"delivered"]) { NSString *p = n[@"appPath"]; if (![p length]) continue; NSDictionary *a = _db[@"auth"][n[@"bundle"]]; if (a && !([a[@"options"] unsignedIntegerValue] & 1)) continue; counts[p] = @([counts[p] integerValue] + 1); }
		NSMutableSet *paths = [NSMutableSet setWithArray: [counts allKeys]]; [paths addObjectsFromArray: [_badged allKeys]];
		for (NSString *p in paths) {
			NSNumber *c = counts[p] ?: @0, *o = _badged[p];
			if (!force && o && [o isEqual: c]) continue; if (!o && [c integerValue] == 0 && !force) continue;
			_badged[p] = c; [[NSDistributedNotificationCenter defaultCenter] postNotificationName: @"com.wsbsd.dock.badge" object: nil userInfo: @{ @"path": p, @"count": c } deliverImmediately: YES];
		}
	}
}
- (void)_badgeTimer:(NSTimer *)t { [self _syncBadges: YES]; }
- (void)_changed { @synchronized (self) { [self _save]; [self _syncBadges: NO]; for (WSUNClient *c in _clients) if ([c->role isEqual: @"shell"]) [[c->conn remoteObjectProxy] listChanged]; } }
- (void)removeDelivered:(NSArray *)ids { WSUNClient *r = [self _me]; @synchronized (self) { NSMutableArray *d = _db[@"delivered"]; for (NSInteger i = (NSInteger)d.count - 1; i >= 0; i--) if ([d[i][@"bundle"] isEqual: r->bundle] && [ids containsObject: d[i][@"id"]]) [d removeObjectAtIndex: i]; } [self _changed]; }
- (void)removeAllDelivered { WSUNClient *r = [self _me]; @synchronized (self) { NSMutableArray *d = _db[@"delivered"]; for (NSInteger i = (NSInteger)d.count - 1; i >= 0; i--) if ([d[i][@"bundle"] isEqual: r->bundle]) [d removeObjectAtIndex: i]; } [self _changed]; }
- (void)removePending:(NSArray *)ids { WSUNClient *r = [self _me]; @synchronized (self) { for (NSInteger i = (NSInteger)_pending.count - 1; i >= 0; i--) if ([_pending[i][@"bundle"] isEqual: r->bundle] && [ids containsObject: _pending[i][@"id"]]) [_pending removeObjectAtIndex: i]; } }
- (void)removeAllPending { WSUNClient *r = [self _me]; @synchronized (self) { for (NSInteger i = (NSInteger)_pending.count - 1; i >= 0; i--) if ([_pending[i][@"bundle"] isEqual: r->bundle]) [_pending removeObjectAtIndex: i]; } }
- (void)allDeliveredWithReply:(void (^)(NSArray *))reply { NSArray *a; @synchronized (self) { a = [_db[@"delivered"] copy]; } if (reply) reply(a); }
- (void)dismissNotification:(NSString *)uid { @synchronized (self) { NSMutableArray *d = _db[@"delivered"]; for (NSInteger i = (NSInteger)d.count - 1; i >= 0; i--) if ([d[i][@"uid"] isEqual: uid]) [d removeObjectAtIndex: i]; } [self _changed]; }
- (void)clearAllNotifications { @synchronized (self) { [_db[@"delivered"] removeAllObjects]; } [self _changed]; }
- (void)activateNotification:(NSString *)uid action:(NSString *)action
{
	NSDictionary *n = nil; @synchronized (self) { for (NSDictionary *d in _db[@"delivered"]) if ([d[@"uid"] isEqual: uid]) n = d; }
	if (!n) return; [self dismissNotification: uid]; WSUNClient *app = nil; @synchronized (self) { for (WSUNClient *c in _clients) if ([c->role isEqual: @"app"] && [c->bundle isEqual: n[@"bundle"]]) app = c; }
	NSString *act = action ?: @"com.apple.UNNotificationDefaultActionIdentifier";
	if (app) [[app->conn remoteObjectProxy] didReceiveResponse: n action: act];
	else @synchronized (self) { NSMutableArray *q = [_responses[n[@"bundle"]] mutableCopy] ?: [NSMutableArray array]; [q addObject: @[ n, act ]]; _responses[n[@"bundle"]] = q; }
	if (!app && [n[@"appPath"] length] && getenv("WSBSD_UN_LAUNCH")) { NSTask *t = [NSTask launchedTaskWithLaunchPath: @"/usr/lib/dyld" arguments: @[ n[@"appPath"] ]]; (void)t; }
}
- (void)setFocus:(BOOL)on { _focus = on; [self _save]; }
- (void)focusWithReply:(void (^)(BOOL))reply { if (reply) reply(_focus); }
@end
