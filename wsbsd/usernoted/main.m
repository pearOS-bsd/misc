/* usernoted: /usr/libexec/usernoted. WSBSD_XPC_DIR as for every XPC service; WSBSD_UN_DIR the database (default ~/Library/Application Support/NotificationCenter). */
#import "WSUserNotificationService.h"
int main(int argc, char **argv)
{
	@autoreleasepool {
		NSString *dir = getenv("WSBSD_UN_DIR") ? @(getenv("WSBSD_UN_DIR")) : [NSHomeDirectory() stringByAppendingPathComponent: @"Library/Application Support/NotificationCenter"];
		WSUserNotificationService *s = [[WSUserNotificationService alloc] initWithDirectory: dir]; [s startListening]; [[NSRunLoop currentRunLoop] run];
	}
	return 0;
}
