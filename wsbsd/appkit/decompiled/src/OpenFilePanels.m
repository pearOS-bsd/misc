/* OpenFilePanels.m — NSOpenPanel / NSSavePanel of the programs: as on the Mac they are served by the Open and Save Panel Service (com.apple.appkit.xpc.openAndSavePanelService, the pearOS-bsd/d repository (bsd/xpcservices/)):
 * the request goes over its socket (WSBSD_XPC_DIR, default /var/run/xpc), the answer comes back as URLs.  The program waits in a modal loop (its own windows keep being served). */
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "NSWindow.h"
#import "NSApplication.h"
#import "NSSavePanel.h"
#import "NSOpenPanel.h"
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <spawn.h>

extern char **environ;
static char kState;
static NSMutableDictionary *State(id p) { NSMutableDictionary *d = objc_getAssociatedObject(p, &kState); if (!d) { d = [NSMutableDictionary new]; objc_setAssociatedObject(p, &kState, d, OBJC_ASSOCIATION_RETAIN); } return d; }

static int ConnectService(void)
{
    const char *dir = getenv("WSBSD_XPC_DIR") ?: "/var/run/xpc"; char path[512]; snprintf(path, sizeof path, "%s/com.apple.appkit.xpc.openAndSavePanelService", dir);
    for (int attempt = 0; attempt < 2; attempt++) {
        int fd = socket(AF_UNIX, SOCK_STREAM, 0); struct sockaddr_un a; memset(&a, 0, sizeof a); a.sun_family = AF_UNIX; strlcpy(a.sun_path, path, sizeof a.sun_path);
        if (connect(fd, (struct sockaddr *)&a, sizeof a) == 0) return fd;
        close(fd);
        if (attempt == 0) {		/* launchd would start the service on the first connection: start it here, from where the Mac keeps it */
            const char *bins[] = { "/System/Library/Frameworks/AppKit.framework/Versions/C/XPCServices/com.apple.appkit.xpc.openAndSavePanelService.xpc/Contents/MacOS/com.apple.appkit.xpc.openAndSavePanelService",
                                   "/usr/local/libexec/com.apple.appkit.xpc.openAndSavePanelService", NULL };
            for (int i = 0; bins[i]; i++) if (access(bins[i], X_OK) == 0) { pid_t pid; char *av[] = { (char *)bins[i], NULL }; { setenv("LD_LIBRARY_PATH", "/usr/local/GNUstep/System/Library/Libraries:/usr/local/GNUstep/Local/Library/Libraries:/usr/local/lib", 0); posix_spawn_file_actions_t fa; posix_spawn_file_actions_init(&fa); posix_spawn_file_actions_addopen(&fa, 1, "/tmp/panelservice.log", O_WRONLY | O_CREAT | O_APPEND, 0644); posix_spawn_file_actions_adddup2(&fa, 1, 2); posix_spawn(&pid, bins[i], &fa, NULL, av, environ); } break; }
            for (int w = 0; w < 300; w++) { usleep(100000); int f2 = socket(AF_UNIX, SOCK_STREAM, 0); if (connect(f2, (struct sockaddr *)&a, sizeof a) == 0) return f2; close(f2); }
            return -1;
        }
    }
    return -1;
}

@implementation NSSavePanel (OpenService)
+ (instancetype)savePanel { return [[self alloc] init]; }
- (NSInteger)_openRun:(NSString *)kind
{
    NSMutableDictionary *s = State(self);
    NSMutableDictionary *r = [@{ @"id": @1, @"kind": kind, @"createDirs": @([self canCreateDirectories]), @"hidden": @([self showsHiddenFiles]), @"other": @([self allowsOtherFileTypes]) } mutableCopy];
    r[@"directory"] = [self directoryURL] ? [[self directoryURL] path] : NSHomeDirectory();
    if ([[self nameFieldStringValue] length]) r[@"name"] = [self nameFieldStringValue];
    for (NSString *k in @[ @"types", @"prompt", @"message", @"files", @"dirs", @"multiple" ]) if (s[k]) r[k] = s[k];
    int fd = ConnectService(); if (fd < 0) { fprintf(stderr, "open: Open and Save Panel Service not available\n"); return 0; }
    NSData *j = [NSJSONSerialization dataWithJSONObject:r options:0 error:NULL]; unsigned char h[4] = { (unsigned char)([j length] >> 24), (unsigned char)([j length] >> 16), (unsigned char)([j length] >> 8), (unsigned char)[j length] };
    write(fd, h, 4); write(fd, [j bytes], [j length]);
    __block NSDictionary *reply = nil; __block BOOL done = NO;
    dispatch_async(dispatch_queue_create("open.panel", DISPATCH_QUEUE_SERIAL), ^{
        NSMutableData *buf = [NSMutableData new];
        while (!done) {
            char tmp[4096]; ssize_t n = read(fd, tmp, sizeof tmp); if (n <= 0) break; [buf appendBytes:tmp length:(NSUInteger)n];
            if ([buf length] >= 4) { const unsigned char *p = [buf bytes]; NSUInteger len = ((NSUInteger)p[0] << 24) | (p[1] << 16) | (p[2] << 8) | p[3]; if ([buf length] >= 4 + len) { id o = [NSJSONSerialization JSONObjectWithData:[buf subdataWithRange:NSMakeRange(4, len)] options:0 error:NULL]; if ([o isKindOfClass:[NSDictionary class]]) reply = o; break; } }
        }
        done = YES;
    });
    while (!done) CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.02, false);
    close(fd);
    NSMutableArray *urls = [NSMutableArray new]; for (NSString *p in reply[@"urls"] ?: @[]) [urls addObject:[NSURL fileURLWithPath:p]];
    s[@"urls"] = urls;
    return [reply[@"response"] integerValue] == 1 ? 1 : 0;			/* NSModalResponseOK / Cancel */
}
- (NSInteger)runModal { return [self _openRun:[self isKindOfClass:NSClassFromString(@"NSOpenPanel")] ? @"open" : @"save"]; }
- (NSURL *)URL { return [State(self)[@"urls"] firstObject]; }
- (void)beginWithCompletionHandler:(void (^)(NSInteger))h { NSInteger r = [self runModal]; if (h) h(r); }
- (void)beginSheetModalForWindow:(NSWindow *)w completionHandler:(void (^)(NSInteger))h { [self beginWithCompletionHandler:h]; }
- (void)setAllowedFileTypes:(NSArray *)t { State(self)[@"types"] = t ?: @[]; }
- (NSArray *)allowedFileTypes { return State(self)[@"types"]; }
- (void)setAllowedContentTypes:(NSArray *)t
{
    NSMutableArray *exts = [NSMutableArray new];
    for (id ut in t) { id e = [ut respondsToSelector:@selector(preferredFilenameExtension)] ? [ut performSelector:@selector(preferredFilenameExtension)] : nil; if (e) [exts addObject:e]; }
    State(self)[@"types"] = exts;
}
- (void)setPrompt:(NSString *)p { State(self)[@"prompt"] = p ?: @""; }
- (NSString *)prompt { return State(self)[@"prompt"]; }
- (void)setMessage:(NSString *)m { State(self)[@"message"] = m ?: @""; }
- (NSString *)message { return State(self)[@"message"]; }
- (void)setTitle:(NSString *)t { }
- (void)setExtensionHidden:(BOOL)b { }
- (void)setAccessoryView:(id)v { }
- (void)setCanSelectHiddenExtension:(BOOL)b { }
@end

@implementation NSOpenPanel (OpenService)
+ (instancetype)openPanel { return [[self alloc] init]; }
- (void)setCanChooseFiles:(BOOL)b { State(self)[@"files"] = @(b); }
- (BOOL)canChooseFiles { NSNumber *n = State(self)[@"files"]; return n ? [n boolValue] : YES; }
- (void)setCanChooseDirectories:(BOOL)b { State(self)[@"dirs"] = @(b); }
- (BOOL)canChooseDirectories { return [State(self)[@"dirs"] boolValue]; }
- (void)setAllowsMultipleSelection:(BOOL)b { State(self)[@"multiple"] = @(b); }
- (BOOL)allowsMultipleSelection { return [State(self)[@"multiple"] boolValue]; }
- (NSArray *)URLs { return State(self)[@"urls"] ?: @[]; }
@end
