/*
 * NSTextView.h — 1:1 reimplementation (behavioral core) of AppKit's NSTextView,
 * the concrete rich-text editing view.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSTextView_interface.txt.
 *
 * NSTextView is an NSText (measured). This core reproduces the configuration
 * surface on top of NSText: the auto-created textContainer, textContainerInset,
 * allowsUndo, the spell/grammar/substitution flags (all defaults measured),
 * usesRuler/usesFindPanel/usesFindBar/usesInspectorBar, rulerVisible and
 * insertionPointColor. The layout/drawing/editing pipeline and the find &
 * inspector UI are TODO(stage2).
 */

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "NSText.h"

NS_ASSUME_NONNULL_BEGIN

@class NSTextContainer, NSColor;

@interface NSTextView : NSText

- (instancetype)initWithFrame:(CGRect)frameRect textContainer:(nullable NSTextContainer *)container;

@property (nullable, strong) NSTextContainer *textContainer;
@property CGSize textContainerInset;
@property BOOL allowsUndo;

@property (getter=isContinuousSpellCheckingEnabled) BOOL continuousSpellCheckingEnabled;
@property (getter=isGrammarCheckingEnabled) BOOL grammarCheckingEnabled;
@property (getter=isAutomaticQuoteSubstitutionEnabled) BOOL automaticQuoteSubstitutionEnabled;
@property (getter=isAutomaticLinkDetectionEnabled) BOOL automaticLinkDetectionEnabled;
@property (getter=isAutomaticDashSubstitutionEnabled) BOOL automaticDashSubstitutionEnabled;
@property (getter=isAutomaticTextReplacementEnabled) BOOL automaticTextReplacementEnabled;
@property BOOL smartInsertDeleteEnabled;

@property BOOL usesRuler;
@property BOOL usesFindPanel;
@property BOOL usesFindBar;
@property BOOL usesInspectorBar;
@property (getter=isRulerVisible) BOOL rulerVisible;
@property (nullable, strong) NSColor *insertionPointColor;

@end

NS_ASSUME_NONNULL_END
