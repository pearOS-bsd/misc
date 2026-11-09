/*
 * NSWindowTab.h — 1:1 reimplementation (core). NSObject.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSWindowTab : NSObject {
 *       @"NSString" _title;  @"NSAttributedString" _attributedTitle;
 *       @"NSString" _toolTip;  @"NSImage" _image;  @"NSView" _accessoryView;
 *       @"NSTabBarItem" _tabBarItem;  @"NSWindow" _window;  B _showIcon;
 *   }
 *   -title -setTitle: -attributedTitle -setAttributedTitle: -toolTip -image
 *   -accessoryView -showIcon -window
 *
 * One tab in a window's tab bar. The core holds the title/attributedTitle/
 * toolTip, the icon image + showIcon flag, an accessory view and the owning
 * window (weak). The tab-bar item and its drawing are stage2.
 */
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSWindowTab : NSObject

@property (null_resettable, copy) NSString *title;
@property (nullable, copy) NSAttributedString *attributedTitle;
@property (nullable, copy) NSString *toolTip;
@property (nullable, strong) id image;            /* NSImage */
@property (nullable, strong) id accessoryView;    /* NSView */
@property BOOL showIcon;
@property (nullable, weak) id window;             /* NSWindow */

@end

NS_ASSUME_NONNULL_END
