/*
 * NSCustomTouchBarItem.h — 1:1 reimplementation (core). NSTouchBarItem subclass.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSCustomTouchBarItem : NSTouchBarItem {
 *       @"NSView" _view;  @"NSViewController" _viewController;
 *       @"NSString" _customizationLabel;  …
 *   }
 *   -view -setView: -viewController -setViewController: -customizationLabel
 *
 * A touch-bar item that shows a custom view (or a view controller's view). The
 * core makes view/viewController/customizationLabel read-write (the base's
 * read-only properties). The customization palette preview is stage2.
 */
#import <Foundation/Foundation.h>
#import "NSTouchBarItem.h"

NS_ASSUME_NONNULL_BEGIN

@class NSView, NSViewController;

@interface NSCustomTouchBarItem : NSTouchBarItem

@property (nullable, strong) NSView *view;
@property (nullable, strong) NSViewController *viewController;
@property (nullable, copy) NSString *customizationLabel;

@end

NS_ASSUME_NONNULL_END
