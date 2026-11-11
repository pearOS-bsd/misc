/*
 * NSRunningApplication.m — behavioral-1:1 core.
 * See NSRunningApplication.h (ASN/window-server path + remote-process control
 * are stage2; +currentApplication is populated from the live process).
 */

#import "NSRunningApplication.h"
#import <unistd.h>

/* NSBundle executable-architecture constants (Foundation). */
#ifndef NSBundleExecutableArchitectureARM64
#define NSBundleExecutableArchitectureARM64  0x0100000c
#endif
#ifndef NSBundleExecutableArchitectureX86_64
#define NSBundleExecutableArchitectureX86_64 0x01000007
#endif

@implementation NSRunningApplication {
    pid_t _pid;
    NSString *_bundleID;
    NSString *_localizedName;
    NSURL *_bundleURL;
    NSURL *_executableURL;
    NSDate *_launchDate;
    NSApplicationActivationPolicy _activationPolicy;
    NSInteger _executableArchitecture;
    BOOL _active, _finishedLaunching, _hidden, _terminated;
}

+ (NSRunningApplication *)currentApplication
{
    static NSRunningApplication *current;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        current = [[NSRunningApplication alloc] _initAsCurrent];
    });
    return current;
}

- (instancetype)_initAsCurrent
{
    self = [super init];
    if (self) {
        NSBundle *main = [NSBundle mainBundle];
        NSProcessInfo *pi = [NSProcessInfo processInfo];
        _pid = getpid();
        _bundleID = [main bundleIdentifier];
        _bundleURL = [main bundleURL];
        _executableURL = [main executableURL];
        _localizedName = [main objectForInfoDictionaryKey:@"CFBundleName"] ?: pi.processName;
        _launchDate = [NSDate date];   /* stage2: exact process start time */
        _active = YES;
        _finishedLaunching = YES;
        _hidden = NO;
        _terminated = NO;

        /* activation policy from Info.plist (LSBackgroundOnly / LSUIElement) */
        id bg = [main objectForInfoDictionaryKey:@"LSBackgroundOnly"];
        id ui = [main objectForInfoDictionaryKey:@"LSUIElement"];
        if ([bg boolValue]) _activationPolicy = NSApplicationActivationPolicyProhibited;
        else if ([ui boolValue]) _activationPolicy = NSApplicationActivationPolicyAccessory;
        else _activationPolicy = NSApplicationActivationPolicyRegular;

#if defined(__arm64__) || defined(__aarch64__)
        _executableArchitecture = NSBundleExecutableArchitectureARM64;
#else
        _executableArchitecture = NSBundleExecutableArchitectureX86_64;
#endif
    }
    return self;
}

+ (NSRunningApplication *)runningApplicationWithProcessIdentifier:(pid_t)pid
{
    if (pid == getpid()) return [self currentApplication];
    return nil;  /* TODO(stage2): resolve an arbitrary pid via the process table/ASN */
}

+ (NSArray<NSRunningApplication *> *)runningApplicationsWithBundleIdentifier:(NSString *)bundleIdentifier
{
    NSRunningApplication *cur = [self currentApplication];
    if (bundleIdentifier && [cur.bundleIdentifier isEqual:bundleIdentifier]) return @[cur];
    return @[];  /* TODO(stage2): enumerate all registered apps */
}

/* --- live identity --- */

- (pid_t)processIdentifier { return _pid; }
- (NSString *)bundleIdentifier { return _bundleID; }
- (NSString *)localizedName { return _localizedName; }
- (NSURL *)bundleURL { return _bundleURL; }
- (NSURL *)executableURL { return _executableURL; }
- (NSDate *)launchDate { return _launchDate; }
- (NSImage *)icon { return nil; /* stage2: NSWorkspace icon */ }
- (NSApplicationActivationPolicy)activationPolicy { return _activationPolicy; }
- (NSInteger)executableArchitecture { return _executableArchitecture; }
- (BOOL)isActive { return _active; }
- (BOOL)isFinishedLaunching { return _finishedLaunching; }
- (BOOL)isHidden { return _hidden; }
- (BOOL)isTerminated { return _terminated; }
- (BOOL)ownsMenuBar { return _active; /* stage2: real menu-bar ownership from the server */ }

/* --- control (stage2: drive the window server / signals) --- */

- (BOOL)hide { return NO; }
- (BOOL)unhide { return NO; }
- (BOOL)activateWithOptions:(NSApplicationActivationOptions)options { return NO; }
- (BOOL)terminate { return NO; }
- (BOOL)forceTerminate { return NO; }

/* --- identity: equal by pid (matches AppKit) --- */

- (BOOL)isEqual:(id)other
{
    if (self == other) return YES;
    if (![other isKindOfClass:[NSRunningApplication class]]) return NO;
    return _pid == ((NSRunningApplication *)other).processIdentifier;
}
- (NSUInteger)hash { return (NSUInteger)_pid; }

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p (%@, pid %d)>", [self class], self, _bundleID ?: _localizedName, _pid];
}

@end
