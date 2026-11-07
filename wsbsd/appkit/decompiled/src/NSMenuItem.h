/*
 * NSMenuItem.h — 1:1 reimplementation of AppKit's NSMenuItem (core).
 *
 * Shape from ../reference/NSMenuItem.h; logic from ../evidence/menuitem.
 * Self-contained (not cell-backed). Shipped: title, action, target (weak),
 * tag, tri-state, separator, submenu, keyEquivalent, the designated initialiser
 * and +separatorItem. Staged: the isEnabled autoenable path through NSApp, and
 * the NSMenu kind-check in setSubmenu: (NSMenu not built yet). TODO(stage2) in .m.
 */
#import <Foundation/Foundation.h>
#import "NSCell.h"   /* NSControlStateValue */

@class NSMenu;

NS_ASSUME_NONNULL_BEGIN

@interface NSMenuItem : NSObject

+ (NSMenuItem *)separatorItem;

- (instancetype)initWithTitle:(NSString *)title
                       action:(nullable SEL)action
                keyEquivalent:(NSString *)keyEquivalent;

@property (copy) NSString *title;
@property (nullable) SEL action;
@property (nullable, weak) id target;
@property NSInteger tag;
@property NSControlStateValue state;
@property (getter=isEnabled) BOOL enabled;
@property (copy) NSString *keyEquivalent;
@property (nullable, strong) NSMenu *submenu;
@property (readonly) BOOL isSeparatorItem;

@end

NS_ASSUME_NONNULL_END
