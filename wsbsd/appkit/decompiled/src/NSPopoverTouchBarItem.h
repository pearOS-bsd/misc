/*
 * NSPopoverTouchBarItem.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSPopoverTouchBarItem, a Touch Bar item that presents a secondary touch bar.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSPopoverTouchBarItem_interface.txt. Superclass is
 * NSTouchBarItem. Real ivars: _popoverTouchBar, _pressAndHoldTouchBar,
 * _customizationLabel, _collapsedRepresentation(/Image/Label), _showsCloseButton,
 * _collapsedRepresentationChevronBehavior, _preventUserDismissal, _overlay.
 *
 * This core reproduces the configuration + presentation state: popoverTouchBar
 * (lazily auto-created, non-nil), pressAndHoldTouchBar, customizationLabel (@""),
 * collapsedRepresentation/Image/Label, collapsedRepresentationShowsChevron (NO),
 * showsCloseButton (YES), and isPresented driven by showPopover:/dismissPopover:.
 * The gesture recognisers, the overlay window and control-strip integration are
 * TODO(stage2).
 */

#import <Foundation/Foundation.h>
#import "NSTouchBarItem.h"

NS_ASSUME_NONNULL_BEGIN

@class NSTouchBar, NSView, NSImage;

@interface NSPopoverTouchBarItem : NSTouchBarItem

@property (strong, null_resettable) NSTouchBar *popoverTouchBar;
@property (nullable, strong) NSTouchBar *pressAndHoldTouchBar;
@property (copy) NSString *customizationLabel;

@property (nullable, strong) NSView *collapsedRepresentation;
@property (nullable, strong) NSImage *collapsedRepresentationImage;
@property (nullable, copy) NSString *collapsedRepresentationLabel;
@property BOOL collapsedRepresentationShowsChevron;

@property BOOL showsCloseButton;
@property (readonly, getter=isPresented) BOOL presented;

- (void)showPopover:(nullable id)sender;
- (void)dismissPopover:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END
