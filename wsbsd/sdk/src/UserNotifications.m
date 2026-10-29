/* UserNotifications without a banner: see the header. Delivered notifications are kept per process and reported through the delegate. */
#import <UserNotifications/UserNotifications.h>
#import <wsbsd/WSUserNotifications.h>
#import <wsbsd/NSXPCConnection.h>
#import <Foundation/NSXPCConnection.h>
#import <objc/message.h>
#include <dispatch/dispatch.h>
#include <dlfcn.h>

@implementation UNNotificationSound
- (id)copyWithZone:(NSZone *)z { return self; }       // immutable: the content copies its sound (a property with copy)
+ (instancetype)defaultSound { return [self new]; }
+ (instancetype)soundNamed:(NSString *)name { (void)name; return [self new]; }
@end
@implementation UNNotificationContent
@synthesize title, subtitle, body, categoryIdentifier, threadIdentifier, userInfo, sound, badge;
- (id)copyWithZone:(NSZone *)z { UNNotificationContent *c = [[UNNotificationContent allocWithZone: z] init]; c.title = title; c.subtitle = subtitle; c.body = body; c.categoryIdentifier = categoryIdentifier; c.threadIdentifier = threadIdentifier; c.userInfo = userInfo; c.sound = sound; c.badge = badge; return c; }
- (id)mutableCopyWithZone:(NSZone *)z { UNNotificationContent *c = [[UNMutableNotificationContent allocWithZone: z] init]; c.title = title; c.subtitle = subtitle; c.body = body; c.categoryIdentifier = categoryIdentifier; c.threadIdentifier = threadIdentifier; c.userInfo = userInfo; c.sound = sound; c.badge = badge; return c; }
@end
@implementation UNMutableNotificationContent @end
@implementation UNNotificationTrigger { BOOL _repeats; } - (BOOL)repeats { return _repeats; } - (void)setWsbsdRepeats:(BOOL)r { _repeats = r; } @end
@implementation UNTimeIntervalNotificationTrigger
{ NSTimeInterval _interval; }
@synthesize timeInterval = _interval;
+ (instancetype)triggerWithTimeInterval:(NSTimeInterval)i repeats:(BOOL)r { UNTimeIntervalNotificationTrigger *t = [self new]; t->_interval = i; [t setWsbsdRepeats: r]; return t; }
@end
@implementation UNNotificationRequest
{ NSString *_identifier; UNNotificationContent *_content; UNNotificationTrigger *_trigger; }
@synthesize identifier = _identifier, content = _content, trigger = _trigger;
+ (instancetype)requestWithIdentifier:(NSString *)i content:(UNNotificationContent *)c trigger:(UNNotificationTrigger *)t { UNNotificationRequest *r = [self new]; r->_identifier = [i copy]; r->_content = [c copy]; r->_trigger = t; return r; }
- (id)copyWithZone:(NSZone *)z { return self; }
@end
@implementation UNNotification
{ NSDate *_date; UNNotificationRequest *_request; }
@synthesize date = _date, request = _request;
+ (instancetype)wsbsdWithRequest:(UNNotificationRequest *)r { UNNotification *n = [self new]; n->_date = [NSDate date]; n->_request = r; return n; }
- (void)wsbsdSetDate:(NSDate *)d { _date = [d copy]; }
- (id)copyWithZone:(NSZone *)z { return self; }
@end
@implementation UNNotificationResponse
{ UNNotification *_notification; NSString *_action; }
@synthesize notification = _notification;
- (NSString *)actionIdentifier { return _action ?: @"com.apple.UNNotificationDefaultActionIdentifier"; }
+ (instancetype)wsbsdWithNotification:(UNNotification *)n { UNNotificationResponse *r = [self new]; r->_notification = n; return r; }
+ (instancetype)wsbsdWithNotification:(UNNotification *)n action:(NSString *)a { UNNotificationResponse *r = [self wsbsdWithNotification: n]; r->_action = [a copy]; return r; }
- (id)copyWithZone:(NSZone *)z { return self; }
@end
@implementation UNNotificationSettings
{ UNAuthorizationStatus _status; }
- (UNAuthorizationStatus)authorizationStatus { return _status; }
+ (instancetype)wsbsdWithStatus:(UNAuthorizationStatus)s { UNNotificationSettings *n = [self new]; n->_status = s; return n; }
@end
@implementation UNNotificationAction
{ NSString *_identifier, *_title; UNNotificationActionOptions _options; }
@synthesize identifier = _identifier, title = _title, options = _options;
+ (instancetype)actionWithIdentifier:(NSString *)i title:(NSString *)t options:(UNNotificationActionOptions)o { UNNotificationAction *a = [self new]; a->_identifier = [i copy]; a->_title = [t copy]; a->_options = o; return a; }
@end
@implementation UNNotificationCategory
{ NSString *_identifier; NSArray *_actions; }
@synthesize identifier = _identifier, actions = _actions;
+ (instancetype)categoryWithIdentifier:(NSString *)i actions:(NSArray *)a intentIdentifiers:(NSArray *)ii options:(NSUInteger)o { (void)ii; (void)o; UNNotificationCategory *c = [self new]; c->_identifier = [i copy]; c->_actions = [a copy]; return c; }
@end

@interface UNNotification (Wsbsd) + (instancetype)wsbsdWithRequest:(UNNotificationRequest *)r; - (void)wsbsdSetDate:(NSDate *)d; @end
@interface UNNotificationResponse (Wsbsd) + (instancetype)wsbsdWithNotification:(UNNotification *)n; + (instancetype)wsbsdWithNotification:(UNNotification *)n action:(NSString *)a; @end
@interface UNNotificationSettings (Wsbsd) + (instancetype)wsbsdWithStatus:(UNAuthorizationStatus)s; @end

/* UNUserNotificationCenter: the requests go to usernoted over XPC (service com.apple.usernoted, protocols in wsbsd/WSUserNotifications.h); when the daemon is not there the old in-process behaviour
 * remains (the delegate is asked, the notification is written to the log and kept as delivered). */
@implementation UNUserNotificationCenter
{ NSMutableArray *_delivered; NSXPCConnection *_conn; BOOL _registered; NSLock *_lock; NSDictionary *_categories; }
@synthesize delegate;
+ (UNUserNotificationCenter *)currentNotificationCenter { static UNUserNotificationCenter *c; static dispatch_once_t o; dispatch_once(&o, ^{ c = [UNUserNotificationCenter new]; c->_delivered = [NSMutableArray array]; c->_lock = [NSLock new]; }); return c; }
/* the .app the process lives in (what the Dock and the Finder call the application): GNUstep takes /Applications/X.app/Contents/MacOS/Resources/X for the bundle of a macOS-style layout without Info.plist, the Mac's mainBundle path is /Applications/X.app */
static NSString *AppBundlePath(void)
{
	for (NSString *c in @[ [[NSBundle mainBundle] bundlePath] ?: @"", [[NSBundle mainBundle] executablePath] ?: @"", [[NSProcessInfo processInfo] arguments].firstObject ?: @"" ]) {
		NSRange r = [c rangeOfString: @".app/" options: 0]; if (r.location != NSNotFound) return [c substringToIndex: r.location + 4];
		if ([c hasSuffix: @".app"]) return c;
	}
	return [[NSBundle mainBundle] bundlePath] ?: @"";
}
static NSString *BundleID(void) { NSString *b = [[NSBundle mainBundle] bundleIdentifier]; return [b length] ? b : [@"org.wsbsd." stringByAppendingString: [[NSProcessInfo processInfo] processName]]; }
static BOOL AppActive(void)       /* only when the process already has its NSApplication (asking for it would start the window server connection of a tool) */
{
	void *sym = dlsym(RTLD_DEFAULT, "NSApp"); id app = sym ? *(__unsafe_unretained id *)sym : nil; if (!app) return NO;
	return ((BOOL (*)(id, SEL))objc_msgSend)(app, NSSelectorFromString(@"isActive"));
}
- (id)_daemon:(void (^)(void))fallback
{
	[_lock lock];
	if (!_conn) {
		if (getenv("WSBSD_UN_OFF")) { [_lock unlock]; return nil; }
		_conn = [[NSXPCConnection alloc] initWithMachServiceName: WSUserNotificationServiceName options: 0]; [_conn setRemoteObjectInterface: [NSXPCInterface interfaceWithProtocol: @protocol(WSUserNotificationRequests)]];
		[_conn setExportedInterface: [NSXPCInterface interfaceWithProtocol: @protocol(WSUserNotificationEvents)]]; [_conn setExportedObject: self]; [_conn resume];
		NSNotificationCenter *nc = [NSNotificationCenter defaultCenter]; [nc addObserver: self selector: @selector(_fg:) name: @"NSApplicationDidBecomeActiveNotification" object: nil]; [nc addObserver: self selector: @selector(_fg:) name: @"NSApplicationDidResignActiveNotification" object: nil];
	}
	NSXPCConnection *c = _conn; BOOL reg = _registered; _registered = YES; [_lock unlock];
	__block BOOL failed = NO; id p = [c remoteObjectProxyWithErrorHandler: ^(NSError *e) { if (failed) return; failed = YES; [self->_lock lock]; self->_conn = nil; self->_registered = NO; [self->_lock unlock]; if (fallback) fallback(); }];
	if (!reg) { NSString *name = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleName"] ?: [[NSProcessInfo processInfo] processName]; NSString *path = AppBundlePath();
		[p registerClientWithInfo: @{ @"bundle": BundleID(), @"name": name, @"path": path, @"role": @"app", @"foreground": @(AppActive()) } reply: ^(BOOL ok) {}]; }
	return p;
}
- (void)_fg:(NSNotification *)n { id p = [self _daemon: nil]; [p setForeground: [[n name] isEqual: @"NSApplicationDidBecomeActiveNotification"]]; }
static NSDictionary *Dict(UNNotificationRequest *r)
{
	UNNotificationContent *c = [r content]; NSMutableDictionary *d = [NSMutableDictionary dictionary]; d[@"id"] = [r identifier] ?: [[NSUUID UUID] UUIDString];
	if ([c title]) d[@"title"] = [c title]; if ([c subtitle]) d[@"subtitle"] = [c subtitle]; if ([c body]) d[@"body"] = [c body]; if ([c threadIdentifier]) d[@"thread"] = [c threadIdentifier]; if ([c categoryIdentifier]) d[@"category"] = [c categoryIdentifier];
	if ([c userInfo]) d[@"userInfo"] = [c userInfo]; if ([c sound]) d[@"sound"] = @YES;
	if ([[r trigger] isKindOfClass: [UNTimeIntervalNotificationTrigger class]]) { d[@"interval"] = @([(UNTimeIntervalNotificationTrigger *)[r trigger] timeInterval]); d[@"repeats"] = @([[r trigger] repeats]); }
	return d;
}
static UNNotification *FromDict(NSDictionary *d)
{
	UNMutableNotificationContent *c = [UNMutableNotificationContent new]; c.title = d[@"title"] ?: @""; c.subtitle = d[@"subtitle"] ?: @""; c.body = d[@"body"] ?: @""; c.threadIdentifier = d[@"thread"] ?: @""; c.categoryIdentifier = d[@"category"] ?: @""; c.userInfo = d[@"userInfo"] ?: @{};
	UNNotification *n = [UNNotification wsbsdWithRequest: [UNNotificationRequest requestWithIdentifier: d[@"id"] content: c trigger: nil]]; if (d[@"date"]) [n wsbsdSetDate: d[@"date"]]; return n;
}
- (void)requestAuthorizationWithOptions:(UNAuthorizationOptions)o completionHandler:(void (^)(BOOL, NSError *))h
{
	id p = [self _daemon: ^{ if (h) h(YES, nil); }]; if (!p) { if (h) h(YES, nil); return; }
	[p requestAuthorization: o reply: ^(BOOL granted) { if (h) h(granted, nil); }];
}
- (void)getNotificationSettingsWithCompletionHandler:(void (^)(UNNotificationSettings *))h
{
	id p = [self _daemon: ^{ if (h) h([UNNotificationSettings wsbsdWithStatus: UNAuthorizationStatusAuthorized]); }]; if (!p) { if (h) h([UNNotificationSettings wsbsdWithStatus: UNAuthorizationStatusAuthorized]); return; }
	[p authorizationStatusWithReply: ^(NSInteger s, NSUInteger o) { if (h) h([UNNotificationSettings wsbsdWithStatus: (UNAuthorizationStatus)s]); }];
}
- (void)_local:(UNNotificationRequest *)r
{
	UNNotification *n = [UNNotification wsbsdWithRequest: r]; UNNotificationContent *c = [r content];
	void (^deliver)(UNNotificationPresentationOptions) = ^(UNNotificationPresentationOptions opts) {
		if (opts & (UNNotificationPresentationOptionAlert | UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionList)) { @synchronized (self) { [_delivered addObject: n]; } NSLog(@"notification: %@%@%@", [c title] ?: @"", [c body] ? @" - " : @"", [c body] ?: @""); }
	};
	if ([delegate respondsToSelector: @selector(userNotificationCenter:willPresentNotification:withCompletionHandler:)]) [delegate userNotificationCenter: self willPresentNotification: n withCompletionHandler: deliver]; else deliver(UNNotificationPresentationOptionAlert);
}
- (void)addNotificationRequest:(UNNotificationRequest *)r withCompletionHandler:(void (^)(NSError *))h
{
	__block BOOL answered = NO; void (^fb)(void) = ^{ if (answered) return; answered = YES; [self _local: r]; if (h) h(nil); };
	id p = [self _daemon: fb]; if (!p) { fb(); return; }
	[p postNotification: Dict(r) reply: ^(NSString *err) { if (answered) return; answered = YES; if (h) h(err ? [NSError errorWithDomain: @"UNErrorDomain" code: 1 userInfo: @{ NSLocalizedDescriptionKey: err }] : nil); }];
}
- (void)getDeliveredNotificationsWithCompletionHandler:(void (^)(NSArray *))h
{
	void (^fb)(void) = ^{ NSArray *a; @synchronized (self) { a = [self->_delivered copy]; } if (h) h(a); };
	id p = [self _daemon: fb]; if (!p) { fb(); return; }
	[p deliveredWithReply: ^(NSArray *a) { NSMutableArray *o = [NSMutableArray array]; for (NSDictionary *d in a) [o addObject: FromDict(d)]; if (h) h(o); }];
}
- (void)getPendingNotificationRequestsWithCompletionHandler:(void (^)(NSArray *))h
{
	id p = [self _daemon: ^{ if (h) h(@[]); }]; if (!p) { if (h) h(@[]); return; }
	[p pendingWithReply: ^(NSArray *a) { NSMutableArray *o = [NSMutableArray array]; for (NSDictionary *d in a) [o addObject: [FromDict(d) request]]; if (h) h(o); }];
}
- (void)removeDeliveredNotificationsWithIdentifiers:(NSArray *)ids
{
	@synchronized (self) { for (NSInteger i = (NSInteger)_delivered.count - 1; i >= 0; i--) if ([ids containsObject: [[(UNNotification *)_delivered[i] request] identifier]]) [_delivered removeObjectAtIndex: i]; }
	[[self _daemon: nil] removeDelivered: ids];
}
- (void)removeAllDeliveredNotifications { @synchronized (self) { [_delivered removeAllObjects]; } [[self _daemon: nil] removeAllDelivered]; }
- (void)removePendingNotificationRequestsWithIdentifiers:(NSArray *)ids { [[self _daemon: nil] removePending: ids]; }
- (void)removeAllPendingNotificationRequests { [[self _daemon: nil] removeAllPending]; }
- (void)setNotificationCategories:(NSSet *)categories { _categories = [NSDictionary dictionaryWithObjects: [categories allObjects] forKeys: [[categories allObjects] valueForKey: @"identifier"]]; }
- (void)getNotificationCategoriesWithCompletionHandler:(void (^)(NSSet *))h { if (h) h([NSSet setWithArray: [_categories allValues]]); }
/* calls from the daemon */
- (void)willPresentNotification:(NSDictionary *)d reply:(void (^)(NSUInteger))reply
{
	UNNotification *n = FromDict(d); id<UNUserNotificationCenterDelegate> dg = delegate;
	if (![dg respondsToSelector: @selector(userNotificationCenter:willPresentNotification:withCompletionHandler:)]) { reply(0); return; }       // in the foreground without a delegate method nothing is shown, as on the Mac
	dispatch_async(dispatch_get_main_queue(), ^{ [dg userNotificationCenter: self willPresentNotification: n withCompletionHandler: ^(UNNotificationPresentationOptions o) { reply((NSUInteger)o); }]; });
}
- (void)didReceiveResponse:(NSDictionary *)d action:(NSString *)action
{
	UNNotificationResponse *r = [UNNotificationResponse wsbsdWithNotification: FromDict(d) action: action]; id<UNUserNotificationCenterDelegate> dg = delegate;
	if ([dg respondsToSelector: @selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:)]) dispatch_async(dispatch_get_main_queue(), ^{ [dg userNotificationCenter: self didReceiveNotificationResponse: r withCompletionHandler: ^{}]; });
}
@end
