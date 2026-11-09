/*
 * NSTextContainer.h — 1:1 reimplementation (core). NSObject <NSSecureCoding>.
 * Public AppKit text API; ships in UIFoundation in the shared cache.
 *
 * Evidence: interface from the dyld shared cache (UIFoundation, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … UIFoundation --objc`:
 *
 *   @interface NSTextContainer : NSObject <NSSecureCoding, …> {
 *       @"NSLayoutManager" _layoutManager; {CGSize} _size; d _lineFragmentPadding;
 *       Q _maximumLines;
 *       {__tcFlags="widthTracksTextView"b1"heightTracksTextView"b1
 *          "observingFrameChanges"b1"lineBreakMode"b4"oldAPI"b1 …} _tcFlags;
 *       @"NSArray" _exclusionPaths; d _minimumWidth; q _layoutOrientation; …
 *   }
 *   -initWithSize: size lineFragmentPadding maximumNumberOfLines
 *   widthTracksTextView heightTracksTextView lineBreakMode exclusionPaths
 *
 * Holds the text container geometry and tracking flags. The layout manager link
 * and the actual line-fragment geometry (lineFragmentRectForProposedRect:…) are
 * stage2.
 */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "NSParagraphStyle.h"   /* NSLineBreakMode */

NS_ASSUME_NONNULL_BEGIN

@interface NSTextContainer : NSObject

- (instancetype)initWithSize:(CGSize)size;

@property CGSize size;
@property CGFloat lineFragmentPadding;
@property NSUInteger maximumNumberOfLines;
@property NSLineBreakMode lineBreakMode;
@property BOOL widthTracksTextView;
@property BOOL heightTracksTextView;
@property (copy) NSArray *exclusionPaths;

@end

NS_ASSUME_NONNULL_END
