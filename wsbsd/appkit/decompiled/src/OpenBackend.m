/* OpenBackend.m: ordering, drawing and the loop of an NSWindow through wsd. */
#import "OpenBackend.h"
#import "NSWindow.h"
#import "NSView.h"
#import "NSApplication.h"
#import "NSColor.h"
#import "NSGraphicsContext.h"
#import "NSEvent.h"
#import "NSFont.h"
#import <objc/runtime.h>
#include "ws_client.h"
#include <poll.h>

@interface NSWindow (OpenPrivate) - (CGRect)_openFrame; @end

static ws_conn *sConn;
static NSMapTable *sWindows;			/* wsd window id -> NSWindow (weak) */
static int sScreenW = 1280, sScreenH = 800;

static ws_conn *OpenConn(void)
{
    if (!sConn) {
        sConn = ws_connect(NULL);
        if (sConn) ws_conn_screen(sConn, &sScreenW, &sScreenH);
        else NSLog(@"open: cannot connect to wsd");
    }
    return sConn;
}

/* the wsd window of an NSWindow: kept with the object */
#define OPEN_TITLEBAR 32		/* measured on macOS (docs/UI-MAC.md) */
@interface OpenWin : NSObject { @public ws_win win; CGContextRef cg; BOOL shown; int tb; } @end
@implementation OpenWin @end
static const void *kOpenWinKey = &kOpenWinKey;
static OpenWin *OpenWinOf(NSWindow *w, BOOL create)
{
    OpenWin *o = objc_getAssociatedObject(w, kOpenWinKey);
    if (o || !create) return o;
    ws_conn *c = OpenConn();
    if (!c) return nil;
    CGRect f = [w _openFrame];
    int tb = (([w styleMask] & 1) ? OPEN_TITLEBAR : 0);
    int top = sScreenH - (int)(f.origin.y + f.size.height) - tb;
    o = [OpenWin new];
    o->tb = tb;
    if (ws_win_create(c, (ws_rect){ (int)f.origin.x, top, (int)f.size.width, (int)f.size.height + tb }, 0, &o->win)) { NSLog(@"open: cannot create the window"); return nil; }
    CGColorSpaceRef cs = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    o->cg = CGBitmapContextCreate(o->win.px->px, o->win.px->w, o->win.px->h, 8, o->win.px->stride, cs, (CGBitmapInfo)kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
    CGColorSpaceRelease(cs);
    objc_setAssociatedObject(w, kOpenWinKey, o, OBJC_ASSOCIATION_RETAIN);
    if (!sWindows) sWindows = [NSMapTable strongToWeakObjectsMapTable];
    [sWindows setObject:w forKey:@(o->win.id)];
    ws_win_set_event_mask(c, &o->win, -1);
    return o;
}

/* a view and its subviews into the current CGContext: the origin of the view, flipped views get a y axis that goes down */
static void OpenDrawView(NSView *v, CGContextRef cg)
{
    CGRect fr = [v frame], b = [v bounds];
    CGContextSaveGState(cg);
    CGContextTranslateCTM(cg, fr.origin.x, fr.origin.y);
    CGContextClipToRect(cg, CGRectMake(0, 0, fr.size.width, fr.size.height));
    if ([v isFlipped]) { CGContextTranslateCTM(cg, 0, fr.size.height); CGContextScaleCTM(cg, 1, -1); }
    NSGraphicsContext *gc = [NSGraphicsContext graphicsContextWithCGContext:cg flipped:[v isFlipped]];
    NSGraphicsContext *old = [NSGraphicsContext currentContext];
    [NSGraphicsContext setCurrentContext:gc];
    [v drawRect:b];
    [NSGraphicsContext setCurrentContext:old];
    CGContextRestoreGState(cg);
    CGContextSaveGState(cg);
    CGContextTranslateCTM(cg, fr.origin.x, fr.origin.y);
    if ([v isFlipped]) { CGContextTranslateCTM(cg, 0, fr.size.height); CGContextScaleCTM(cg, 1, -1); }
    for (NSView *s in [v subviews]) OpenDrawView(s, cg);
    CGContextRestoreGState(cg);
}

void OpenWindowDisplay(NSWindow *w)
{
    OpenWin *o = OpenWinOf(w, NO);
    if (!o) return;
    CGContextSaveGState(o->cg);
    CGContextClearRect(o->cg, CGRectMake(0, 0, o->win.px->w, o->win.px->h));
    CGContextSetRGBFillColor(o->cg, 30 / 255.0, 30 / 255.0, 30 / 255.0, 1); CGContextFillRect(o->cg, CGRectMake(0, 0, o->win.px->w, o->win.px->h - o->tb));		/* window background (dark) */
    NSView *cv = [w contentView];
    if (cv) { @try { OpenDrawView(cv, o->cg); } @catch (NSException *ex) { fprintf(stderr, "open: exception while drawing: %s: %s\n", [[ex name] UTF8String], [[ex reason] UTF8String]); } }
    if (o->tb) {
        CGFloat W = o->win.px->w, H = o->win.px->h, tb = o->tb;
        CGContextSetRGBFillColor(o->cg, 35 / 255.0, 35 / 255.0, 36 / 255.0, 1); CGContextFillRect(o->cg, CGRectMake(0, H - tb, W, tb));
        /* traffic lights 14x14 at x = 9, 32, 55: gradient top / middle / bottom (docs/UI-MAC.md) */
        static const int gr[3][3][3] = { { {247,94,85}, {244,83,70}, {239,104,97} }, { {251,180,1}, {253,193,1}, {254,207,48} }, { {51,194,1}, {0,188,0}, {78,194,58} } };
        CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
        for (int i = 0; i < 3; i++) {
            CGFloat c[12], loc[3] = { 0, 0.5, 1 };
            for (int k = 0; k < 3; k++) { c[k * 4] = gr[i][2 - k][0] / 255.0; c[k * 4 + 1] = gr[i][2 - k][1] / 255.0; c[k * 4 + 2] = gr[i][2 - k][2] / 255.0; c[k * 4 + 3] = 1; }
            CGGradientRef g = CGGradientCreateWithColorComponents(rgb, c, loc, 3);
            CGRect r = CGRectMake(9 + i * 23, H - tb + 9, 14, 14);
            CGContextSaveGState(o->cg); CGContextAddEllipseInRect(o->cg, r); CGContextClip(o->cg);
            CGContextDrawLinearGradient(o->cg, g, CGPointMake(0, r.origin.y + 14), CGPointMake(0, r.origin.y), 0);
            CGContextRestoreGState(o->cg); CGGradientRelease(g);
        }
        CGColorSpaceRelease(rgb);
        NSGraphicsContext *gc = [NSGraphicsContext graphicsContextWithCGContext:o->cg flipped:NO];
        NSGraphicsContext *old = [NSGraphicsContext currentContext]; [NSGraphicsContext setCurrentContext:gc];
        NSString *t = [w title]; NSDictionary *at = @{ NSFontAttributeName: [NSFont boldSystemFontOfSize:13], NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:1 alpha:0.85] };
        CGSize ts = [t sizeWithAttributes:at];
        [t drawAtPoint:CGPointMake(82, H - tb / 2 - ts.height / 2) withAttributes:at];
        [NSGraphicsContext setCurrentContext:old];
    }
    CGContextRestoreGState(o->cg);
    int fr_ = ws_win_flush(sConn, &o->win); if (getenv("OPEN_DEBUG")) fprintf(stderr, "open: display flush rc %d\n", fr_);
}

void OpenWindowOrderFront(NSWindow *w)
{
    OpenWin *o = OpenWinOf(w, YES);
    if (!o) return;
    OpenWindowDisplay(w);
    ws_win_order(sConn, &o->win, WS_ABOVE, 0);
    o->shown = YES;
    ws_win_set_key(sConn, &o->win);
}

void OpenWindowOrderOut(NSWindow *w)
{
    OpenWin *o = OpenWinOf(w, NO);
    if (o && o->shown) { ws_win_order(sConn, &o->win, WS_OUT, 0); o->shown = NO; }
}

static NSView *sMouseView;				/* the view that took the mouse down: it gets the drag and the up */
static int sDragWid, sDragX, sDragY;
/* US layout: macOS virtual key code -> characters (plain, shifted) */
static NSString *OpenKeyChars(unsigned short kc, BOOL shift)
{
    static const char *pl = "asdfhgzxcv\0bqweryt123465=97-80]ou[ip\0lj'k;\\,/nm.\0\0`";
    static const char *sh = "ASDFHGZXCV\0BQWERYT!@#$^%+(&_*)}OU{IP\0LJ\"K:|<?NM>\0\0~";
    if (kc == 36) return @"\r"; if (kc == 48) return @"\t"; if (kc == 49) return @" "; if (kc == 51) return @"\x7f"; if (kc == 53) return @"\x1b";
    if (kc < 51) { char ch = (shift ? sh : pl)[kc]; if (ch) return [NSString stringWithFormat:@"%c", ch]; }
    return @"";
}

static void OpenDispatch(const ws_event *e)
{
    NSWindow *w = [sWindows objectForKey:@(e->wid)];
    if (!w) return;
    OpenWin *o = OpenWinOf(w, NO);
    CGFloat h = o ? o->win.px->h : 0;
    if (o && o->tb && e->y < o->tb && (e->type == WS_EV_MOUSE_DOWN || e->type == WS_EV_MOUSE_MOVE || e->type == WS_EV_MOUSE_UP || sDragWid)) {	/* the title bar */
        if (e->type == WS_EV_MOUSE_DOWN) {
            int i = (e->x - 9) / 23;
            if (e->x >= 9 && i < 3 && ((e->x - 9) % 23) < 14) { if (i == 0) { OpenWindowOrderOut(w); BOOL any = NO; for (NSNumber *k in [sWindows keyEnumerator]) { OpenWin *q = OpenWinOf([sWindows objectForKey:k], NO); if (q && q->shown) any = YES; } if (!any) exit(0); } return; }
            sDragWid = e->wid; sDragX = e->x; sDragY = e->y;
        }
        return;
    }
    if (sDragWid && e->wid == sDragWid) {
        if (e->type == WS_EV_MOUSE_MOVE && e->buttons) { const ws_win *wl[1] = { &o->win }; ws_win_move_list(OpenConn(), wl, 1, e->x - sDragX, e->y - sDragY); return; }
        if (e->type == WS_EV_MOUSE_UP) { sDragWid = 0; return; }
    }
    CGPoint p = CGPointMake(e->x, h - e->y);			/* wsd: origin top left; AppKit: lower left */
    NSEventModifierFlags fl = e->flags;
    NSTimeInterval t = CFAbsoluteTimeGetCurrent();
    NSView *cv = [w contentView];
    switch (e->type) {
    case WS_EV_MOUSE_DOWN: case WS_EV_MOUSE_UP: case WS_EV_MOUSE_MOVE: {
        NSEventType ty = e->type == WS_EV_MOUSE_DOWN ? NSEventTypeLeftMouseDown : e->type == WS_EV_MOUSE_UP ? NSEventTypeLeftMouseUp : (e->buttons ? NSEventTypeLeftMouseDragged : NSEventTypeMouseMoved);
        NSEvent *ev = [NSEvent mouseEventWithType:ty location:p modifierFlags:fl timestamp:t windowNumber:e->wid context:nil eventNumber:0 clickCount:1 pressure:1];
        NSView *v = (ty == NSEventTypeLeftMouseDragged || ty == NSEventTypeLeftMouseUp) && sMouseView ? sMouseView : [cv hitTest:p];
        if (getenv("OPEN_DEBUG")) fprintf(stderr, "open: hit %s at %g,%g\n", v ? class_getName([v class]) : "nil", p.x, p.y);
        if (ty == NSEventTypeLeftMouseDown) sMouseView = v;
        if (ty == NSEventTypeLeftMouseUp) sMouseView = nil;
        if (ty == NSEventTypeLeftMouseDown) [v mouseDown:ev];
        else if (ty == NSEventTypeLeftMouseUp) [v mouseUp:ev];
        else if (ty == NSEventTypeLeftMouseDragged) [v mouseDragged:ev];
        else [v mouseMoved:ev];
        break; }
    case WS_EV_FOCUS_OUT: { if ([cv respondsToSelector:@selector(_openFocusOut)]) [cv performSelector:@selector(_openFocusOut)]; break; }
    case WS_EV_SCROLL: {
        NSView *v = [cv hitTest:p];
        while (v && ![v respondsToSelector:@selector(_openScrollBy:)]) v = [v superview];
        if (v) [v performSelector:@selector(_openScrollBy:) withObject:@((double)e->dy)];
        break; }
    case WS_EV_KEY_DOWN: case WS_EV_KEY_UP: {
        NSEvent *ev = [NSEvent keyEventWithType:e->type == WS_EV_KEY_DOWN ? NSEventTypeKeyDown : NSEventTypeKeyUp location:CGPointZero modifierFlags:fl timestamp:t windowNumber:e->wid context:nil characters:OpenKeyChars((unsigned short)e->key, (fl & NSEventModifierFlagShift) != 0) charactersIgnoringModifiers:OpenKeyChars((unsigned short)e->key, NO) isARepeat:NO keyCode:(unsigned short)e->key];
        NSResponder *r = [w firstResponder];
        if (!r || r == (NSResponder *)w) r = cv;			/* no first responder set: the content view takes the keys */
        if (e->type == WS_EV_KEY_DOWN) [r keyDown:ev]; else [r keyUp:ev];
        break; }
    default: break;
    }
}

void OpenRunLoop(void)
{
    /* the events of wsd are read by a thread and handed to the main queue; the main thread sits in the run loop (which then also serves timers, dispatch and sources of the application) */
    ws_conn *c = OpenConn();
    if (c) {
        dispatch_queue_t q = dispatch_queue_create("open.events", DISPATCH_QUEUE_SERIAL);
        dispatch_async(q, ^{
            for (;;) {
                ws_event e;
                if (ws_conn_next_pushed_event(c, 20, &e)) {
                    ws_event ev = e;
                    if (getenv("OPEN_DEBUG")) fprintf(stderr, "open: event type %d wid %d at %d,%d buttons %d\n", ev.type, (int)ev.wid, ev.x, ev.y, ev.buttons);
                    CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^{ OpenDispatch(&ev); }); CFRunLoopWakeUp(CFRunLoopGetMain());		/* not the main queue: a nested (modal) run loop serves run loop blocks, not the busy main queue */
                }
            }
        });
    }
    CFRunLoopRun();
}

/* ---- what the views and colours need to draw ---- */
@implementation NSView (OpenDrawing)
- (void)drawRect:(CGRect)dirtyRect { }
- (NSWindow *)_openWindow
{
    NSWindow *w = [self window];
    if (w) return w;
    NSView *root = self; while ([root superview]) root = [root superview];			/* the window link of nested views is not kept by addSubview: yet: the root is the content view of a window */
    for (NSNumber *k in [sWindows keyEnumerator]) { NSWindow *c = [sWindows objectForKey:k]; if ([c contentView] == root) return c; }
    return nil;
}
- (void)setNeedsDisplay:(BOOL)flag { NSWindow *w = flag ? [self _openWindow] : nil; if (w) OpenWindowDisplay(w); }
- (void)display { NSWindow *w = [self _openWindow]; if (w) OpenWindowDisplay(w); }
@end

@implementation NSColor (OpenDrawing)
/* the components as RGBA whatever the colour is made of (gray, RGB; anything else: light text colour) */
- (void)_openRGBA:(CGFloat *)c
{
    @try {
        CGFloat a = [self alphaComponent];
        if ([self numberOfComponents] == 2) { CGFloat w = [self whiteComponent]; c[0] = c[1] = c[2] = w; c[3] = a; }
        else { c[0] = [self redComponent]; c[1] = [self greenComponent]; c[2] = [self blueComponent]; c[3] = a; }
    } @catch (NSException *e) { c[0] = c[1] = c[2] = 0.85; c[3] = 1; }
}
- (void)setFill { CGContextRef cg = [[NSGraphicsContext currentContext] CGContext]; if (!cg) return; CGFloat c[4]; [self _openRGBA:c]; CGContextSetRGBFillColor(cg, c[0], c[1], c[2], c[3]); }
- (void)setStroke { CGContextRef cg = [[NSGraphicsContext currentContext] CGContext]; if (!cg) return; CGFloat c[4]; [self _openRGBA:c]; CGContextSetRGBStrokeColor(cg, c[0], c[1], c[2], c[3]); }
- (void)set { [self setFill]; [self setStroke]; }
- (NSColor *)colorUsingColorSpace:(id)cs { return self; }
- (NSColor *)colorUsingType:(NSInteger)t { return self; }
- (CGColorRef)CGColor { CGFloat c[4]; [self _openRGBA:c]; CGColorSpaceRef sp = CGColorSpaceCreateDeviceRGB(); CGColorRef r = CGColorCreate(sp, c); CGColorSpaceRelease(sp); return (CGColorRef)CFAutorelease(r); }
- (NSString *)_copyFormattingDescription:(id)x { return [self description]; }
@end

@protocol OpenAppDelegate <NSObject>
@optional
- (void)applicationWillFinishLaunching:(NSNotification *)n;
- (void)applicationDidFinishLaunching:(NSNotification *)n;
@end
@implementation NSApplication (OpenRun)
- (void)run
{
    id<OpenAppDelegate> d = [self delegate];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    NSNotification *n = [NSNotification notificationWithName:@"NSApplicationWillFinishLaunchingNotification" object:self];
    [nc postNotification:n];
    if ([d respondsToSelector:@selector(applicationWillFinishLaunching:)]) [d applicationWillFinishLaunching:n];
    n = [NSNotification notificationWithName:@"NSApplicationDidFinishLaunchingNotification" object:self];
    if ([d respondsToSelector:@selector(applicationDidFinishLaunching:)]) [d applicationDidFinishLaunching:n];
    [nc postNotification:n];
    OpenRunLoop();
}
@end

void NSRectFill(CGRect r)
{
    CGContextRef cg = [[NSGraphicsContext currentContext] CGContext];
    if (cg) CGContextFillRect(cg, r);
}

/* ---- text: attribute names and string drawing through CoreText ---- */
#import "NSFont.h"
#import <CoreText/CoreText.h>
NSString *const NSFontAttributeName = @"NSFont";
NSString *const NSForegroundColorAttributeName = @"NSColor";
NSString *const NSParagraphStyleAttributeName = @"NSParagraphStyle";
NSString *const NSBackgroundColorAttributeName = @"NSBackgroundColor";
NSString *const NSUnderlineStyleAttributeName = @"NSUnderline";
NSString *const NSKernAttributeName = @"NSKern";
NSString *const NSShadowAttributeName = @"NSShadow";

static CTLineRef OpenLine(NSString *s, NSDictionary *attrs, CGFloat *ascent, CGFloat *descent, CGFloat *width)
{
    NSFont *f = attrs[NSFontAttributeName] ?: [NSFont systemFontOfSize:13];
    NSColor *c = attrs[NSForegroundColorAttributeName] ?: [NSColor blackColor];
    CGFloat r = 0, g = 0, b = 0, a = [c alphaComponent];
    if ([c numberOfComponents] == 2) r = g = b = [c whiteComponent]; else { r = [c redComponent]; g = [c greenComponent]; b = [c blueComponent]; }
    CGColorRef cg = CGColorCreateSRGB(r, g, b, a);
    NSDictionary *ca = @{ (id)kCTFontAttributeName: (id)f, (id)kCTForegroundColorAttributeName: (__bridge id)cg };
    CGColorRelease(cg);
    CFAttributedStringRef as = CFAttributedStringCreate(kCFAllocatorDefault, (__bridge CFStringRef)(s ?: @""), (__bridge CFDictionaryRef)ca);
    CTLineRef line = CTLineCreateWithAttributedString(as);
    CFRelease(as);
    CGFloat lead = 0;
    double w = CTLineGetTypographicBounds(line, ascent, descent, &lead);
    if (width) *width = (CGFloat)w;
    return line;
}

@implementation NSString (OpenDrawing)
- (void)drawAtPoint:(CGPoint)point withAttributes:(NSDictionary *)attrs
{
    NSGraphicsContext *gc = [NSGraphicsContext currentContext];
    CGContextRef cg = [gc CGContext];
    if (!cg) return;
    CGFloat asc = 0, desc = 0, w = 0;
    CTLineRef line = OpenLine(self, attrs, &asc, &desc, &w);
    CGContextSaveGState(cg);
    if ([gc isFlipped]) { CGContextSetTextMatrix(cg, CGAffineTransformMake(1, 0, 0, -1, 0, 0)); CGContextSetTextPosition(cg, point.x, point.y + asc); }
    else { CGContextSetTextMatrix(cg, CGAffineTransformIdentity); CGContextSetTextPosition(cg, point.x, point.y + desc); }
    CTLineDraw(line, cg);
    CGContextRestoreGState(cg);
    CFRelease(line);
}
- (void)drawInRect:(CGRect)rect withAttributes:(NSDictionary *)attrs
{
    NSGraphicsContext *gc = [NSGraphicsContext currentContext];
    CGFloat asc = 0, desc = 0, w = 0;
    CTLineRef line = OpenLine(self, attrs, &asc, &desc, &w); CFRelease(line);
    CGPoint p = rect.origin;
    if (![gc isFlipped]) p.y = rect.origin.y + rect.size.height - (asc + desc);	/* the top of the rect */
    [self drawAtPoint:p withAttributes:attrs];
}
- (CGSize)sizeWithAttributes:(NSDictionary *)attrs
{
    CGFloat asc = 0, desc = 0, w = 0;
    CTLineRef line = OpenLine(self, attrs, &asc, &desc, &w); CFRelease(line);
    return CGSizeMake(w, asc + desc);
}
@end

/* CoreText asks AppKit for the default writing direction of a language (GetDefaultWritingDirection) */
#import "NSParagraphStyle.h"
@interface NSParagraphStyle (OpenCoreText) + (NSInteger)defaultWritingDirectionForLanguage:(NSString *)language; @end
@implementation NSParagraphStyle (OpenCoreText)
+ (NSInteger)defaultWritingDirectionForLanguage:(NSString *)language
{
    NSString *l = [language lowercaseString];
    BOOL rtl = [l hasPrefix:@"ar"] || [l hasPrefix:@"he"] || [l hasPrefix:@"fa"] || [l hasPrefix:@"ur"];
    return rtl ? 1 : 0;					/* NSWritingDirectionRightToLeft / LeftToRight */
}
@end

/* ---- push button: rounded rectangle, radius 5, 24 pt high centred in the frame, white 8 % over the window (21 % pressed), the accent for the default button (docs/UI-MAC.md) ---- */
#import "NSButton.h"
static const void *kOpenPressed = &kOpenPressed;
@implementation NSButton (OpenDrawing)
- (void)drawRect:(CGRect)dirty
{
    CGContextRef cg = [[NSGraphicsContext currentContext] CGContext];
    if (!cg) return;
    CGRect b = [self bounds], r = CGRectMake(b.origin.x + 1, b.origin.y + (b.size.height - 24) / 2, b.size.width - 2, 24);
    NSInteger kind = [self respondsToSelector:@selector(_openKind)] ? (NSInteger)[self performSelector:@selector(_openKind)] : 0;
    if (kind) {		/* check box (1) / radio (2): 14 pt box, accent when on, then the title */
        CGRect bx = CGRectMake(1, (b.size.height - 14) / 2, 14, 14); BOOL on = [self state] != 0;
        if (on) CGContextSetRGBFillColor(cg, 0, 122 / 255.0, 1, 1); else CGContextSetRGBFillColor(cg, 1, 1, 1, 0.12);
        CGPathRef pp = CGPathCreateWithRoundedRect(bx, kind == 2 ? 7 : 4, kind == 2 ? 7 : 4, NULL); CGContextAddPath(cg, pp); CGContextFillPath(cg); CGPathRelease(pp);
        if (on) { CGContextSetRGBStrokeColor(cg, 1, 1, 1, 1); CGContextSetLineWidth(cg, 2); CGContextMoveToPoint(cg, 4, b.size.height / 2); CGContextAddLineToPoint(cg, 7, b.size.height / 2 - 3); CGContextAddLineToPoint(cg, 12, b.size.height / 2 + 3); CGContextStrokePath(cg); }
        NSDictionary *a2 = @{ NSFontAttributeName: [NSFont systemFontOfSize:13], NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:1 alpha:0.85] };
        CGSize t2 = [[self title] sizeWithAttributes:a2]; [[self title] drawAtPoint:CGPointMake(22, (b.size.height - t2.height) / 2) withAttributes:a2];
        return;
    }
    BOOL down = [objc_getAssociatedObject(self, kOpenPressed) boolValue], def = NO;
    if (def) CGContextSetRGBFillColor(cg, down ? 30 / 255.0 : 0, down ? 138 / 255.0 : 122 / 255.0, 1, 1); else CGContextSetRGBFillColor(cg, 1, 1, 1, down ? 0.21 : 0.08);
    CGPathRef p = CGPathCreateWithRoundedRect(r, 5, 5, NULL); CGContextAddPath(cg, p); CGContextFillPath(cg); CGPathRelease(p);
    NSString *t = [self title];
    NSDictionary *at = @{ NSFontAttributeName: [NSFont systemFontOfSize:13], NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:1 alpha:def ? 1 : 0.85] };
    CGSize ts = [t sizeWithAttributes:at];
    [t drawAtPoint:CGPointMake(r.origin.x + (r.size.width - ts.width) / 2, r.origin.y + (r.size.height - ts.height) / 2) withAttributes:at];
}
- (void)mouseDown:(NSEvent *)e { objc_setAssociatedObject(self, kOpenPressed, @YES, OBJC_ASSOCIATION_RETAIN); [self display]; }
- (void)mouseUp:(NSEvent *)e
{
    objc_setAssociatedObject(self, kOpenPressed, @NO, OBJC_ASSOCIATION_RETAIN);
    if ([self respondsToSelector:@selector(_openKind)] && (NSInteger)[self performSelector:@selector(_openKind)]) [self setState:[self state] ? 0 : 1];
    CGPoint p = [e locationInWindow];
    for (NSView *v = self; v && v != [[self window] contentView]; v = [v superview]) { p.x -= [v frame].origin.x; p.y -= [v frame].origin.y; }
    if ([self window]) { CGRect cf = [[[self window] contentView] frame]; p.x -= cf.origin.x; p.y -= cf.origin.y; }
    [self display];
    if (CGRectContainsPoint([self bounds], p) && [self action]) [[self target] performSelector:[self action] withObject:self];
}
@end

/* ---- text field: bezel = 1 px border (window colour lightened 5 %) round the text background (23,24,25), radius 6 (WsdMacTheme.m); editing: click takes the keys, characters append, delete removes, return sends the action ---- */
#import "NSTextField.h"
@implementation NSTextField (OpenDrawing)
- (BOOL)acceptsFirstResponder { return [self isEditable]; }
- (void)drawRect:(CGRect)dirty
{
    CGContextRef cg = [[NSGraphicsContext currentContext] CGContext];
    if (!cg) return;
    CGRect b = [self bounds];
    if ([self isBezeled]) {
        CGPathRef p = CGPathCreateWithRoundedRect(CGRectInset(b, 0.5, 0.5), 6, 6, NULL);
        CGContextSetRGBFillColor(cg, 23 / 255.0, 24 / 255.0, 25 / 255.0, 1); CGContextAddPath(cg, p); CGContextFillPath(cg);
        CGContextSetRGBStrokeColor(cg, 1, 1, 1, 0.12); CGContextSetLineWidth(cg, 1); CGContextAddPath(cg, p); CGContextStrokePath(cg);
        CGPathRelease(p);
    }
    NSDictionary *at = @{ NSFontAttributeName: [NSFont systemFontOfSize:13], NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:1 alpha:0.85] };
    NSString *t = [self stringValue]; CGSize ts = [t sizeWithAttributes:at];
    CGFloat x = [self isBezeled] ? 5 : 0, y = b.origin.y + (b.size.height - ts.height) / 2;
    if ([t length]) [t drawAtPoint:CGPointMake(x, y) withAttributes:at];
    if ([[self window] firstResponder] == self) { CGContextSetRGBFillColor(cg, 0.3, 0.6, 1, 1); CGContextFillRect(cg, CGRectMake(x + ts.width + 1, y, 1.5, ts.height > 0 ? ts.height : 15)); }
}
- (void)mouseDown:(NSEvent *)e { if ([self isEditable]) { [[self window] makeFirstResponder:self]; [self display]; } }
- (void)keyDown:(NSEvent *)e
{
    NSString *c = [e characters], *s = [self stringValue];
    if ([c isEqualToString:@"\x7f"]) { if ([s length]) [self setStringValue:[s substringToIndex:[s length] - 1]]; }
    else if ([c isEqualToString:@"\r"]) { if ([self action]) [[self target] performSelector:[self action] withObject:self]; }
    else if ([c length] && [c characterAtIndex:0] >= 32) [self setStringValue:[s stringByAppendingString:c]];
    [self display];
}
@end

/* ---- the gaps of our AppKit: a selector of one of our classes that nobody implements is logged once and answers 0 (OPEN_STRICT=1: it stays an exception) ---- */
static id OpenZero(id self, SEL _cmd) { return nil; }
@interface NSObject (OpenGaps) @end
@implementation NSObject (OpenGaps)
+ (BOOL)resolveInstanceMethod:(SEL)sel
{
    const char *img = class_getImageName(self);
    if (!img || !strstr(img, "/open/") || getenv("OPEN_STRICT")) return NO;
    fprintf(stderr, "open: unimplemented -[%s %s]\n", class_getName(self), sel_getName(sel));
    class_addMethod(self, sel, (IMP)OpenZero, "@@:");
    return YES;
}
+ (BOOL)resolveClassMethod:(SEL)sel
{
    const char *img = class_getImageName(self);
    if (!img || !strstr(img, "/open/") || getenv("OPEN_STRICT")) return NO;
    fprintf(stderr, "open: unimplemented +[%s %s]\n", class_getName(self), sel_getName(sel));
    class_addMethod(object_getClass(self), sel, (IMP)OpenZero, "@@:");
    return YES;
}
@end

@implementation NSGraphicsContext (OpenScreen)
- (BOOL)isDrawingToScreen { return YES; }
@end
@implementation NSApplication (OpenEvent)
- (NSEvent *)currentEvent { return nil; }
@end
