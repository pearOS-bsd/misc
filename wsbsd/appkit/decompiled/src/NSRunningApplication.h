/*
 * NSRunningApplication.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSRunningApplication.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSRunningApplication_interface.txt. Real ivars: _asn (the window
 * server application serial number the live state is read through), _pid,
 * _bundleID/_localizedName/_bundleURL/_executableURL/_launchDate/_icon, and a
 * packed _aflags carrying terminated/finishedLaunching/hidden/active/ownsMenuBar/
 * arch/activationPolicy.
 *
 * Measured: the live identity of another process is read through its ASN
 * registration with the window server — in a plain CLI tool +currentApplication
 * returns a degenerate instance. That ASN/LaunchServices path is stage2 on our
 * stack; this core reproduces the *documented* behavior by populating
 * +currentApplication from the running process (pid/bundle/URLs/arch) and makes
 * the state getters consistent. Enumerating or controlling *other* processes
 * (runningApplicationsWithBundleIdentifier:, hide/unhide/activate/terminate of a
 * remote app) is TODO(stage2).
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class NSImage;

typedef NS_ENUM(NSInteger, NSApplicationActivationPolicy) {
    NSApplicationActivationPolicyRegular   = 0,
    NSApplicationActivationPolicyAccessory = 1,
    NSApplicationActivationPolicyProhibited = 2,
};

typedef NS_OPTIONS(NSUInteger, NSApplicationActivationOptions) {
    NSApplicationActivateAllWindows          = 1 << 0,
    NSApplicationActivateIgnoringOtherApps   = 1 << 1,  /* deprecated in AppKit */
};

@interface NSRunningApplication : NSObject

@property (class, readonly, strong) NSRunningApplication *currentApplication;
+ (nullable NSRunningApplication *)runningApplicationWithProcessIdentifier:(pid_t)pid;
+ (NSArray<NSRunningApplication *> *)runningApplicationsWithBundleIdentifier:(NSString *)bundleIdentifier;

@property (readonly, getter=isTerminated) BOOL terminated;
@property (readonly, getter=isFinishedLaunching) BOOL finishedLaunching;
@property (readonly, getter=isHidden) BOOL hidden;
@property (readonly, getter=isActive) BOOL active;
@property (readonly) BOOL ownsMenuBar;
@property (readonly) NSApplicationActivationPolicy activationPolicy;
@property (nullable, readonly, copy) NSString *localizedName;
@property (nullable, readonly, copy) NSString *bundleIdentifier;
@property (nullable, readonly, copy) NSURL *bundleURL;
@property (nullable, readonly, copy) NSURL *executableURL;
@property (readonly) pid_t processIdentifier;
@property (nullable, readonly, copy) NSDate *launchDate;
@property (nullable, readonly, strong) NSImage *icon;
@property (readonly) NSInteger executableArchitecture;

- (BOOL)hide;
- (BOOL)unhide;
- (BOOL)activateWithOptions:(NSApplicationActivationOptions)options;
- (BOOL)terminate;
- (BOOL)forceTerminate;

@end

NS_ASSUME_NONNULL_END
