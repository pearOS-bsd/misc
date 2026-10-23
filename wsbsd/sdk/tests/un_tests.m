/* usernoted end to end: the daemon (in this process, as a second thread of the XPC), a client with the framework, a shell client. Authorisation, immediate and timed posting, willPresent of an application in the foreground,
 * Focus keeps the banner away, the list of delivered notifications, removal, a click (activate) reaching the delegate. */
#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>
#import <wsbsd/WSUserNotifications.h>
#import <wsbsd/NSXPCConnection.h>
#import <Foundation/NSXPCConnection.h>
#include <stdio.h>
#import "../../usernoted/WSUserNotificationService.h"
static int failures; static void Check(int ok, const char *what, int line) { if (!ok) { printf("FAIL %s:%d %s\n", __FILE__, line, what); failures++; } }
#define CHECK(c) Check((c), #c, __LINE__)
static void Spin(double s) { [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: s]]; }

@interface Shell : NSObject <WSUserNotificationEvents> { @public NSMutableArray *banners; int lists; } @end
@implementation Shell
- (instancetype)init { if ((self = [super init])) banners = [NSMutableArray array]; return self; }
- (void)presentBanner:(NSDictionary *)n { @synchronized (self) { [banners addObject: n]; } }
- (void)listChanged { lists++; }
@end
@interface Delegate : NSObject <UNUserNotificationCenterDelegate> { @public int will, did; NSUInteger options; NSString *lastAction; } @end
@implementation Delegate
- (void)userNotificationCenter:(UNUserNotificationCenter *)c willPresentNotification:(UNNotification *)n withCompletionHandler:(void (^)(UNNotificationPresentationOptions))h { will++; h((UNNotificationPresentationOptions)options); }
- (void)userNotificationCenter:(UNUserNotificationCenter *)c didReceiveNotificationResponse:(UNNotificationResponse *)r withCompletionHandler:(void (^)(void))h { did++; lastAction = [r actionIdentifier]; h(); }
@end
static UNNotificationRequest *Req(NSString *i, NSString *t, NSString *b, NSTimeInterval iv)
{
	UNMutableNotificationContent *c = [UNMutableNotificationContent new]; c.title = t; c.body = b; c.subtitle = @"sub";
	return [UNNotificationRequest requestWithIdentifier: i content: c trigger: iv > 0 ? [UNTimeIntervalNotificationTrigger triggerWithTimeInterval: iv repeats: NO] : nil];
}
int main(void)
{
	@autoreleasepool {
		setenv("WSBSD_XPC_DIR", "/tmp/wsbsd-un-test", 1); setenv("WSBSD_UN_DIR", "/tmp/wsbsd-un-test/db", 1); system("rm -rf /tmp/wsbsd-un-test");
		WSUserNotificationService *svc = [[WSUserNotificationService alloc] initWithDirectory: @"/tmp/wsbsd-un-test/db"]; [svc startListening];
		// the shell
		Shell *sh = [Shell new]; NSXPCConnection *sc = [[NSXPCConnection alloc] initWithMachServiceName: WSUserNotificationServiceName options: 0]; [sc setRemoteObjectInterface: [NSXPCInterface interfaceWithProtocol: @protocol(WSUserNotificationRequests)]]; [sc setExportedInterface: [NSXPCInterface interfaceWithProtocol: @protocol(WSUserNotificationEvents)]]; [sc setExportedObject: sh]; [sc resume];
		id<WSUserNotificationRequests> shell = [sc synchronousRemoteObjectProxyWithErrorHandler: ^(NSError *e) { printf("shell error %s\n", [[e description] UTF8String]); }];
		[shell registerClientWithInfo: @{ @"bundle": @"com.apple.notificationcenterui", @"name": @"Notification Center", @"role": @"shell" } reply: ^(BOOL ok) {}];
		// the application
		UNUserNotificationCenter *c = [UNUserNotificationCenter currentNotificationCenter]; Delegate *dg = [Delegate new]; c.delegate = dg; dg->options = 4;
		__block BOOL granted = NO, got = NO; [c requestAuthorizationWithOptions: 7 completionHandler: ^(BOOL g, NSError *e) { granted = g; got = YES; }]; for (int i = 0; i < 50 && !got; i++) Spin(0.1);
		CHECK(got && granted);
		__block UNAuthorizationStatus st = UNAuthorizationStatusNotDetermined; [c getNotificationSettingsWithCompletionHandler: ^(UNNotificationSettings *s) { st = [s authorizationStatus]; }]; Spin(0.5); CHECK(st == UNAuthorizationStatusAuthorized);
		// an immediate notification reaches the shell as a banner and is listed
		__block NSError *perr = (NSError *)@"unset"; [c addNotificationRequest: Req(@"one", @"Title", @"Body", 0) withCompletionHandler: ^(NSError *e) { perr = e; }]; Spin(1);
		CHECK(perr == nil); @synchronized (sh) { CHECK([sh->banners count] == 1); CHECK([sh->banners[0][@"title"] isEqual: @"Title"]); CHECK([sh->banners[0][@"appName"] length] > 0); }
		__block NSUInteger nd = 0; [c getDeliveredNotificationsWithCompletionHandler: ^(NSArray *a) { nd = [a count]; }]; Spin(0.5); CHECK(nd == 1);
		// a timed one
		[c addNotificationRequest: Req(@"timed", @"Later", @"x", 0.6) withCompletionHandler: nil]; __block NSUInteger np = 0; [c getPendingNotificationRequestsWithCompletionHandler: ^(NSArray *a) { np = [a count]; }]; Spin(0.3); CHECK(np == 1);
		Spin(1.5); @synchronized (sh) { CHECK([sh->banners count] == 2); }
		// removal of a pending one before it fires
		[c addNotificationRequest: Req(@"gone", @"Never", @"x", 1.0) withCompletionHandler: nil]; Spin(0.3); [c removePendingNotificationRequestsWithIdentifiers: @[ @"gone" ]]; Spin(1.5); @synchronized (sh) { CHECK([sh->banners count] == 2); }
		// Focus: listed, no banner
		[shell setFocus: YES]; __block BOOL fo = NO; [shell focusWithReply: ^(BOOL on) { fo = on; }]; Spin(0.3); CHECK(fo); [c addNotificationRequest: Req(@"quiet", @"Quiet", @"x", 0) withCompletionHandler: nil]; Spin(1); @synchronized (sh) { CHECK([sh->banners count] == 2); }
		nd = 0; [c getDeliveredNotificationsWithCompletionHandler: ^(NSArray *a) { nd = [a count]; }]; Spin(0.5); CHECK(nd == 3);
		[shell setFocus: NO];
		// removal of a delivered one
		[c removeDeliveredNotificationsWithIdentifiers: @[ @"one" ]]; Spin(0.5); nd = 0; [c getDeliveredNotificationsWithCompletionHandler: ^(NSArray *a) { nd = [a count]; }]; Spin(0.5); CHECK(nd == 2);
		// the shell's list and a click on a notification: the delegate gets the response
		__block NSArray *all = nil; [shell allDeliveredWithReply: ^(NSArray *a) { all = a; }]; CHECK([all count] == 2);
		NSString *uid = nil; for (NSDictionary *n in all) if ([n[@"id"] isEqual: @"quiet"]) uid = n[@"uid"]; CHECK(uid != nil);
		[shell activateNotification: uid action: nil]; Spin(1); CHECK(dg->did == 1); CHECK([dg->lastAction isEqual: @"com.apple.UNNotificationDefaultActionIdentifier"]);
		[shell allDeliveredWithReply: ^(NSArray *a) { all = a; }]; CHECK([all count] == 1);
		// an application in the foreground: the delegate decides (options 0: nothing is shown)
		NSXPCConnection *cc = nil; (void)cc; [c performSelector: NSSelectorFromString(@"_fg:") withObject: [NSNotification notificationWithName: @"NSApplicationDidBecomeActiveNotification" object: nil]]; Spin(0.5);
		dg->options = 0; int before; @synchronized (sh) { before = (int)[sh->banners count]; } [c addNotificationRequest: Req(@"fg0", @"Fg", @"x", 0) withCompletionHandler: nil]; Spin(1); CHECK(dg->will == 1); @synchronized (sh) { CHECK((int)[sh->banners count] == before); }
		dg->options = 4; [c addNotificationRequest: Req(@"fg4", @"Fg", @"x", 0) withCompletionHandler: nil]; Spin(1); CHECK(dg->will == 2); @synchronized (sh) { CHECK((int)[sh->banners count] == before + 1); }
		// the database survives the daemon
		WSUserNotificationService *again = [[WSUserNotificationService alloc] initWithDirectory: @"/tmp/wsbsd-un-test/db"]; (void)again;
		CHECK([[NSDictionary dictionaryWithContentsOfFile: @"/tmp/wsbsd-un-test/db/db.plist"][@"delivered"] count] >= 1);
	}
	printf(failures ? "usernoted: %d failed\n" : "usernoted ok\n", failures);
	return failures != 0;
}
