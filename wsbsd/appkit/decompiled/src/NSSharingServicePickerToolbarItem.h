/*
 * NSSharingServicePickerToolbarItem.h — 1:1 reimplementation (behavioral core)
 * of AppKit's NSSharingServicePickerToolbarItem, the toolbar Share button.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSSharingServicePickerToolbarItem_interface.txt. Real ivars:
 * _isShowing, _delegate (weak), _picker, _collapsedPicker. Superclass is
 * NSToolbarItem. It conforms to NSSharingServicePicker/Service/Menu delegates
 * internally.
 *
 * Public surface is just the weak `delegate`
 * (NSSharingServicePickerToolbarItemDelegate, whose required method supplies the
 * items to share). This core models the delegate wiring and the showing state;
 * the NSSharingServicePicker popover, the collapsed picker and the actual
 * share: presentation are TODO(stage2). -share: is provided so the
 * delegate->items path is testable without the picker UI.
 */

#import <Foundation/Foundation.h>
#import "NSToolbarItem.h"

NS_ASSUME_NONNULL_BEGIN

@class NSSharingServicePickerToolbarItem;

@protocol NSSharingServicePickerToolbarItemDelegate <NSObject>
@required
- (NSArray *)itemsForSharingServicePickerToolbarItem:(NSSharingServicePickerToolbarItem *)pickerToolbarItem;
@optional
- (BOOL)validateToolbarItem:(NSToolbarItem *)item;
@end

@interface NSSharingServicePickerToolbarItem : NSToolbarItem

@property (nullable, weak) id<NSSharingServicePickerToolbarItemDelegate> delegate;

/* whether the picker is currently presented (SPI-ish, testable). */
@property (readonly, getter=isShowing) BOOL showing;

- (void)share:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END
