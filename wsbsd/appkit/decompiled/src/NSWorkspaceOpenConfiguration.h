/*
 * NSWorkspaceOpenConfiguration.h — 1:1 reimplementation of AppKit's
 * NSWorkspaceOpenConfiguration, the options bag passed to the NSWorkspace
 * openURL(s)/openApplication APIs.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSWorkspaceOpenConfiguration_interface.txt. It is a plain value
 * object (<NSCopying>) that LaunchServices reads; there is no stage2 here — the
 * behaviour is the option storage itself, reproduced 1:1 with the defaults
 * measured on this Mac.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class NSAppleEventDescriptor;

@interface NSWorkspaceOpenConfiguration : NSObject <NSCopying>

+ (instancetype)configuration;

@property BOOL promptsUserIfNeeded;                       /* YES */
@property BOOL addsToRecentItems;                         /* YES */
@property BOOL activates;                                 /* YES */
@property BOOL hides;                                     /* NO  */
@property BOOL hidesOthers;                               /* NO  */
@property (getter=isForPrinting) BOOL forPrinting;        /* NO  */
@property BOOL createsNewApplicationInstance;             /* NO  */
@property BOOL allowsRunningApplicationSubstitution;      /* YES */
@property BOOL requiresUniversalLinks;                    /* NO  */
@property int architecture;                               /* default -1 */
@property (copy) NSArray<NSString *> *arguments;          /* empty */
@property (copy) NSDictionary<NSString *, NSString *> *environment; /* empty */
@property (nullable, strong) NSAppleEventDescriptor *appleEvent;   /* nil */

@end

NS_ASSUME_NONNULL_END
