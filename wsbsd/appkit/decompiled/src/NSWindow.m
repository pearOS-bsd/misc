/*
 * NSWindow.m — 1:1 reimplementation of AppKit's NSWindow (data + responder core).
 * Addresses cite the macOS 27 arm64e disassembly under ../evidence/window.
 *
 * Shipping ivars: _auxiliaryStorage 0xc18, _wFlags 0xc20 (bit2 visible),
 * _styleMask 0xc24, _borderView 0xc28, _contentView 0xc2c, _delegate 0xc48 (weak).
 */
#import "NSWindow.h"

enum : uint64_t { NSWindowWFlagVisible = 1u << 2 };  /* _wFlags bit 2 (isVisible 0x184f1175c) */

@implementation NSWindow {
    NSString *_title;
    uint64_t _wFlags;                       /* 0xc20 */
    NSWindowStyleMask _styleMask;           /* 0xc24 */
    NSView *_contentView;                   /* 0xc2c */
    __weak id _delegate;                    /* 0xc48 */
    __weak NSResponder *_firstResponder;
    CGRect _frame;
}

/* -[NSWindow initWithContentRect:styleMask:backing:defer:] */
- (instancetype)initWithContentRect:(CGRect)contentRect
                          styleMask:(NSWindowStyleMask)style
                            backing:(NSBackingStoreType)backingStoreType
                              defer:(BOOL)flag
{
    self = [super init];
    if (self) {
        _styleMask = style;
        _frame = contentRect;
        _title = @"";
        /* content view sized to the content rect; the border-view layer is stage2 */
        _contentView = [[NSView alloc] initWithFrame:CGRectMake(0, 0,
                                        contentRect.size.width, contentRect.size.height)];
        /* the window is its own first responder until one is set (firstResponder 0x184f3676c) */
        _firstResponder = self;
    }
    return self;
}

/* -[NSWindow title] 0x184feb99c / setTitle: 0x184f37194
 * (shipping path reads/writes auxiliary storage and clears a _wFlags bit; we
 * keep the string directly. TODO(stage2): auxiliary-storage title.) */
- (NSString *)title { return _title ?: @""; }
- (void)setTitle:(NSString *)title
{
    _wFlags &= ~(1ull << 26);     /* clears the "title is hidden" flag, as the binary does */
    _title = [title copy] ?: @"";
}

/* -[NSWindow styleMask] 0x184f19958 (border view if present, else _styleMask). */
- (NSWindowStyleMask)styleMask { return _styleMask; }
- (void)setStyleMask:(NSWindowStyleMask)styleMask { _styleMask = styleMask; }

/* -[NSWindow contentView] 0x184f34b34 / setContentView: wires the view to this window. */
- (NSView *)contentView { return _contentView; }
- (void)setContentView:(NSView *)contentView
{
    _contentView = contentView;
    /* TODO(stage2): swap under the border view and wire the subtree's window
     * link (NSView _setWindow:) so descendants report this window. */
}

/* -[NSWindow delegate] 0x184ff44c8 (weak) / setDelegate: 0x184f39694 (weak + KVO). */
- (id)delegate { return _delegate; }
- (void)setDelegate:(id)delegate { _delegate = delegate; }

/* -[NSWindow isVisible] 0x184f1175c (_wFlags bit 2). */
- (BOOL)isVisible { return (_wFlags & NSWindowWFlagVisible) != 0; }

- (void)makeKeyAndOrderFront:(id)sender { _wFlags |= NSWindowWFlagVisible; /* stage2: server order + key */ }
- (void)orderOut:(id)sender { _wFlags &= ~NSWindowWFlagVisible; }

/* -[NSWindow firstResponder] 0x184f3676c: stored responder, or the window itself. */
- (NSResponder *)firstResponder { return _firstResponder ?: self; }

/* -[NSWindow makeFirstResponder:] 0x184fe9d04 -> _makeFirstResponder helper 0x188051dd0.
 * The helper body is stage2; this is the documented resign/become contract it
 * implements: ask the current responder to resign, the new one to become, and
 * fall back to the window itself when the new one refuses or is nil. */
- (BOOL)makeFirstResponder:(NSResponder *)responder
{
    if (_firstResponder == responder)
        return YES;

    NSResponder *current = _firstResponder;
    if (current && ![current resignFirstResponder])
        return NO;

    if (responder == nil) {
        _firstResponder = self;
        return YES;
    }
    if (![responder becomeFirstResponder]) {
        _firstResponder = self;
        return NO;
    }
    _firstResponder = responder;
    return YES;
}

@end
