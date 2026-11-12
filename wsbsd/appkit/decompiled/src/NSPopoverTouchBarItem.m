/*
 * NSPopoverTouchBarItem.m — behavioral-1:1 core. See the header.
 */

#import "NSPopoverTouchBarItem.h"
#import "NSTouchBar.h"

@implementation NSPopoverTouchBarItem {
    NSTouchBar *_popoverTouchBar;
    NSTouchBar *_pressAndHoldTouchBar;
    NSString *_customizationLabel;
    NSView *_collapsedRepresentation;
    NSImage *_collapsedRepresentationImage;
    NSString *_collapsedRepresentationLabel;
    BOOL _collapsedRepresentationShowsChevron;
    BOOL _showsCloseButton;
    BOOL _presented;
}

- (instancetype)initWithIdentifier:(NSString *)identifier
{
    self = [super initWithIdentifier:identifier];
    if (self) {
        _showsCloseButton = YES;      /* measured */
        _customizationLabel = @"";    /* measured */
    }
    return self;
}

- (NSTouchBar *)popoverTouchBar
{
    if (!_popoverTouchBar) _popoverTouchBar = [[NSTouchBar alloc] init]; /* lazy, non-nil (measured) */
    return _popoverTouchBar;
}
- (void)setPopoverTouchBar:(NSTouchBar *)bar { _popoverTouchBar = bar; }  /* null_resettable: nil re-arms the lazy getter */

- (NSTouchBar *)pressAndHoldTouchBar { return _pressAndHoldTouchBar; }
- (void)setPressAndHoldTouchBar:(NSTouchBar *)bar { _pressAndHoldTouchBar = bar; }
- (NSString *)customizationLabel { return _customizationLabel; }
- (void)setCustomizationLabel:(NSString *)s { _customizationLabel = [s copy] ?: @""; }

- (NSView *)collapsedRepresentation { return _collapsedRepresentation; }
- (void)setCollapsedRepresentation:(NSView *)v { _collapsedRepresentation = v; }
- (NSImage *)collapsedRepresentationImage { return _collapsedRepresentationImage; }
- (void)setCollapsedRepresentationImage:(NSImage *)i { _collapsedRepresentationImage = i; }
- (NSString *)collapsedRepresentationLabel { return _collapsedRepresentationLabel; }
- (void)setCollapsedRepresentationLabel:(NSString *)s { _collapsedRepresentationLabel = [s copy]; }
- (BOOL)collapsedRepresentationShowsChevron { return _collapsedRepresentationShowsChevron; }
- (void)setCollapsedRepresentationShowsChevron:(BOOL)v { _collapsedRepresentationShowsChevron = v; }

- (BOOL)showsCloseButton { return _showsCloseButton; }
- (void)setShowsCloseButton:(BOOL)v { _showsCloseButton = v; }
- (BOOL)isPresented { return _presented; }

- (void)showPopover:(id)sender
{
    /* TODO(stage2): slide the popoverTouchBar in over the owning bar. */
    (void)[self popoverTouchBar];   /* ensure the bar exists, as the real item does */
    _presented = YES;
}

- (void)dismissPopover:(id)sender { _presented = NO; }

@end
