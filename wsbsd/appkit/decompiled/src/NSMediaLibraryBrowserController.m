/*
 * NSMediaLibraryBrowserController.m — behavioral-1:1 core. See the header.
 */

#import "NSMediaLibraryBrowserController.h"

@implementation NSMediaLibraryBrowserController {
    BOOL _visible;
    CGRect _frame;
    NSMediaLibrary _mediaLibraries;
}

+ (NSMediaLibraryBrowserController *)sharedMediaLibraryBrowserController
{
    static NSMediaLibraryBrowserController *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[self alloc] init]; });
    return shared;
}

- (BOOL)isVisible { return _visible; }
- (void)setVisible:(BOOL)v { _visible = v; /* TODO(stage2): order the panel in/out */ }
- (CGRect)frame { return _frame; }
- (void)setFrame:(CGRect)f { _frame = f; }
- (NSMediaLibrary)mediaLibraries { return _mediaLibraries; }
- (void)setMediaLibraries:(NSMediaLibrary)m { _mediaLibraries = m; }

- (void)togglePanel:(id)sender
{
    self.visible = !_visible;   /* show/hide the floating media browser */
}

@end
