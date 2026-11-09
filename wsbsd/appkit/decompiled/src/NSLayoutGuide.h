/*
 * NSLayoutGuide.h — 1:1 reimplementation (core). NSObject <NSCoding,
 * NSUserInterfaceItemIdentification>.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSLayoutGuide : NSObject <NSLayoutSpacingItem, NSCoding,
 *                                         NSUserInterfaceItemIdentification> {
 *       @ _owningView;  @"NSString" _identifier;
 *       @"NSISVariable" _minYVariable/_minXVariable/_widthVariable/_heightVariable;
 *       @"NSLayoutXAxisAnchor" _left/_right/_leading/_trailing/_centerX;
 *       @"NSLayoutYAxisAnchor" _top/_bottom/_centerY;
 *       @"NSLayoutDimension" _width/_height;
 *       {CGRect} _frame;  {CGRect} _internalFrame;  q _piercingToken;
 *   }
 *   owningView identifier frame leadingAnchor trailingAnchor topAnchor …
 *
 * A rectangular region that participates in Auto Layout without a backing view.
 * owningView / identifier / frame are the value core; the layout anchors
 * (NSLayoutXAxisAnchor/…) and the NSISEngine variables that actually solve the
 * frame are stage2.
 */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSLayoutGuide : NSObject

@property (nullable, weak) id owningView;
@property (copy) NSString *identifier;
@property (readonly) CGRect frame;

/* Window-server / engine glue sets the solved frame here (stage2 upstream). */
- (void)_setFrame:(CGRect)frame;

@end

NS_ASSUME_NONNULL_END
