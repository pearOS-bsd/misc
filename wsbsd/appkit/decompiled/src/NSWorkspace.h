/*
 * NSWorkspace.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSWorkspace, the shared gateway to file opening, app launching and metadata.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSWorkspace_interface.txt.
 *
 * This core reproduces the shared singleton and the dedicated notificationCenter
 * (a private NSNotificationCenter, distinct from the default one — measured).
 * Everything else is backed by LaunchServices / the window server, so the
 * open/launch actions and the metadata queries are TODO(stage2): actions return
 * NO, metadata queries return nil, runningApplications returns @[].
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class NSImage;

@interface NSWorkspace : NSObject

@property (class, readonly, strong) NSWorkspace *sharedWorkspace;
@property (readonly, strong) NSNotificationCenter *notificationCenter;

- (BOOL)openURL:(NSURL *)url;
- (BOOL)openFile:(NSString *)fullPath;
- (BOOL)launchApplication:(NSString *)appName;
- (BOOL)selectFile:(nullable NSString *)fullPath inFileViewerRootedAtPath:(NSString *)rootFullPath;

- (nullable NSImage *)iconForFile:(NSString *)fullPath;
- (nullable NSString *)fullPathForApplication:(NSString *)appName;
- (nullable NSURL *)URLForApplicationToOpenURL:(NSURL *)url;
@property (readonly, copy) NSArray *runningApplications;

@end

NS_ASSUME_NONNULL_END
