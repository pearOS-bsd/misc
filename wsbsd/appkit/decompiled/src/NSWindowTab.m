/*
 * NSWindowTab.m — 1:1 (core). See NSWindowTab.h for the interface evidence.
 *
 * A value object: title (null_resettable — a nil title falls back to an empty
 * string here; AppKit falls back to the window's own title, which is stage2),
 * attributedTitle, toolTip, icon image + showIcon flag, accessory view and the
 * weak owning window. The NSTabBarItem and its drawing are stage2.
 */
#import "NSWindowTab.h"

@implementation NSWindowTab {
    NSString *_title;
    NSAttributedString *_attributedTitle;
    NSString *_toolTip;
    id _image;
    id _accessoryView;
    BOOL _showIcon;
    __weak id _window;
}

- (NSString *)title { return _title ?: @""; }
- (void)setTitle:(NSString *)v { _title = [v copy]; }
- (NSAttributedString *)attributedTitle { return _attributedTitle; }
- (void)setAttributedTitle:(NSAttributedString *)v { _attributedTitle = [v copy]; }
- (NSString *)toolTip { return _toolTip; }
- (void)setToolTip:(NSString *)v { _toolTip = [v copy]; }
- (id)image { return _image; }
- (void)setImage:(id)v { _image = v; }
- (id)accessoryView { return _accessoryView; }
- (void)setAccessoryView:(id)v { _accessoryView = v; }
- (BOOL)showIcon { return _showIcon; }
- (void)setShowIcon:(BOOL)v { _showIcon = v; }
- (id)window { return _window; }
- (void)setWindow:(id)v { _window = v; }

@end
