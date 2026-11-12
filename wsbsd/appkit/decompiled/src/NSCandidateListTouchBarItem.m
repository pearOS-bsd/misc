/*
 * NSCandidateListTouchBarItem.m — behavioral-1:1 core. See the header.
 */

#import "NSCandidateListTouchBarItem.h"

@implementation NSCandidateListTouchBarItem {
    __weak id _client;
    __weak id<NSCandidateListTouchBarItemDelegate> _delegate;
    BOOL _collapsed;
    BOOL _allowsCollapsing;
    BOOL _allowsTextInputContextCandidates;
    NSAttributedString *(^_attributedStringForCandidate)(id, NSInteger);
    NSArray *_candidates;
    NSString *_customizationLabel;
    NSRange _selectedRange;
    NSString *_originalString;
}

- (instancetype)initWithIdentifier:(NSString *)identifier
{
    self = [super initWithIdentifier:identifier];
    if (self) {
        _allowsCollapsing = YES;                 /* measured */
        _allowsTextInputContextCandidates = YES; /* measured */
        _candidates = @[];
        _customizationLabel = @"";
    }
    return self;
}

- (id)client { return _client; }
- (void)setClient:(id)c { _client = c; }
- (id<NSCandidateListTouchBarItemDelegate>)delegate { return _delegate; }
- (void)setDelegate:(id<NSCandidateListTouchBarItemDelegate>)d { _delegate = d; }

- (BOOL)isCollapsed { return _collapsed; }
- (void)setCollapsed:(BOOL)collapsed
{
    if (_collapsed == collapsed) return;
    _collapsed = collapsed;
    /* visibility is derived from collapsed; notify the delegate of the change. */
    if ([_delegate respondsToSelector:@selector(candidateListTouchBarItem:changedCandidateListVisibility:)]) {
        [_delegate candidateListTouchBarItem:self changedCandidateListVisibility:!_collapsed];
    }
}

- (BOOL)allowsCollapsing { return _allowsCollapsing; }
- (void)setAllowsCollapsing:(BOOL)v { _allowsCollapsing = v; }
- (BOOL)isCandidateListVisible { return !_collapsed; }  /* measured: == !collapsed */
- (BOOL)allowsTextInputContextCandidates { return _allowsTextInputContextCandidates; }
- (void)setAllowsTextInputContextCandidates:(BOOL)v { _allowsTextInputContextCandidates = v; }

- (NSAttributedString *(^)(id, NSInteger))attributedStringForCandidate { return _attributedStringForCandidate; }
- (void)setAttributedStringForCandidate:(NSAttributedString *(^)(id, NSInteger))b { _attributedStringForCandidate = [b copy]; }

- (NSArray *)candidates { return _candidates; }
- (NSString *)customizationLabel { return _customizationLabel; }
- (void)setCustomizationLabel:(NSString *)s { _customizationLabel = [s copy] ?: @""; }

- (void)setCandidates:(NSArray *)candidates forSelectedRange:(NSRange)selectedRange inString:(NSString *)originalString
{
    _candidates = [candidates copy] ?: @[];
    _selectedRange = selectedRange;
    _originalString = [originalString copy];
    /* TODO(stage2): push the candidates into the candidate view controller. */
}

@end
