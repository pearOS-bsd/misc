/*
 * NSSharingServicePicker.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSSharingServicePicker, the share-sheet presenter (pairs with NSSharingService).
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSSharingServicePicker_interface.txt. Real ivars: shareServices,
 * mainServices, _applicationServices, _excludedSharingServiceNames, owner, and
 * the rollover menu/layers used for presentation.
 *
 * Measured on this Mac: initWithItems: accepts any item array (empty included);
 * standardShareMenuItem returns a non-nil NSMenuItem titled "Share…" with no
 * submenu (the service menu is built lazily at present time).
 *
 * This core reproduces the picker's identity (shared items, delegate, excluded
 * service names) and the standard share menu item. Enumerating the system share
 * services for the items and the popover/menu presentation
 * (showRelativeToRect:ofView:preferredEdge:) are TODO(stage2).
 */

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

@class NSView, NSMenuItem;

NS_ASSUME_NONNULL_BEGIN

@protocol NSSharingServicePickerDelegate <NSObject>
@end

@interface NSSharingServicePicker : NSObject

- (instancetype)initWithItems:(NSArray *)items NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property (nullable, weak) id<NSSharingServicePickerDelegate> delegate;
@property (nullable, copy) NSArray<NSString *> *excludedSharingServiceNames;
@property (readonly, strong) NSMenuItem *standardShareMenuItem;

- (void)showRelativeToRect:(NSRect)rect ofView:(NSView *)view preferredEdge:(NSRectEdge)preferredEdge;
- (void)close;

@end

NS_ASSUME_NONNULL_END
