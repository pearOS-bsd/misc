/*
 * NSMediaLibraryBrowserController.h — 1:1 reimplementation (behavioral core) of
 * AppKit's NSMediaLibraryBrowserController, the shared controller for the
 * floating Media Browser panel (Photos/iTunes/Movies picker).
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSMediaLibraryBrowserController_interface.txt.
 *
 * This core reproduces the singleton + its configuration/visibility state:
 * +sharedMediaLibraryBrowserController, visible (NO at rest — measured), frame
 * (CGRectZero at rest), mediaLibraries (NSMediaLibrary mask, 0 at rest), and
 * -togglePanel: which flips visibility. The actual floating panel is owned by
 * the window server, so presenting it is TODO(stage2); the core tracks the
 * requested state so bindings/menus observe it correctly.
 */

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, NSMediaLibrary) {
    NSMediaLibraryAudio = 1 << 0,
    NSMediaLibraryImage = 1 << 1,
    NSMediaLibraryMovie = 1 << 2,
};

@interface NSMediaLibraryBrowserController : NSObject

@property (class, readonly, strong) NSMediaLibraryBrowserController *sharedMediaLibraryBrowserController;

@property (getter=isVisible) BOOL visible;
@property CGRect frame;
@property NSMediaLibrary mediaLibraries;

- (void)togglePanel:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END
