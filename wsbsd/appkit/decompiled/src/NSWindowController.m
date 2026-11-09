/*
 * NSWindowController.m — 1:1 (core). See NSWindowController.h for interface evidence.
 *
 * initWithWindow: adopts a window and marks nibIsLoaded. setContentViewController:
 * installs the controller's view as the window's contentView (AppKit also
 * resizes the window to fit — stage2). isWindowLoaded reflects whether a window
 * exists / nib loaded. showWindow: ensures the window is loaded and orders it
 * front (the server ordering is stage2; here it sets the window visible). close
 * orders the window out. Nib loading and document coupling are stage2.
 */
#import "NSWindowController.h"
#import "NSWindow.h"
#import "NSViewController.h"

@implementation NSWindowController {
    NSWindow *_window;
    BOOL _nibLoaded;
    __weak id _document;
    NSViewController *_contentViewController;
    NSString *_frameAutosaveName;
}

- (instancetype)initWithWindow:(NSWindow *)window
{
    self = [super init];
    if (self) {
        _window = window;
        _nibLoaded = (window != nil);
        _frameAutosaveName = @"";
    }
    return self;
}

- (instancetype)init { return [self initWithWindow:nil]; }

- (NSWindow *)window { return _window; }
- (void)setWindow:(NSWindow *)w { _window = w; _nibLoaded = (w != nil); }
- (BOOL)isWindowLoaded { return _nibLoaded; }
- (id)document { return _document; }
- (void)setDocument:(id)d { _document = d; }

- (NSViewController *)contentViewController { return _contentViewController; }
- (void)setContentViewController:(NSViewController *)vc
{
    _contentViewController = vc;
    if (_window) _window.contentView = vc.view;  /* AppKit also sizes to fit: stage2 */
}

- (NSString *)windowFrameAutosaveName { return _frameAutosaveName; }
- (void)setWindowFrameAutosaveName:(NSString *)name { _frameAutosaveName = [name copy] ?: @""; }

- (void)showWindow:(id)sender
{
    /* stage2: window-server ordering. Core makes the window key and visible. */
    [_window makeKeyAndOrderFront:sender];
}

- (void)close
{
    [_window orderOut:nil];
}

@end
