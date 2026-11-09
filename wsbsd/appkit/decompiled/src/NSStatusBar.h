/*
 * NSStatusBar.h — 1:1 reimplementation (core). NSObject.
 * Evidence ../evidence/statusbar: +systemStatusBar is a cached singleton,
 * thickness is the constant 20.0, isVertical is NO, statusItemWithLength: builds
 * an NSStatusItem (with system priority 1000). Menu-bar placement is stage2.
 */
#import <Foundation/Foundation.h>
#import "NSStatusItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSStatusBar : NSObject
@property (class, readonly, strong) NSStatusBar *systemStatusBar;
@property (readonly) CGFloat thickness;
@property (getter=isVertical, readonly) BOOL vertical;
- (NSStatusItem *)statusItemWithLength:(CGFloat)length;
- (void)removeStatusItem:(NSStatusItem *)item;
@end

NS_ASSUME_NONNULL_END
