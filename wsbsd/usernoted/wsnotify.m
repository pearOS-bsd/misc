/* wsnotify: posts a notification through UserNotifications (what `display notification` of AppleScript or terminal-notifier does on the Mac).
 *   wsnotify [-title T] [-subtitle S] [-message M] [-after SECONDS] [-id ID]      the bundle is org.wsbsd.wsnotify (authorised without a question) */
#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>
int main(int argc, char **argv)
{
	@autoreleasepool {
		NSString *title = @"", *sub = @"", *msg = @"", *ident = [[NSUUID UUID] UUIDString]; double after = 0;
		for (int i = 1; i + 1 < argc; i += 2) { NSString *k = @(argv[i]), *v = @(argv[i + 1]); if ([k isEqual: @"-title"]) title = v; else if ([k isEqual: @"-subtitle"]) sub = v; else if ([k isEqual: @"-message"]) msg = v; else if ([k isEqual: @"-after"]) after = [v doubleValue]; else if ([k isEqual: @"-id"]) ident = v; }
		if (![title length] && ![msg length]) { fprintf(stderr, "usage: wsnotify [-title T] [-subtitle S] [-message M] [-after SECONDS] [-id ID]\n"); return 2; }
		UNUserNotificationCenter *c = [UNUserNotificationCenter currentNotificationCenter]; __block BOOL done = NO, ok = NO;
		[c requestAuthorizationWithOptions: 7 completionHandler: ^(BOOL g, NSError *e) { ok = g; done = YES; }]; for (int i = 0; i < 100 && !done; i++) [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.05]];
		if (!ok) { fprintf(stderr, "wsnotify: notifications are not allowed\n"); return 1; }
		UNMutableNotificationContent *n = [UNMutableNotificationContent new]; n.title = title; n.subtitle = sub; n.body = msg; done = NO; __block NSError *err = nil;
		[c addNotificationRequest: [UNNotificationRequest requestWithIdentifier: ident content: n trigger: after > 0 ? [UNTimeIntervalNotificationTrigger triggerWithTimeInterval: after repeats: NO] : nil] withCompletionHandler: ^(NSError *e) { err = e; done = YES; }];
		for (int i = 0; i < 100 && !done; i++) [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.05]];
		if (err) { fprintf(stderr, "wsnotify: %s\n", [[err localizedDescription] UTF8String]); return 1; }
	}
	return 0;
}
