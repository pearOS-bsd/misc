/*
 * NSMenuToolbarItem.h — 1:1 reimplementation (core). NSToolbarItem subclass.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSMenuToolbarItem : NSToolbarItem {
 *       @"NSMenu" _menu;  B _showsIndicator;  @"NSView<…>" _control;
 *       @"NSImage" _image;  @"NSString" _title;  @ _target;  : _action;
 *   }
 *   @property (T@"NSMenu",&) menu;  (TB) showsIndicator;
 *   -menu -setMenu: -showsIndicator -target -setTarget: -action -setAction:
 *
 * A toolbar item that drops a menu. The core tracks the menu, the showsIndicator
 * flag (default YES) and target/action. The pull-down control rendering and the
 * disclosure indicator drawing are stage2.
 */
#import <Foundation/Foundation.h>
#import "NSToolbarItem.h"

NS_ASSUME_NONNULL_BEGIN

@class NSMenu;

@interface NSMenuToolbarItem : NSToolbarItem

@property (nullable, strong) NSMenu *menu;
@property BOOL showsIndicator;
@property (nullable, weak) id target;
@property (nullable) SEL action;

@end

NS_ASSUME_NONNULL_END
