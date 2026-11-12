/*
 * NSTextSelection.h — 1:1 reimplementation (behavioral core) of AppKit/TextKit 2's
 * NSTextSelection.
 *
 * Interface evidence (real UIFoundation, re-exported by AppKit.framework,
 * macOS 27 build 26A5416b, arm64e) in evidence/-NSTextSelection_interface.txt.
 * Real ivars: _typingAttributes, _transient, _logical, _textRanges,
 * _granularity, _affinity, _anchorPositionOffset, _secondarySelectionLocation,
 * _selectionAnchorLocation.
 *
 * An immutable-ish selection = one or more NSTextRanges plus a granularity and
 * affinity. This core reproduces the three initialisers, the stored attributes,
 * containsLocation:/textRangeContainingLocation:, textSelectionWithTextRanges:
 * (derives a new selection keeping affinity/granularity) and equality. Measured
 * defaults: transient=NO, logical=NO, anchorPositionOffset=0, typingAttributes=
 * nil; initWithLocation:affinity: yields one empty range with Character
 * granularity. NSSecureCoding archiving is TODO(stage2).
 */

#import <Foundation/Foundation.h>
#import "NSTextRange.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NSTextSelectionGranularity) {
    NSTextSelectionGranularityCharacter = 0,
    NSTextSelectionGranularityWord = 1,
    NSTextSelectionGranularityParagraph = 2,
    NSTextSelectionGranularityLine = 3,
    NSTextSelectionGranularitySentence = 4,
};

typedef NS_ENUM(NSInteger, NSTextSelectionAffinity) {
    NSTextSelectionAffinityUpstream = 0,
    NSTextSelectionAffinityDownstream = 1,
};

@interface NSTextSelection : NSObject

- (instancetype)initWithRanges:(NSArray<NSTextRange *> *)textRanges
                      affinity:(NSTextSelectionAffinity)affinity
                   granularity:(NSTextSelectionGranularity)granularity;
- (instancetype)initWithRange:(NSTextRange *)range
                     affinity:(NSTextSelectionAffinity)affinity
                  granularity:(NSTextSelectionGranularity)granularity;
- (instancetype)initWithLocation:(id<NSTextLocation>)location
                        affinity:(NSTextSelectionAffinity)affinity;

@property (readonly, copy) NSArray<NSTextRange *> *textRanges;
@property (readonly) NSTextSelectionGranularity granularity;
@property (readonly) NSTextSelectionAffinity affinity;
@property (getter=isTransient) BOOL transient;
@property (getter=isLogical) BOOL logical;
@property double anchorPositionOffset;
@property (nullable, strong) id<NSTextLocation> selectionAnchorLocation;
@property (nullable, strong) id<NSTextLocation> secondarySelectionLocation;
@property (nullable, copy) NSDictionary *typingAttributes;

- (NSTextSelection *)textSelectionWithTextRanges:(NSArray<NSTextRange *> *)textRanges;
- (BOOL)isEqualToTextSelection:(NSTextSelection *)textSelection;

- (BOOL)containsLocation:(id<NSTextLocation>)location;
- (nullable NSTextRange *)textRangeContainingLocation:(id<NSTextLocation>)location;

@end

NS_ASSUME_NONNULL_END
