/*
 * NSStatusItem.h — 1:1 reimplementation (core). NSObject.
 * Evidence ../evidence/status: length @0x10 (double; special values -1 variable,
 * -2 square), menu stored, visibility derived from a flags word @0xe8. The
 * status-bar button and the menu-bar placement are stage2.
 */
#import <Foundation/Foundation.h>
@class NSMenu, NSStatusBar;

NS_ASSUME_NONNULL_BEGIN

static const CGFloat NSVariableStatusItemLength = -1.0;
static const CGFloat NSSquareStatusItemLength = -2.0;

@interface NSStatusItem : NSObject
@property CGFloat length;
@property (nullable, strong) NSMenu *menu;
@property (getter=isVisible) BOOL visible;
@end

NS_ASSUME_NONNULL_END
