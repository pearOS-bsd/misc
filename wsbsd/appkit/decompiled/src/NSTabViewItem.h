/*
 * NSTabViewItem.h — 1:1 reimplementation (core). NSObject.
 * Evidence ../evidence/tab: identifier @0x8 (objc_getProperty, copy), label @0x10,
 * a view, and the owning tab view. (label is kept plainly; the shipping item
 * routes it through a contents helper — stage2.)
 */
#import <Foundation/Foundation.h>
@class NSView, NSTabView;

NS_ASSUME_NONNULL_BEGIN

@interface NSTabViewItem : NSObject
- (instancetype)initWithIdentifier:(nullable id)identifier;
@property (nullable, copy) id identifier;
@property (copy) NSString *label;
@property (nullable, strong) NSView *view;
@end

NS_ASSUME_NONNULL_END
