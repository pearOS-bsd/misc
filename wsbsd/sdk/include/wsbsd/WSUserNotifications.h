/* The XPC protocols of usernoted (service com.apple.usernoted): the framework in an application (UserNotifications.framework, sdk/src/UserNotifications.m) and the desktop shell (the banner and the panel of
 * Notification Center, topbar/) talk to the daemon through them; the daemon calls back through WSUserNotificationEvents. As on the Mac the application never draws anything: it hands a request to the daemon. */
#import <Foundation/Foundation.h>
#define WSUserNotificationServiceName @"com.apple.usernoted"
@protocol WSUserNotificationRequests <NSObject>
/* info: bundle, name, path (the .app, for the icon), role ("app" or "shell"), foreground (BOOL) */
- (void)registerClientWithInfo:(NSDictionary *)info reply:(void (^)(BOOL ok))reply;
- (void)setForeground:(BOOL)foreground;
- (void)requestAuthorization:(NSUInteger)options reply:(void (^)(BOOL granted))reply;
- (void)authorizationStatusWithReply:(void (^)(NSInteger status, NSUInteger options))reply;
/* n: id, title, subtitle, body, thread, category, userInfo, interval (NSNumber, absent = now), repeats */
- (void)postNotification:(NSDictionary *)n reply:(void (^)(NSString *error))reply;
- (void)deliveredWithReply:(void (^)(NSArray *notifications))reply;
- (void)pendingWithReply:(void (^)(NSArray *notifications))reply;
- (void)removeDelivered:(NSArray *)identifiers;
- (void)removeAllDelivered;
- (void)removePending:(NSArray *)identifiers;
- (void)removeAllPending;
/* the shell */
- (void)allDeliveredWithReply:(void (^)(NSArray *notifications))reply;
- (void)dismissNotification:(NSString *)uid;
- (void)clearAllNotifications;
- (void)activateNotification:(NSString *)uid action:(NSString *)action;
- (void)setFocus:(BOOL)on;
- (void)focusWithReply:(void (^)(BOOL on))reply;
@end
@protocol WSUserNotificationEvents <NSObject>
@optional
/* to an application that is in the foreground: the delegate's willPresentNotification decides how it is shown */
- (void)willPresentNotification:(NSDictionary *)n reply:(void (^)(NSUInteger options))reply;
- (void)didReceiveResponse:(NSDictionary *)n action:(NSString *)action;
/* to the shell */
- (void)presentBanner:(NSDictionary *)n;
- (void)listChanged;
@end
