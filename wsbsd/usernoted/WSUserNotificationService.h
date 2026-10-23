#import <wsbsd/WSUserNotifications.h>
#import <wsbsd/NSXPCConnection.h>
#import <Foundation/NSXPCConnection.h>
/* usernoted: authorisation per bundle, scheduling, Focus, the list of delivered notifications (kept in a property list), arbitration between the application and the shell. dir: where the database is (default ~/Library/Application Support/NotificationCenter) */
@interface WSUserNotificationService : NSObject <NSXPCListenerDelegate, WSUserNotificationRequests>
- (instancetype)initWithDirectory:(NSString *)dir;
- (void)startListening;
@end
