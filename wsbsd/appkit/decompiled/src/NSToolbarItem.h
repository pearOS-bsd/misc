/*
 * NSToolbarItem.h — 1:1 reimplementation (core). NSObject.
 * Evidence ../evidence/tbitem: itemIdentifier @0x28, label @0x30 (nil -> ""),
 * tag @0x58, view @0x78, flags @0xc8 (enabled bit, explicit-tag bit). The
 * flag-gated _loadViewIfNecessary path is stage2; we store the properties plainly.
 */
#import <Foundation/Foundation.h>
@class NSView, NSImage, NSMenuItem;

NS_ASSUME_NONNULL_BEGIN

@interface NSToolbarItem : NSObject
- (instancetype)initWithItemIdentifier:(NSString *)itemIdentifier;
@property (readonly, copy) NSString *itemIdentifier;
@property (copy) NSString *label;
@property (copy) NSString *paletteLabel;
@property (nullable, copy) NSString *toolTip;
@property NSInteger tag;
@property (getter=isEnabled) BOOL enabled;
@property (nullable, strong) NSView *view;
@end

NS_ASSUME_NONNULL_END
