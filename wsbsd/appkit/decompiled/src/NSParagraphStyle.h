/*
 * NSParagraphStyle.h / NSMutableParagraphStyle — 1:1 reimplementation (core).
 * Public AppKit text API; physically ships in UIFoundation in the shared cache.
 *
 * Evidence: interface from the dyld shared cache (UIFoundation, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … UIFoundation --objc`:
 *
 *   @interface NSParagraphStyle : NSObject <NSCopying, NSMutableCopying,
 *                                            NSSecureCoding> {
 *       d _lineSpacing; d _paragraphSpacing; d _headIndent; d _tailIndent;
 *       d _firstLineHeadIndent; d _minimumLineHeight; d _maximumLineHeight;
 *       @"NSArray" _tabStops;
 *       {?="alignment"b4 "lineBreakMode"b4 "tabStopsIsMutable"b1
 *         "isNaturalDirection"b1 "rightToLeftDirection"b1 "fixedMultiple"b2
 *         "tightensForTruncation"b1 "refCount"b18} _flags;
 *       d _defaultTabInterval;
 *       @"NSParagraphStyleExtraData" _extraData;   // lineHeightMultiple,
 *                                                  // paragraphSpacingBefore,
 *                                                  // hyphenationFactor, …
 *   }
 *   @property (Tq,R) alignment;  (TQ,R) lineBreakMode;  (Tq,R) baseWritingDirection;
 *   (Td,R) lineSpacing/paragraphSpacing/headIndent/tailIndent/firstLineHeadIndent
 *          /minimumLineHeight/maximumLineHeight/lineHeightMultiple
 *          /paragraphSpacingBefore/defaultTabInterval;
 *   (Tf,R) hyphenationFactor;  (T@"NSArray",R,C) tabStops;
 *   +defaultParagraphStyle;  +defaultWritingDirectionForLanguage:;
 *
 * The _flags bitfield packs alignment (b0-3) and lineBreakMode (b4-7); the rest
 * of the properties live in ivars / _extraData. Per the work model we match the
 * observable contract, not Apple's exact ivar/_extraData packing. Markdown /
 * presentation-intent / textLists / textBlocks are stage2.
 */
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NSTextAlignment) {
    NSTextAlignmentLeft = 0,
    NSTextAlignmentRight = 1,
    NSTextAlignmentCenter = 2,
    NSTextAlignmentJustified = 3,
    NSTextAlignmentNatural = 4,
};

typedef NS_ENUM(NSUInteger, NSLineBreakMode) {
    NSLineBreakByWordWrapping = 0,
    NSLineBreakByCharWrapping = 1,
    NSLineBreakByClipping = 2,
    NSLineBreakByTruncatingHead = 3,
    NSLineBreakByTruncatingTail = 4,
    NSLineBreakByTruncatingMiddle = 5,
};

typedef NS_ENUM(NSInteger, NSParagraphWritingDirection) {
    NSParagraphWritingDirectionNatural = -1,
    NSParagraphWritingDirectionLeftToRight = 0,
    NSParagraphWritingDirectionRightToLeft = 1,
};

@interface NSParagraphStyle : NSObject <NSCopying, NSMutableCopying>

@property (class, readonly, copy) NSParagraphStyle *defaultParagraphStyle;

@property (readonly) CGFloat lineSpacing;
@property (readonly) CGFloat paragraphSpacing;
@property (readonly) NSTextAlignment alignment;
@property (readonly) CGFloat headIndent;
@property (readonly) CGFloat tailIndent;
@property (readonly) CGFloat firstLineHeadIndent;
@property (readonly) CGFloat minimumLineHeight;
@property (readonly) CGFloat maximumLineHeight;
@property (readonly) NSLineBreakMode lineBreakMode;
@property (readonly) NSInteger baseWritingDirection;
@property (readonly) CGFloat lineHeightMultiple;
@property (readonly) CGFloat paragraphSpacingBefore;
@property (readonly) float hyphenationFactor;
@property (readonly) CGFloat defaultTabInterval;
@property (readonly, copy) NSArray *tabStops;
@property (readonly) BOOL allowsDefaultTighteningForTruncation;

@end

@interface NSMutableParagraphStyle : NSParagraphStyle

@property (readwrite) CGFloat lineSpacing;
@property (readwrite) CGFloat paragraphSpacing;
@property (readwrite) NSTextAlignment alignment;
@property (readwrite) CGFloat headIndent;
@property (readwrite) CGFloat tailIndent;
@property (readwrite) CGFloat firstLineHeadIndent;
@property (readwrite) CGFloat minimumLineHeight;
@property (readwrite) CGFloat maximumLineHeight;
@property (readwrite) NSLineBreakMode lineBreakMode;
@property (readwrite) NSInteger baseWritingDirection;
@property (readwrite) CGFloat lineHeightMultiple;
@property (readwrite) CGFloat paragraphSpacingBefore;
@property (readwrite) float hyphenationFactor;
@property (readwrite) CGFloat defaultTabInterval;
@property (readwrite, copy) NSArray *tabStops;
@property (readwrite) BOOL allowsDefaultTighteningForTruncation;

- (void)setParagraphStyle:(NSParagraphStyle *)obj;

@end

NS_ASSUME_NONNULL_END
