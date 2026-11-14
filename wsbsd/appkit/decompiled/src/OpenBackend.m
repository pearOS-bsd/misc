/* OpenBackend.m: ordering, drawing and the loop of an NSWindow through wsd. */
#import "OpenBackend.h"
#import "NSWindow.h"
#import "NSView.h"
#import "NSApplication.h"
#import "NSColor.h"
#import "NSGraphicsContext.h"
#import <objc/runtime.h>
#include "ws_client.h"

@interface NSWindow (OpenPrivate) - (CGRect)_openFrame; @end

static ws_conn *sConn;
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
@interface OpenWin : NSObject { @public ws_win win; CGContextRef cg; BOOL shown; } @end
@implementation OpenWin @end
static const void *kOpenWinKey = &kOpenWinKey;
static OpenWin *OpenWinOf(NSWindow *w, BOOL create)
{
    OpenWin *o = objc_getAssociatedObject(w, kOpenWinKey);
    if (o || !create) return o;
    ws_conn *c = OpenConn();
    if (!c) return nil;
    CGRect f = [w _openFrame];
    int top = sScreenH - (int)(f.origin.y + f.size.height);
    o = [OpenWin new];
    if (ws_win_create(c, (ws_rect){ (int)f.origin.x, top, (int)f.size.width, (int)f.size.height }, 0, &o->win)) { NSLog(@"open: cannot create the window"); return nil; }
    CGColorSpaceRef cs = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    o->cg = CGBitmapContextCreate(o->win.px->px, o->win.px->w, o->win.px->h, 8, o->win.px->stride, cs, (CGBitmapInfo)kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
    CGColorSpaceRelease(cs);
    objc_setAssociatedObject(w, kOpenWinKey, o, OBJC_ASSOCIATION_RETAIN);
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
    CGContextRestoreGState(o->cg);
    ws_win_flush(sConn, &o->win);
}

void OpenWindowOrderFront(NSWindow *w)
{
    OpenWin *o = OpenWinOf(w, YES);
    if (!o) return;
    OpenWindowDisplay(w);
    ws_win_order(sConn, &o->win, WS_ABOVE, 0);
    o->shown = YES;
}

void OpenWindowOrderOut(NSWindow *w)
{
    OpenWin *o = OpenWinOf(w, NO);
    if (o && o->shown) { ws_win_order(sConn, &o->win, WS_OUT, 0); o->shown = NO; }
}

void OpenRunLoop(void)
{
    for (;;) CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.05, false);	/* the events of wsd (the event channel of the connection) are the next step */
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
