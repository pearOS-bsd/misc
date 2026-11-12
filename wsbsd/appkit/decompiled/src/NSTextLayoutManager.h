/*
 * NSTextLayoutManager.h — 1:1 reimplementation (behavioral core) of AppKit/
 * TextKit 2's NSTextLayoutManager, which lays a content manager's elements into
 * a text container.
 *
 * Interface evidence (real UIFoundation, re-exported by AppKit.framework,
 * macOS 27 build 26A5416b, arm64e) in evidence/-NSTextLayoutManager_interface.txt.
 *
 * This core reproduces the configuration + wiring model: delegate,
 * textContentManager (set when added to a manager), textContainer, the layout
 * flags usesFontLeading (YES) / usesHyphenation (NO) /
 * limitsLayoutForSuspiciousContents (NO) (measured), textSelections (nil by
 * default — measured), documentRange delegated to the content manager, and the
 * lazily-created textSelectionNavigation. The glyph layout engine —
 * usageBoundsForTextContainer, enumerateTextLayoutFragments…, the viewport
 * controller — is TODO(stage2) and reports empty.
 */

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "NSTextRange.h"

NS_ASSUME_NONNULL_BEGIN

@class NSTextContentManager, NSTextContainer, NSTextSelectionNavigation, NSTextLayoutManager;

@protocol NSTextLayoutManagerDelegate <NSObject>
@optional
- (void)textLayoutManager:(NSTextLayoutManager *)textLayoutManager didInvalidateLayout:(NSTextRange *)range;
@end

@interface NSTextLayoutManager : NSObject

@property (nullable, weak) id<NSTextLayoutManagerDelegate> delegate;
@property (readonly, weak, nullable) NSTextContentManager *textContentManager;
@property (nullable, strong) NSTextContainer *textContainer;

@property BOOL usesFontLeading;
@property BOOL limitsLayoutForSuspiciousContents;
@property BOOL usesHyphenation;

@property (nullable, copy) NSArray *textSelections;
@property (readonly, strong, nullable) NSTextSelectionNavigation *textSelectionNavigation;
@property (readonly, nullable) NSTextRange *documentRange;
@property (readonly) CGRect usageBoundsForTextContainer;

/* readonly in the public API; set when the content manager adopts us. */
- (void)setTextContentManager:(nullable NSTextContentManager *)textContentManager;

@end

NS_ASSUME_NONNULL_END
