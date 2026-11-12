/*
 * NSTypesetter.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSTypesetter, the abstract TextKit 1 typesetter.
 *
 * Interface evidence (real UIFoundation, re-exported by AppKit.framework,
 * macOS 27 build 26A5416b, arm64e) in evidence/-NSTypesetter_interface.txt.
 * Real ivars are the layout-cursor scratch state.
 *
 * This core reproduces the configuration surface + the shared-instance
 * factories: usesFontLeading (YES), typesetterBehavior (10_4 == default),
 * hyphenationFactor (0), lineFragmentPadding (0), bidiProcessingEnabled (YES),
 * attributedString; +sharedSystemTypesetter (singleton),
 * +sharedSystemTypesetterForBehavior:, +defaultTypesetterBehavior (10_4). The
 * glyph layout engine (layoutParagraphAtPoint:, line-fragment generation) is
 * TODO(stage2).
 */

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NSTypesetterBehavior) {
    NSTypesetterLatestBehavior = -1,
    NSTypesetterOriginalBehavior = 0,
    NSTypesetterBehavior_10_2_WithCompatibility = 1,
    NSTypesetterBehavior_10_2 = 2,
    NSTypesetterBehavior_10_3 = 3,
    NSTypesetterBehavior_10_4 = 4,
};

@interface NSTypesetter : NSObject

@property (class, readonly, strong) NSTypesetter *sharedSystemTypesetter;
+ (NSTypesetter *)sharedSystemTypesetterForBehavior:(NSTypesetterBehavior)behavior;
@property (class, readonly) NSTypesetterBehavior defaultTypesetterBehavior;

@property BOOL usesFontLeading;
@property NSTypesetterBehavior typesetterBehavior;
@property float hyphenationFactor;
@property CGFloat lineFragmentPadding;
@property BOOL bidiProcessingEnabled;
@property (nullable, strong) NSAttributedString *attributedString;

@end

NS_ASSUME_NONNULL_END
