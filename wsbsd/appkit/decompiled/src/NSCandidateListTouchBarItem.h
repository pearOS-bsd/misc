/*
 * NSCandidateListTouchBarItem.h — 1:1 reimplementation (behavioral core) of
 * AppKit's NSCandidateListTouchBarItem, the Touch Bar item that shows text
 * input / completion candidates.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSCandidateListTouchBarItem_interface.txt. Superclass is
 * NSTouchBarItem. Real ivars: _candidateViewController,
 * _inputContextViewController, _customizationLabel, a flags bitfield.
 *
 * This core reproduces the configuration + candidate model: client/delegate
 * (weak), collapsed/allowsCollapsing, allowsTextInputContextCandidates,
 * attributedStringForCandidate (formatting block), candidates (set via
 * setCandidates:forSelectedRange:inString:), customizationLabel. candidateList-
 * Visible == !isCollapsed (measured standalone). The candidate view controller,
 * the position animation and the IM/completion plumbing are TODO(stage2).
 */

#import <Foundation/Foundation.h>
#import "NSTouchBarItem.h"

NS_ASSUME_NONNULL_BEGIN

@class NSCandidateListTouchBarItem, NSAttributedString;

@protocol NSCandidateListTouchBarItemDelegate <NSObject>
@optional
- (void)candidateListTouchBarItem:(NSCandidateListTouchBarItem *)anItem beginSelectingCandidateAtIndex:(NSInteger)index;
- (void)candidateListTouchBarItem:(NSCandidateListTouchBarItem *)anItem changeSelectionFromCandidateAtIndex:(NSInteger)previousIndex toIndex:(NSInteger)index;
- (void)candidateListTouchBarItem:(NSCandidateListTouchBarItem *)anItem endSelectingCandidateAtIndex:(NSInteger)index;
- (void)candidateListTouchBarItem:(NSCandidateListTouchBarItem *)anItem changedCandidateListVisibility:(BOOL)isVisible;
@end

@interface NSCandidateListTouchBarItem : NSTouchBarItem

@property (nullable, weak) id client;
@property (nullable, weak) id<NSCandidateListTouchBarItemDelegate> delegate;

@property (getter=isCollapsed) BOOL collapsed;
@property BOOL allowsCollapsing;
@property (readonly, getter=isCandidateListVisible) BOOL candidateListVisible;
@property BOOL allowsTextInputContextCandidates;

@property (nullable, copy) NSAttributedString *(^attributedStringForCandidate)(id candidate, NSInteger index);

@property (readonly, copy) NSArray *candidates;
@property (copy) NSString *customizationLabel;

- (void)setCandidates:(NSArray *)candidates forSelectedRange:(NSRange)selectedRange inString:(nullable NSString *)originalString;

@end

NS_ASSUME_NONNULL_END
