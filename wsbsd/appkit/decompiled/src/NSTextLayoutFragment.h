/*
 * NSTextLayoutFragment.h — 1:1 reimplementation (behavioral core) of AppKit/
 * TextKit 2's NSTextLayoutFragment, the laid-out geometry for one text element.
 *
 * Interface evidence (real UIFoundation, re-exported by AppKit.framework,
 * macOS 27 build 26A5416b, arm64e) in evidence/-NSTextLayoutFragment_interface.txt.
 *
 * This core reproduces construction (initWithTextElement:range: keeps the SAME
 * element + range) and the measured pre-layout state: textLineFragments=nil,
 * state=None(0), layoutFragmentFrame / renderingSurfaceBounds zero,
 * textLayoutManager nil until the manager lays it out. -invalidateLayout resets
 * the fragment. The glyph layout that fills the line fragments and frames is
 * TODO(stage2); the engine-facing setters let the manager populate them.
 */

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "NSTextRange.h"

NS_ASSUME_NONNULL_BEGIN

@class NSTextElement, NSTextLayoutManager, NSTextLineFragment;

typedef NS_ENUM(NSInteger, NSTextLayoutFragmentState) {
    NSTextLayoutFragmentStateNone = 0,
    NSTextLayoutFragmentStateEstimatedUsageBounds = 1,
    NSTextLayoutFragmentStateCalculatedUsageBounds = 2,
    NSTextLayoutFragmentStateLayoutAvailable = 3,
};

@interface NSTextLayoutFragment : NSObject

- (instancetype)initWithTextElement:(NSTextElement *)textElement range:(nullable NSTextRange *)rangeInElement;

@property (readonly, weak, nullable) NSTextLayoutManager *textLayoutManager;
@property (readonly, weak, nullable) NSTextElement *textElement;
@property (readonly, nullable) NSTextRange *rangeInElement;
@property (readonly, copy, nullable) NSArray<NSTextLineFragment *> *textLineFragments;
@property NSTextLayoutFragmentState state;
@property (readonly) CGRect layoutFragmentFrame;
@property (readonly) CGRect renderingSurfaceBounds;

- (void)invalidateLayout;

/* engine-facing setters used by the layout manager */
- (void)setTextLayoutManager:(nullable NSTextLayoutManager *)textLayoutManager;
- (void)setTextLineFragments:(nullable NSArray<NSTextLineFragment *> *)textLineFragments;
- (void)setLayoutFragmentFrame:(CGRect)layoutFragmentFrame;

@end

NS_ASSUME_NONNULL_END
