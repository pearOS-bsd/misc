/* UserNotifications: requests go to usernoted (XPC, com.apple.usernoted), which shows them through the banner of the desktop shell; without the daemon they are handled in the process (see the .m). Was: requests are accepted, handed to the delegate (willPresentNotification), and shown by the notification banner of the desktop shell once that exists; until then they are written to the log
 * of the process and kept as delivered. Authorization is always granted. Implemented in sdk/src/UserNotifications.m */
#ifndef WSBSD_USERNOTIFICATIONS_H
#define WSBSD_USERNOTIFICATIONS_H
#import <Foundation/Foundation.h>
typedef NS_OPTIONS(NSUInteger, UNAuthorizationOptions) { UNAuthorizationOptionBadge = 1, UNAuthorizationOptionSound = 2, UNAuthorizationOptionAlert = 4, UNAuthorizationOptionProvisional = 64 };
typedef NS_OPTIONS(NSUInteger, UNNotificationPresentationOptions) { UNNotificationPresentationOptionBadge = 1, UNNotificationPresentationOptionSound = 2, UNNotificationPresentationOptionAlert = 4, UNNotificationPresentationOptionList = 8, UNNotificationPresentationOptionBanner = 16 };
typedef NS_ENUM(NSInteger, UNAuthorizationStatus) { UNAuthorizationStatusNotDetermined = 0, UNAuthorizationStatusDenied, UNAuthorizationStatusAuthorized, UNAuthorizationStatusProvisional };
@interface UNNotificationSound : NSObject
+ (instancetype)defaultSound;
+ (instancetype)soundNamed:(NSString *)name;
@end
@interface UNNotificationContent : NSObject <NSCopying, NSMutableCopying>
@property (nonatomic, copy) NSString *title, *subtitle, *body, *categoryIdentifier, *threadIdentifier;
@property (nonatomic, copy) NSDictionary *userInfo;
@property (nonatomic, copy) UNNotificationSound *sound;
@property (nonatomic, copy) NSNumber *badge;
@end
@interface UNMutableNotificationContent : UNNotificationContent
@end
typedef NS_OPTIONS(NSUInteger, UNNotificationActionOptions) { UNNotificationActionOptionAuthenticationRequired = 1, UNNotificationActionOptionDestructive = 2, UNNotificationActionOptionForeground = 4 };
@interface UNNotificationAction : NSObject
@property (nonatomic, readonly, copy) NSString *identifier, *title;
@property (nonatomic, readonly) UNNotificationActionOptions options;
+ (instancetype)actionWithIdentifier:(NSString *)identifier title:(NSString *)title options:(UNNotificationActionOptions)options;
@end
@interface UNNotificationCategory : NSObject
@property (nonatomic, readonly, copy) NSString *identifier;
@property (nonatomic, readonly, copy) NSArray *actions;
+ (instancetype)categoryWithIdentifier:(NSString *)identifier actions:(NSArray *)actions intentIdentifiers:(NSArray *)intentIdentifiers options:(NSUInteger)options;
@end
@interface UNNotificationTrigger : NSObject
@property (nonatomic, readonly) BOOL repeats;
@end
@interface UNTimeIntervalNotificationTrigger : UNNotificationTrigger
@property (nonatomic, readonly) NSTimeInterval timeInterval;
+ (instancetype)triggerWithTimeInterval:(NSTimeInterval)interval repeats:(BOOL)repeats;
@end
@interface UNNotificationRequest : NSObject
@property (nonatomic, readonly, copy) NSString *identifier;
@property (nonatomic, readonly, copy) UNNotificationContent *content;
@property (nonatomic, readonly, copy) UNNotificationTrigger *trigger;
+ (instancetype)requestWithIdentifier:(NSString *)identifier content:(UNNotificationContent *)content trigger:(UNNotificationTrigger *)trigger;
@end
@interface UNNotification : NSObject
@property (nonatomic, readonly, copy) NSDate *date;
@property (nonatomic, readonly, copy) UNNotificationRequest *request;
@end
@interface UNNotificationResponse : NSObject
@property (nonatomic, readonly, copy) UNNotification *notification;
@property (nonatomic, readonly, copy) NSString *actionIdentifier;
@end
@interface UNNotificationSettings : NSObject
@property (nonatomic, readonly) UNAuthorizationStatus authorizationStatus;
@end
@class UNUserNotificationCenter;
@protocol UNUserNotificationCenterDelegate <NSObject>
@optional
- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler;
- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler;
@end
@interface UNUserNotificationCenter : NSObject
@property (nonatomic, assign) id<UNUserNotificationCenterDelegate> delegate;
+ (UNUserNotificationCenter *)currentNotificationCenter;
- (void)requestAuthorizationWithOptions:(UNAuthorizationOptions)options completionHandler:(void (^)(BOOL granted, NSError *error))completionHandler;
- (void)getNotificationSettingsWithCompletionHandler:(void (^)(UNNotificationSettings *settings))completionHandler;
- (void)addNotificationRequest:(UNNotificationRequest *)request withCompletionHandler:(void (^)(NSError *error))completionHandler;
- (void)getDeliveredNotificationsWithCompletionHandler:(void (^)(NSArray *notifications))completionHandler;
- (void)removeDeliveredNotificationsWithIdentifiers:(NSArray *)identifiers;
- (void)removeAllDeliveredNotifications;
- (void)removePendingNotificationRequestsWithIdentifiers:(NSArray *)identifiers;
- (void)removeAllPendingNotificationRequests;
- (void)getPendingNotificationRequestsWithCompletionHandler:(void (^)(NSArray *requests))completionHandler;
- (void)setNotificationCategories:(NSSet *)categories;
- (void)getNotificationCategoriesWithCompletionHandler:(void (^)(NSSet *categories))completionHandler;
@end
#endif
