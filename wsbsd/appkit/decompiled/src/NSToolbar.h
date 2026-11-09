/*
 * NSToolbar.h — 1:1 reimplementation (core). NSObject.
 * Evidence ../evidence/toolbar: identifier @0x8, _tbFlags @0x88 (displayMode =
 * bits 22-23, allowsUserCustomization = bit 0). isVisible is read off the owning
 * window and items come from the delegate — both stage2.
 */
#import <Foundation/Foundation.h>
@class NSToolbarItem;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, NSToolbarDisplayMode) {
    NSToolbarDisplayModeDefault = 0,
    NSToolbarDisplayModeIconAndLabel = 1,
    NSToolbarDisplayModeIconOnly = 2,
    NSToolbarDisplayModeLabelOnly = 3,
};

@interface NSToolbar : NSObject
- (instancetype)initWithIdentifier:(NSString *)identifier;
@property (readonly, copy) NSString *identifier;
@property NSToolbarDisplayMode displayMode;
@property (getter=isVisible) BOOL visible;
@property BOOL allowsUserCustomization;
@end

NS_ASSUME_NONNULL_END
