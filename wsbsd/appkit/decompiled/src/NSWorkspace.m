/*
 * NSWorkspace.m — behavioral-1:1 core. See the header.
 */

#import "NSWorkspace.h"

@implementation NSWorkspace {
    NSNotificationCenter *_notificationCenter;
}

+ (NSWorkspace *)sharedWorkspace
{
    static NSWorkspace *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[self alloc] init]; });
    return shared;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        /* a dedicated center, distinct from +[NSNotificationCenter defaultCenter]
           (measured: real class is NSWorkspaceNotificationCenter). */
        _notificationCenter = [[NSNotificationCenter alloc] init];
    }
    return self;
}

- (NSNotificationCenter *)notificationCenter { return _notificationCenter; }

/* LaunchServices / window-server backed — stage2. */
- (BOOL)openURL:(NSURL *)url { return NO; }
- (BOOL)openFile:(NSString *)fullPath { return NO; }
- (BOOL)launchApplication:(NSString *)appName { return NO; }
- (BOOL)selectFile:(NSString *)fullPath inFileViewerRootedAtPath:(NSString *)rootFullPath { return NO; }
- (NSImage *)iconForFile:(NSString *)fullPath { return nil; }
- (NSString *)fullPathForApplication:(NSString *)appName { return nil; }
- (NSURL *)URLForApplicationToOpenURL:(NSURL *)url { return nil; }
- (NSArray *)runningApplications { return @[]; }

@end
