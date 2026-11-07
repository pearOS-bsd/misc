/*
 * NSView.m — 1:1 reimplementation of AppKit's NSView (structural core).
 * Addresses cite the macOS 27 arm64e disassembly under ../evidence.
 *
 * Measured ivar offsets (from _OBJC_IVAR_$_NSView.*, macOS 27 arm64e):
 *   _vFlags    (w, @0xac0)   bit 0x800000 set by initWithFrame:; isFlipped = bit 11
 *   _subviews  (@0xacc)      NSMutableArray *, nil until first child
 *   _frame     (@0xad0)      CGRect
 *   _bounds    (@0xad4)      CGRect
 *   _superview (@0xad8)      NSView *, not owning (NSViewSuperviewIsWeak default NO)
 *   _window    (@0xae8)      NSWindow *, not owning
 */
#import "NSView.h"
#import <objc/runtime.h>

extern void _NSAddKeyValueDependency(id object, NSString *key);
/* _NSViewValidateRect normalises a CGRect (NaN/inf guard, negative size).
 * Provided by AppKit; the test harness supplies a plain pass-through. */
extern CGRect _NSViewValidateRect(CGRect r);

/* NSView._vFlags bit for isFlipped (byte[1] bit 3 == word bit 11). */
enum { NSViewVFlagInitialised = 0x00800000u };

@interface NSView ()
- (void)_setSuperview:(nullable NSView *)sv;
- (void)_setWindow:(nullable NSWindow *)window;
- (CGPoint)_convertPointFromSuperview:(CGPoint)p;
@end

@implementation NSView {
    uint32_t _vFlags;                       /* 0xac0 */
    NSMutableArray<NSView *> *_subviews;     /* 0xacc */
    CGRect _frame;                           /* 0xad0 */
    CGRect _bounds;                          /* 0xad4 */
    __unsafe_unretained NSView *_superview;  /* 0xad8 */
    __unsafe_unretained NSWindow *_window;   /* 0xae8 */
}

/* -[NSView initWithFrame:]  — evidence: 0x184f0eec8 */
- (instancetype)initWithFrame:(CGRect)frameRect
{
    frameRect = _NSViewValidateRect(frameRect);
    /* _NSViewCommonPreInitialization(self) @0x184f0ef00 — layer/geometry prep (stage2) */
    self = [super init];
    if (self) {
        _frame = frameRect;
        /* bounds starts with frame's size, origin zero (str q0=[_frame.size] -> [_bounds.size]) */
        _bounds = CGRectMake(0, 0, frameRect.size.width, frameRect.size.height);
        /* helpers @0x18803dfe0 / @0x188041940 / @0x1880a76f0 — layer host wiring (stage2) */
        _vFlags |= NSViewVFlagInitialised;   /* orr w9,#0x800000 */
    }
    return self;
}

#pragma mark - Geometry

/* -[NSView frame]  — evidence: 0x184f2992c  (KVO deps frameOrigin, frameSize) */
- (CGRect)frame
{
    _NSAddKeyValueDependency(self, @"frameOrigin");
    _NSAddKeyValueDependency(self, @"frameSize");
    return _frame;
}

/* -[NSView bounds]  — evidence: 0x184f125c4  (KVO deps boundsOrigin, boundsSize) */
- (CGRect)bounds
{
    _NSAddKeyValueDependency(self, @"boundsOrigin");
    _NSAddKeyValueDependency(self, @"boundsSize");
    return _bounds;
}

/* -[NSView setFrame:]  — evidence: 0x184f33d9c
 * Observable core: validate, early-out when unchanged, store into _frame.
 * TODO(stage2): _NSViewLayoutFeedbackLoopDebugger (@0x184f33e0c), layer origin/
 * size push (@0x1880a5560/@0x1880a55a0), os_unfair_lock _vFlags toggles,
 * NSViewFrameDidChangeNotification. */
- (void)setFrame:(CGRect)frameRect
{
    frameRect = _NSViewValidateRect(frameRect);
    if (CGRectEqualToRect(frameRect, _frame))
        return;
    _frame = frameRect;
}

- (void)setBounds:(CGRect)boundsRect   /* evidence: 0x184f1... setBounds: (stage2 internals) */
{
    _bounds = _NSViewValidateRect(boundsRect);
}

/* -[NSView isFlipped]  — evidence: 0x184f14290  (return (_vFlags >> 11) & 1) */
- (BOOL)isFlipped
{
    return (_vFlags >> 11) & 1u;
}

#pragma mark - Hierarchy

/* -[NSView superview]  — evidence: 0x184f0fd44  (KVO dep, return _superview) */
- (NSView *)superview
{
    _NSAddKeyValueDependency(self, @"superview");
    return _superview;
}

/* -[NSView subviews]  — evidence: 0x184f17b18
 * KVO dep "subviews"; nil storage -> empty array; else a copy
 * (NSViewSubviewsReturnsInternalMutableStorage default NO). */
- (NSArray<NSView *> *)subviews
{
    _NSAddKeyValueDependency(self, @"subviews");
    if (!_subviews)
        return @[];
    return [_subviews copy];
}

/* -[NSView window]  — evidence: 0x184f12a90  (KVO dep, return _window) */
- (NSWindow *)window
{
    _NSAddKeyValueDependency(self, @"window");
    return _window;
}

/* -[NSView addSubview:]  — evidence: 0x184f0f... -> addSubview:positioned:relativeTo:
 * (NSWindowAbove, nil). Observable core below; TODO(stage2): cursor rects,
 * constraint engine, layer attach, geometry notifications. */
- (void)addSubview:(NSView *)view
{
    if (!view || view == self)
        return;
    [view removeFromSuperview];
    if (!_subviews)
        _subviews = [NSMutableArray array];
    [_subviews addObject:view];
    [view _setSuperview:self];
    [view _setWindow:_window];
}

/* -[NSView removeFromSuperview]  — evidence: 0x184f364d8
 * Observable core: drop from superview's _subviews, clear _superview and the
 * window chain. TODO(stage2): window unregister (@0x188051890), cursor-rect
 * invalidation, _layoutAux flag clear, constraint teardown. */
- (void)removeFromSuperview
{
    NSView *sv = _superview;
    if (!sv)
        return;
    [sv->_subviews removeObjectIdenticalTo:self];
    _superview = nil;
    [self _setWindow:nil];
}

/* -[NSView isDescendantOf:]  — evidence: 0x184f1d238
 * self == view ? YES : [_superview isDescendantOf:view]  (nil chain -> NO). */
- (BOOL)isDescendantOf:(NSView *)view
{
    if (view == self)
        return YES;
    if (!_superview)
        return NO;
    return [_superview isDescendantOf:view];
}

#pragma mark - Hit testing

/* -[NSView hitTest:]  — evidence: 0x18504cfd4
 *   tail: [self _hitTestForContext:nil point:point preferPointOverContext:YES]
 * The _hitTestForContext: body is not decoded yet; this is the documented
 * geometric algorithm it reduces to for an ordinary view. TODO(stage2): decode
 * _hitTestForContext:point:preferPointOverContext: and match exactly. */
- (NSView *)hitTest:(CGPoint)point
{
    /* point arrives in the superview's coordinate space */
    if (_superview && !CGRectContainsPoint(_frame, point))
        return nil;

    CGPoint local = [self _convertPointFromSuperview:point];

    for (NSView *sub in [_subviews reverseObjectEnumerator]) {
        NSView *hit = [sub hitTest:local];
        if (hit)
            return hit;
    }
    if (CGRectContainsPoint(_bounds, local))
        return self;
    return nil;
}

#pragma mark - Window move hooks (evidence: viewDidMoveToWindow 0x184f117d4 empty)

- (void)viewWillMoveToWindow:(NSWindow *)newWindow { }
- (void)viewDidMoveToWindow { }

#pragma mark - Internal helpers

- (void)_setSuperview:(NSView *)sv { _superview = sv; }

/* Propagate a window change down the subtree, bracketing with the public hooks.
 * Mirrors AppKit's _setWindow: recursion (exact private body is stage2). */
- (void)_setWindow:(NSWindow *)window
{
    if (_window == window)
        return;
    [self viewWillMoveToWindow:window];
    _window = window;
    for (NSView *sub in _subviews)
        [sub _setWindow:window];
    [self viewDidMoveToWindow];
}

/* bounds<->frame mapping for hitTest. Full affine (bounds origin/scale/flip) is
 * stage2; this handles translation plus the flip the algorithm needs. */
- (CGPoint)_convertPointFromSuperview:(CGPoint)p
{
    CGPoint q = CGPointMake(p.x - _frame.origin.x, p.y - _frame.origin.y);
    q.x += _bounds.origin.x;
    q.y += _bounds.origin.y;
    return q;
}

@end
