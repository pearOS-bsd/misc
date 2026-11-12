/*
 * NSTextLineFragment.h — 1:1 reimplementation (behavioral core) of AppKit/
 * TextKit 2's NSTextLineFragment, one laid-out line within a text layout
 * fragment.
 *
 * Interface evidence (real UIFoundation, re-exported by AppKit.framework,
 * macOS 27 build 26A5416b, arm64e) in evidence/-NSTextLineFragment_interface.txt.
 * Real storage wraps a CTLine plus glyph/advance arrays and cached geometry.
 *
 * This core reproduces the stored content + the measured standalone contract:
 * initWithAttributedString:range: / initWithString:attributes:range: keep the
 * attributed string and character range, and every geometric value is zero until
 * the layout manager lays the fragment out (glyphOrigin={0,0},
 * typographicBounds=CGRectZero, locationForCharacterAtIndex:->{0,0},
 * characterIndexForPoint:->range start). glyphOrigin / typographicBounds have the
 * engine-facing setters; padding, isExtra and textLayoutFragment are stored.
 * The CoreText glyph run layout, drawing and real hit-testing are TODO(stage2).
 */

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@class NSAttributedString, NSTextLayoutFragment;

@interface NSTextLineFragment : NSObject

- (instancetype)initWithAttributedString:(NSAttributedString *)attributedString range:(NSRange)range;
- (instancetype)initWithString:(NSString *)string attributes:(NSDictionary *)attributes range:(NSRange)range;

@property (readonly, strong) NSAttributedString *attributedString;
@property (readonly) NSRange characterRange;
@property (readonly) CGRect typographicBounds;
@property (readonly) CGPoint glyphOrigin;

- (CGPoint)locationForCharacterAtIndex:(NSInteger)index;
- (NSInteger)characterIndexForPoint:(CGPoint)point;

@property double padding;
@property (getter=isExtra) BOOL extra;
@property (nullable, weak) NSTextLayoutFragment *textLayoutFragment;

/* engine-facing geometry setters (used by the layout manager) */
- (void)setGlyphOrigin:(CGPoint)glyphOrigin;
- (void)setTypographicBounds:(CGRect)typographicBounds;

@end

NS_ASSUME_NONNULL_END
