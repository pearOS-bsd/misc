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
#define OPEN_TITLEBAR 28
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
    NSView *cv = [w contentView];
    if (cv) OpenDrawView(cv, o->cg);
    if (o->tb) {
        CGFloat W = o->win.px->w, H = o->win.px->h, tb = o->tb;
        CGContextSetRGBFillColor(o->cg, 0.91, 0.91, 0.92, 1); CGContextFillRect(o->cg, CGRectMake(0, H - tb, W, tb));
        CGContextSetRGBFillColor(o->cg, 0.75, 0.75, 0.76, 1); CGContextFillRect(o->cg, CGRectMake(0, H - tb, W, 1));
        static const CGFloat col[3][3] = { { 1.0, 0.37, 0.34 }, { 1.0, 0.74, 0.18 }, { 0.16, 0.79, 0.25 } };
        for (int i = 0; i < 3; i++) { CGContextSetRGBFillColor(o->cg, col[i][0], col[i][1], col[i][2], 1); CGContextFillEllipseInRect(o->cg, CGRectMake(8 + i * 20, H - tb / 2 - 6, 12, 12)); }
        NSGraphicsContext *gc = [NSGraphicsContext graphicsContextWithCGContext:o->cg flipped:NO];
        NSGraphicsContext *old = [NSGraphicsContext currentContext]; [NSGraphicsContext setCurrentContext:gc];
        NSString *t = [w title]; NSDictionary *at = @{ NSFontAttributeName: [NSFont systemFontOfSize:13], NSForegroundColorAttributeName: [NSColor blackColor] };
        CGSize ts = [t sizeWithAttributes:at];
        [t drawAtPoint:CGPointMake((W - ts.width) / 2, H - tb / 2 - ts.height / 2) withAttributes:at];
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
            int i = e->x / 20;
            if (e->x < 62 && i < 3 && (e->x % 20) >= 8) { if (i == 0) { OpenWindowOrderOut(w); BOOL any = NO; for (NSNumber *k in [sWindows keyEnumerator]) { OpenWin *q = OpenWinOf([sWindows objectForKey:k], NO); if (q && q->shown) any = YES; } if (!any) exit(0); } return; }
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
        if (ty == NSEventTypeLeftMouseDown) sMouseView = v;
        if (ty == NSEventTypeLeftMouseUp) sMouseView = nil;
        if (ty == NSEventTypeLeftMouseDown) [v mouseDown:ev];
        else if (ty == NSEventTypeLeftMouseUp) [v mouseUp:ev];
        else if (ty == NSEventTypeLeftMouseDragged) [v mouseDragged:ev];
        else [v mouseMoved:ev];
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
                    dispatch_async(dispatch_get_main_queue(), ^{ OpenDispatch(&ev); });
                }
            }
        });
    }
    CFRunLoopRun();
}

/* ---- what the views and colours need to draw ---- */
@implementation NSView (OpenDrawing)
- (void)drawRect:(CGRect)dirtyRect { }
- (void)setNeedsDisplay:(BOOL)flag { if (flag && [self window]) OpenWindowDisplay([self window]); }
- (void)display { if ([self window]) OpenWindowDisplay([self window]); }
@end

@implementation NSColor (OpenDrawing)
- (void)setFill
{
    CGContextRef cg = [[NSGraphicsContext currentContext] CGContext];
    if (!cg) return;
    NSColor *c = [self numberOfComponents] == 2 ? nil : self;			/* gray + alpha */
    CGFloat r = 0, g = 0, b = 0, a = [self alphaComponent];
    if (c) { r = [self redComponent]; g = [self greenComponent]; b = [self blueComponent]; }
    else { r = g = b = [self whiteComponent]; }
    CGContextSetRGBFillColor(cg, r, g, b, a);
}
- (void)set { [self setFill]; CGContextRef cg = [[NSGraphicsContext currentContext] CGContext]; if (cg) { CGFloat a = [self alphaComponent]; CGContextSetRGBStrokeColor(cg, [self redComponent], [self greenComponent], [self blueComponent], a); } }
@end

@implementation NSApplication (OpenRun)
- (void)run { OpenRunLoop(); }
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
    NSDictionary *ca = @{ (id)kCTFontAttributeName: (__bridge id)[f CTFont], (id)kCTForegroundColorAttributeName: (__bridge id)cg };
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
