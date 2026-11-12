/*
 * NSSharingServicePickerToolbarItem.m — behavioral-1:1 core. See the header.
 */

#import "NSSharingServicePickerToolbarItem.h"

@implementation NSSharingServicePickerToolbarItem {
    __weak id<NSSharingServicePickerToolbarItemDelegate> _delegate;
    BOOL _isShowing;
    NSArray *_lastSharedItems;   /* items pulled from the delegate on -share: */
}

- (instancetype)initWithItemIdentifier:(NSString *)itemIdentifier
{
    self = [super initWithItemIdentifier:itemIdentifier];
    /* delegate nil, not showing by default (measured). */
    return self;
}

- (id<NSSharingServicePickerToolbarItemDelegate>)delegate { return _delegate; }
- (void)setDelegate:(id<NSSharingServicePickerToolbarItemDelegate>)d { _delegate = d; }
- (BOOL)isShowing { return _isShowing; }

- (void)share:(id)sender
{
    /* The real item opens an NSSharingServicePicker over the toolbar button;
       its first act is to ask the delegate for the items to share. We reproduce
       that pull + the showing-state toggle; the popover itself is stage2. */
    if (_isShowing) return;
    NSArray *items = nil;
    if ([_delegate respondsToSelector:@selector(itemsForSharingServicePickerToolbarItem:)]) {
        items = [_delegate itemsForSharingServicePickerToolbarItem:self];
    }
    _lastSharedItems = [items copy];
    /* No items => nothing to present, matching the real no-op. */
    if (items.count == 0) return;
    _isShowing = YES;   /* TODO(stage2): present NSSharingServicePicker, clear on dismiss */
}

/* internal, exposed for the test to model the picker dismissing. */
- (void)_pickerDidClose { _isShowing = NO; }

@end
