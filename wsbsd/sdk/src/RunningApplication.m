/* The application started by -[NSWorkspace launchApplicationAtURL:options:configuration:error:]: the bundle's executable runs as a child
 * with the configuration's arguments and environment. */
#import <AppKit/AppKit.h>
#import <wsbsd/AppKitCompat2.h>
#include <signal.h>
#include <sys/wait.h>
#include <unistd.h>
#include <errno.h>

@implementation WsbsdRunningApplication
{ pid_t _pid; NSURL *_url; NSTask *_task; }
- (instancetype)initWithPid:(pid_t)pid bundleURL:(NSURL *)url task:(NSTask *)t { if ((self = [super init])) { _pid = pid; _url = url; _task = t; } return self; }
- (NSBundle *)wsbsdBundle { return [NSBundle bundleWithURL: _url]; }
- (pid_t)processIdentifier { return _pid; }
- (NSURL *)bundleURL { return _url; }
- (NSString *)bundleIdentifier { return [[self wsbsdBundle] bundleIdentifier]; }
- (NSString *)localizedName { NSString *n = [[self wsbsdBundle] objectForInfoDictionaryKey: @"CFBundleName"]; return n ?: [[[_url path] lastPathComponent] stringByDeletingPathExtension]; }
- (NSURL *)executableURL { NSString *p = [[self wsbsdBundle] executablePath]; return p ? [NSURL fileURLWithPath: p] : nil; }
- (BOOL)isActive { return NO; }
- (BOOL)isTerminated { return ![_task isRunning]; }
- (BOOL)terminate { return kill(_pid, SIGTERM) == 0; }
- (BOOL)forceTerminate { return kill(_pid, SIGKILL) == 0; }
@end

@implementation NSWorkspace (WsbsdLaunchAtURL)
- (NSRunningApplication *)launchApplicationAtURL:(NSURL *)url options:(NSUInteger)options configuration:(NSDictionary *)configuration error:(NSError **)error
{
	(void)options; NSBundle *b = [NSBundle bundleWithURL: url]; NSString *exe = [b executablePath];
	if (!exe || ![[NSFileManager defaultManager] isExecutableFileAtPath: exe]) {
		if (error) *error = [NSError errorWithDomain: NSCocoaErrorDomain code: 260 userInfo: @{ NSLocalizedDescriptionKey: [NSString stringWithFormat: @"The application “%@” could not be launched because it is missing or has no executable.", [[url path] lastPathComponent]], NSURLErrorKey: url ?: [NSNull null] }];
		return nil;
	}
	NSTask *t = [[NSTask alloc] init]; [t setLaunchPath: exe]; [t setArguments: configuration[NSWorkspaceLaunchConfigurationArguments] ?: @[]];
	NSDictionary *env = configuration[NSWorkspaceLaunchConfigurationEnvironment]; if (env) { NSMutableDictionary *e = [[[NSProcessInfo processInfo] environment] mutableCopy]; [e addEntriesFromDictionary: env]; [t setEnvironment: e]; }
	@try { [t launch]; } @catch (NSException *x) { if (error) *error = [NSError errorWithDomain: NSCocoaErrorDomain code: 256 userInfo: @{ NSLocalizedDescriptionKey: [x reason] ?: @"launch failed" }]; return nil; }
	return [[WsbsdRunningApplication alloc] initWithPid: [t processIdentifier] bundleURL: url task: t];
}
@end
