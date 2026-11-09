/*
 * NSHelpManager.h — 1:1 reimplementation (core). NSObject.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSHelpManager : NSObject {
 *       @"NSMapTable" _helpMapTable;  @"NSMapTable" _keyMapTable;
 *       @"NSMapTable" _bundleMapTable;  @"NSWindow" _helpWindow; …
 *   }
 *   +sharedHelpManager +isContextHelpModeActive +setContextHelpModeActive:
 *   -setContextHelp:forObject: -contextHelpForObject: -removeContextHelpForObject:
 *
 * The shared manager keeps a map from objects to their context-help text and a
 * global context-help-mode flag. The help-book/window presentation and the
 * event-driven help cursor are stage2.
 */
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSHelpManager : NSObject

@property (class, readonly, strong) NSHelpManager *sharedHelpManager;
@property (class, getter=isContextHelpModeActive) BOOL contextHelpModeActive;

- (void)setContextHelp:(NSAttributedString *)helpString forObject:(id)object;
- (nullable NSAttributedString *)contextHelpForObject:(id)object;
- (void)removeContextHelpForObject:(id)object;

@end

NS_ASSUME_NONNULL_END
