/*
 * NSWindowController.h — 1:1 reimplementation (core). NSResponder subclass.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSWindowController : NSResponder <NSSeguePerforming> {
 *       @"NSWindow" _window;  @"NSString" _windowNibName;  @"NSDocument" _document;
 *       {__wcFlags="shouldCloseDocument"b1"shouldCascade"b1"isLoadingNib"b1
 *          "nibIsLoaded"b1 …} _wcFlags;
 *       @"NSString" _frameAutosaveName; …
 *   }
 *   -initWithWindow: -window -setWindow: -isWindowLoaded -document -setDocument:
 *   -contentViewController -setContentViewController: -windowFrameAutosaveName
 *   -showWindow: -close
 *
 * Owns a window (and, via setContentViewController:, drives the window's content
 * view). The core tracks window/document/contentViewController/autosave name
 * and the nibIsLoaded flag. Nib loading, showWindow: ordering and document
 * close coupling are stage2.
 */
#import <Foundation/Foundation.h>
#import "NSResponder.h"

NS_ASSUME_NONNULL_BEGIN

@class NSWindow, NSViewController;

@interface NSWindowController : NSResponder

- (instancetype)initWithWindow:(nullable NSWindow *)window;

@property (nullable, strong) NSWindow *window;
@property (readonly) BOOL isWindowLoaded;
@property (nullable, weak) id document;
@property (nullable, strong) NSViewController *contentViewController;
@property (copy) NSString *windowFrameAutosaveName;

- (void)showWindow:(nullable id)sender;
- (void)close;

@end

NS_ASSUME_NONNULL_END
