/* UserNotifications without a banner: see the header. Delivered notifications are kept per process and reported through the delegate. */
#import <UserNotifications/UserNotifications.h>

@implementation UNNotificationSound
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
+ (instancetype)triggerWithTimeInterval:(NSTimeInterval)i repeats:(BOOL)r { UNTimeIntervalNotificationTrigger *t = [self new]; [t setWsbsdRepeats: r]; return t; }
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
- (id)copyWithZone:(NSZone *)z { return self; }
@end
@implementation UNNotificationResponse
{ UNNotification *_notification; }
@synthesize notification = _notification;
- (NSString *)actionIdentifier { return @"com.apple.UNNotificationDefaultActionIdentifier"; }
+ (instancetype)wsbsdWithNotification:(UNNotification *)n { UNNotificationResponse *r = [self new]; r->_notification = n; return r; }
- (id)copyWithZone:(NSZone *)z { return self; }
@end
@implementation UNNotificationSettings
- (UNAuthorizationStatus)authorizationStatus { return UNAuthorizationStatusAuthorized; }
@end

@interface UNNotification (Wsbsd) + (instancetype)wsbsdWithRequest:(UNNotificationRequest *)r; @end
@interface UNNotificationResponse (Wsbsd) + (instancetype)wsbsdWithNotification:(UNNotification *)n; @end
@implementation UNUserNotificationCenter
{ NSMutableArray *_delivered; }
@synthesize delegate;
+ (UNUserNotificationCenter *)currentNotificationCenter { static UNUserNotificationCenter *c; static dispatch_once_t o; dispatch_once(&o, ^{ c = [UNUserNotificationCenter new]; c->_delivered = [NSMutableArray array]; }); return c; }
- (void)requestAuthorizationWithOptions:(UNAuthorizationOptions)o completionHandler:(void (^)(BOOL, NSError *))h { if (h) h(YES, nil); }
- (void)getNotificationSettingsWithCompletionHandler:(void (^)(UNNotificationSettings *))h { if (h) h([UNNotificationSettings new]); }
- (void)addNotificationRequest:(UNNotificationRequest *)r withCompletionHandler:(void (^)(NSError *))h
{
	UNNotification *n = [UNNotification wsbsdWithRequest: r]; UNNotificationContent *c = [r content];
	void (^deliver)(UNNotificationPresentationOptions) = ^(UNNotificationPresentationOptions opts) {
		if (opts & (UNNotificationPresentationOptionAlert | UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionList)) {
			@synchronized (self) { [_delivered addObject: n]; }
			NSLog(@"notification: %@%@%@", [c title] ?: @"", [c body] ? @" - " : @"", [c body] ?: @""); }
	};
	if ([delegate respondsToSelector: @selector(userNotificationCenter:willPresentNotification:withCompletionHandler:)]) [delegate userNotificationCenter: self willPresentNotification: n withCompletionHandler: deliver];
	else deliver(UNNotificationPresentationOptionAlert);
	if (h) h(nil);
}
- (void)getDeliveredNotificationsWithCompletionHandler:(void (^)(NSArray *))h { NSArray *a; @synchronized (self) { a = [_delivered copy]; } if (h) h(a); }
- (void)removeDeliveredNotificationsWithIdentifiers:(NSArray *)ids { @synchronized (self) { for (NSInteger i = (NSInteger)_delivered.count - 1; i >= 0; i--) if ([ids containsObject: [[(UNNotification *)_delivered[i] request] identifier]]) [_delivered removeObjectAtIndex: i]; } }
- (void)removeAllDeliveredNotifications { @synchronized (self) { [_delivered removeAllObjects]; } }
- (void)removePendingNotificationRequestsWithIdentifiers:(NSArray *)ids { (void)ids; }
- (void)removeAllPendingNotificationRequests {}
@end
