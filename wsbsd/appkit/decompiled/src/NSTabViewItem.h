/*
 * NSTabViewItem.h — 1:1 reimplementation (core). NSObject.
 * Evidence ../evidence/tab: identifier @0x8 (objc_getProperty, copy), label @0x10,
 * a view, and the owning tab view. (label is kept plainly; the shipping item
 * routes it through a contents helper — stage2.)
 */
#import <Foundation/Foundation.h>
@class NSView, NSTabView, NSViewController;

NS_ASSUME_NONNULL_BEGIN

@interface NSTabViewItem : NSObject
- (instancetype)initWithIdentifier:(nullable id)identifier;
/* Modern convenience: an item backed by a view controller (its identifier is
 * the controller and its view is the controller's view). */
+ (instancetype)tabViewItemWithViewController:(NSViewController *)viewController;
@property (nullable, copy) id identifier;
@property (copy) NSString *label;
@property (nullable, strong) NSView *view;
@property (nullable, strong) NSViewController *viewController;
@end

NS_ASSUME_NONNULL_END
