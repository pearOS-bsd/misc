/*
 * NSCustomTouchBarItem.m — 1:1 (core). See the header for the interface evidence.
 *
 * Overrides the base's read-only view/viewController/customizationLabel to be
 * settable. Setting a view controller adopts its view as the item's view (and a
 * directly-set view clears any view controller), matching AppKit. The
 * customization palette preview view is stage2.
 */
#import "NSCustomTouchBarItem.h"
#import "NSViewController.h"
#import "NSView.h"

@implementation NSCustomTouchBarItem {
    NSView *_view;
    NSViewController *_viewController;
    NSString *_customizationLabel;
}

- (NSView *)view
{
    if (_view) return _view;
    return _viewController.view;   /* view controller provides the view */
}
- (void)setView:(NSView *)view { _view = view; _viewController = nil; }

- (NSViewController *)viewController { return _viewController; }
- (void)setViewController:(NSViewController *)vc
{
    _viewController = vc;
    _view = nil;                   /* the controller's view is used via -view */
}

- (NSString *)customizationLabel { return _customizationLabel; }
- (void)setCustomizationLabel:(NSString *)label { _customizationLabel = [label copy]; }

@end
