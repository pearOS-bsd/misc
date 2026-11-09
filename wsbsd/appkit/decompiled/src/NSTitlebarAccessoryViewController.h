/*
 * NSTitlebarAccessoryViewController.h — 1:1 reimplementation (core).
 * NSViewController subclass.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSTitlebarAccessoryViewController : NSViewController
 *                                            <NSAnimationDelegate, …> {
 *       q _layoutAttribute;  d _fullScreenMinHeight;
 *       B _automaticallyAdjustsSize;  b1 _hidden;  …
 *   }
 *   -layoutAttribute -setLayoutAttribute: -isHidden -setHidden:
 *   -fullScreenMinHeight -setFullScreenMinHeight: -automaticallyAdjustsSize
 *
 * Hosts an accessory view in a window's titlebar. The core tracks the layout
 * attribute, hidden flag, full-screen minimum height and the automatic-size
 * flag. Placement in the real titlebar, the reveal animation and the separator
 * view are stage2.
 */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "NSViewController.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NSLayoutAttribute) {
    NSLayoutAttributeLeft = 1,
    NSLayoutAttributeRight = 2,
    NSLayoutAttributeTop = 3,
    NSLayoutAttributeBottom = 4,
    NSLayoutAttributeLeading = 5,
    NSLayoutAttributeTrailing = 6,
};

@interface NSTitlebarAccessoryViewController : NSViewController

@property NSLayoutAttribute layoutAttribute;
@property (getter=isHidden) BOOL hidden;
@property CGFloat fullScreenMinHeight;
@property BOOL automaticallyAdjustsSize;

@end

NS_ASSUME_NONNULL_END
