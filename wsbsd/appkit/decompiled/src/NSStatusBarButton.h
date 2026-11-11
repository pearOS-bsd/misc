/*
 * NSStatusBarButton.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSStatusBarButton (: NSButton), the button inside an NSStatusItem.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSStatusBarButton_interface.txt.
 *
 * Public: appearsDisabled (default NO) dims the button while keeping it
 * clickable. This core reproduces appearsDisabled plus the doubleAction and
 * statusMenu accessories. The dimming draw (looksDisabled → reduced alpha),
 * selectionInset highlight geometry and right-click/status-menu behaviour are
 * TODO(stage2).
 */

#import "NSButton.h"

NS_ASSUME_NONNULL_BEGIN

@class NSMenu;

@interface NSStatusBarButton : NSButton

@property BOOL appearsDisabled;                 /* default NO */
@property SEL doubleAction;
@property (nullable, strong) NSMenu *statusMenu;

@end

NS_ASSUME_NONNULL_END
