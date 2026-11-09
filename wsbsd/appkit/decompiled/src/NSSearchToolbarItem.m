/*
 * NSSearchToolbarItem.m — 1:1 (core). See NSSearchToolbarItem.h for the evidence.
 *
 * searchField is created lazily the first time it is read (an NSSearchField when
 * that class is linked). resignsFirstResponderWithCancel defaults YES.
 * beginEditing/endEditing toggle the _isEditing flag; in AppKit they also move
 * first responder to the field and expand a collapsed representation, which is
 * stage2.
 */
#import "NSSearchToolbarItem.h"

@implementation NSSearchToolbarItem {
    id _searchField;
    BOOL _resignsFirstResponderWithCancel;
    CGFloat _preferredWidthForSearchField;
    BOOL _isEditing;
}

- (instancetype)initWithItemIdentifier:(NSString *)itemIdentifier
{
    self = [super initWithItemIdentifier:itemIdentifier];
    if (self) {
        _resignsFirstResponderWithCancel = YES;
        _preferredWidthForSearchField = 0.0;
    }
    return self;
}

- (id)searchField
{
    if (!_searchField) {
        Class cls = NSClassFromString(@"NSSearchField");
        if (cls) _searchField = [[cls alloc] init];
    }
    return _searchField;
}
- (void)setSearchField:(id)v { _searchField = v; }

- (BOOL)resignsFirstResponderWithCancel { return _resignsFirstResponderWithCancel; }
- (void)setResignsFirstResponderWithCancel:(BOOL)v { _resignsFirstResponderWithCancel = v; }
- (CGFloat)preferredWidthForSearchField { return _preferredWidthForSearchField; }
- (void)setPreferredWidthForSearchField:(CGFloat)v { _preferredWidthForSearchField = v; }

- (BOOL)isEditing { return _isEditing; }
- (void)beginEditing { _isEditing = YES; }   /* stage2: also make the field first responder */
- (void)endEditing { _isEditing = NO; }

@end
