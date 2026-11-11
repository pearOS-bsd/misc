/*
 * NSScrubberLayout.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSScrubberLayout, the abstract base producing an NSScrubber's item layout.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSScrubberLayout_interface.txt.
 *
 * Measured on this Mac (base): shouldInvalidateLayoutForSelectionChange /
 * HighlightChange = NO, automaticallyMirrorsInRightToLeftLayout = YES,
 * scrubberContentSize = zero, +layoutAttributesClass = NSScrubberLayoutAttributes.
 *
 * This core reproduces the abstract base contract: the weak scrubber back-link,
 * the layoutAttributesClass hook, invalidateLayout, and the override points that
 * return empty/nil/zero so concrete subclasses (NSScrubberFlowLayout /
 * NSScrubberProportionalLayout) only override what they compute. The geometry
 * itself is TODO(stage2).
 */

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "NSScrubberLayoutAttributes.h"

NS_ASSUME_NONNULL_BEGIN

@class NSScrubber;

@interface NSScrubberLayout : NSObject <NSCoding>

+ (Class)layoutAttributesClass;

@property (nullable, readonly, weak) NSScrubber *scrubber;
@property (readonly) NSRect visibleRect;
@property (readonly) NSSize scrubberContentSize;
@property (readonly) BOOL shouldInvalidateLayoutForSelectionChange;
@property (readonly) BOOL shouldInvalidateLayoutForHighlightChange;
@property (readonly) BOOL automaticallyMirrorsInRightToLeftLayout;

- (void)invalidateLayout;
- (void)prepareLayout;
- (nullable NSScrubberLayoutAttributes *)layoutAttributesForItemAtIndex:(NSInteger)index;
- (NSSet<NSScrubberLayoutAttributes *> *)layoutAttributesForItemsInRect:(NSRect)rect;
- (BOOL)shouldInvalidateLayoutForChangeFromVisibleRect:(NSRect)fromVisibleRect toVisibleRect:(NSRect)toVisibleRect;

@end

NS_ASSUME_NONNULL_END
