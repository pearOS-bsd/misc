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
extern void OpenDrawPushButton(CGContextRef cg, CGRect frame, NSString *title, BOOL isDefault, BOOL enabled, BOOL pressed);
extern void OpenDrawTextBezel(CGContextRef cg, CGRect frame);
extern void OpenDrawCheck(CGContextRef cg, CGRect box, BOOL radio, BOOL on);
#import <objc/message.h>
#include "ws_client.h"
#include <poll.h>

@interface NSWindow (OpenPrivate) - (CGRect)_openFrame; @end

static ws_conn *sConn;
static NSMapTable *sWindows;
static NSWindow *sKeyWindow;			/* wsd window id -> NSWindow (weak) */
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
@interface OpenWin : NSObject { @public ws_win win; CGContextRef cg; BOOL shown; int tb; BOOL hover; int pressed; BOOL glassSet; } @end
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
    if (tb && (top < 28 || top > sScreenH - 60)) top = 60 + (int)([[sWindows keyEnumerator] allObjects].count % 8) * 24;		/* a window from a nib may carry a position of another screen: keep it visible */
    if (tb && (f.origin.x < 0 || f.origin.x > 1000)) f.origin.x = 120 + top;
    o = [OpenWin new]; o->pressed = -1;
    o->tb = tb;
    if (ws_win_create(c, (ws_rect){ (int)f.origin.x, top, (int)f.size.width, (int)f.size.height + tb }, 0, &o->win)) { NSLog(@"open: cannot create the window"); return nil; }
    CGColorSpaceRef cs = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    o->cg = CGBitmapContextCreate(o->win.px->px, o->win.px->w, o->win.px->h, 8, o->win.px->stride, cs, (CGBitmapInfo)kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
    CGColorSpaceRelease(cs);
    objc_setAssociatedObject(w, kOpenWinKey, o, OBJC_ASSOCIATION_RETAIN);
    if (!sWindows) sWindows = [NSMapTable strongToWeakObjectsMapTable];
    [sWindows setObject:w forKey:@(o->win.id)];
    ws_win_set_event_mask(c, &o->win, -1);
    ws_win_shadow(c, &o->win, tb ? 16 : 12, tb ? 1 : 2);		/* titled windows: the shadow and the rounded corners of the window server; borderless ones (menus, panels): the menu shadow */
    return o;
}

/* a view and its subviews into the current CGContext: the origin of the view, flipped views get a y axis that goes down */
extern void OpenLayerPaint(NSView *v, CGContextRef cg, CGRect b);
static void OpenDrawView(NSView *v, CGContextRef cg)
{
    if ([v isKindOfClass:NSClassFromString(@"NSClipView")]) for (NSView *d in [v subviews]) if ([d frame].size.width <= 0 || [d frame].size.height <= 0) [d setFrame:[v bounds]];		/* a document view without a size takes the one of its clip view (as the scroll view does) */
    CGRect fr = [v frame], b = [v bounds];
    CGContextSaveGState(cg);
    CGContextTranslateCTM(cg, fr.origin.x, fr.origin.y);
    CGContextClipToRect(cg, CGRectMake(0, 0, fr.size.width, fr.size.height));
    if ([v isFlipped]) { CGContextTranslateCTM(cg, 0, fr.size.height); CGContextScaleCTM(cg, 1, -1); }
    NSGraphicsContext *gc = [NSGraphicsContext graphicsContextWithCGContext:cg flipped:[v isFlipped]];
    NSGraphicsContext *old = [NSGraphicsContext currentContext];
    [NSGraphicsContext setCurrentContext:gc];
    OpenLayerPaint(v, cg, b);
    if (getenv("OPEN_DEBUG") && ([v isKindOfClass:NSClassFromString(@"NSText")] || [v isKindOfClass:NSClassFromString(@"NSScrollView")])) { static int n; if (n++ < 6) { id bc = [v respondsToSelector:@selector(backgroundColor)] ? [v performSelector:@selector(backgroundColor)] : nil; fprintf(stderr, "open: bg %s draws=%d color=%s\n", class_getName([v class]), [v respondsToSelector:@selector(drawsBackground)] ? ((BOOL(*)(id,SEL))objc_msgSend)(v, @selector(drawsBackground)) : -1, bc ? [[bc description] UTF8String] : "nil"); } }
    [v drawRect:b];
    [NSGraphicsContext setCurrentContext:old];
    CGContextRestoreGState(cg);
    CGContextSaveGState(cg);
    CGContextTranslateCTM(cg, fr.origin.x, fr.origin.y);
    if ([v isFlipped]) { CGContextTranslateCTM(cg, 0, fr.size.height); CGContextScaleCTM(cg, 1, -1); }
    for (NSView *s in [v subviews]) OpenDrawView(s, cg);
    CGContextRestoreGState(cg);
}

static void OpenDump(NSView *v, int d)
{
    CGRect f = [v frame];
    fprintf(stderr, "open: view %*s%s (%g,%g %gx%g) subviews %lu\n", d * 2, "", class_getName([v class]), f.origin.x, f.origin.y, f.size.width, f.size.height, (unsigned long)[[v subviews] count]);
    for (NSView *s in [v subviews]) OpenDump(s, d + 1);
}
static BOOL OpenWindowEdited(NSWindow *w)		/* the edited marker: the window's own flag or the document of its controller */
{
    if ([w respondsToSelector:@selector(isDocumentEdited)] && (BOOL)(NSInteger)[w performSelector:@selector(isDocumentEdited)]) return YES;
    id wc = [w respondsToSelector:NSSelectorFromString(@"windowController")] ? [w performSelector:NSSelectorFromString(@"windowController")] : nil;
    id d = [wc respondsToSelector:@selector(document)] ? [wc performSelector:@selector(document)] : nil;
    return [d respondsToSelector:@selector(isDocumentEdited)] && (BOOL)(NSInteger)[d performSelector:@selector(isDocumentEdited)];
}
extern void OpenDrawTitleBar(CGContextRef cg, CGFloat W, CGFloat H, NSString *title, BOOL key, BOOL hover, int pressed, BOOL edited, BOOL hasClose, BOOL hasMini, BOOL hasZoom);
void OpenWindowDisplay(NSWindow *w)
{
    static int dumped; if (getenv("OPEN_DEBUG") && dumped++ < 2) OpenDump([w contentView], 0);
    OpenWin *o = OpenWinOf(w, NO);
    if (!o) return;
    CGContextSaveGState(o->cg);
    CGContextClearRect(o->cg, CGRectMake(0, 0, o->win.px->w, o->win.px->h));
    BOOL glass = !o->tb && [[w contentView] respondsToSelector:@selector(_openGlass)];
    if (glass) { if (!o->glassSet) { ws_win_glass(sConn, &o->win, (ws_rect){ 0, 0, o->win.px->w, o->win.px->h }, 12, 5); o->glassSet = YES; } }
    else { id wbg = [w performSelector:@selector(backgroundColor)]; if (getenv("OPEN_DEBUG")) { static int n; if (n++ < 3) { CGFloat cr = -1, cg2 = -1, cb = -1, ca = -1; if ([wbg respondsToSelector:@selector(getRed:green:blue:alpha:)]) [wbg getRed:&cr green:&cg2 blue:&cb alpha:&ca]; fprintf(stderr, "open: window bg %g %g %g %g content layer %p\n", cr, cg2, cb, ca, (__bridge void *)[[w contentView] performSelector:@selector(layer)]); } } if ([wbg respondsToSelector:@selector(CGColor)]) CGContextSetFillColorWithColor(o->cg, [wbg CGColor]); else CGContextSetRGBFillColor(o->cg, 30 / 255.0, 30 / 255.0, 30 / 255.0, 1); CGContextFillRect(o->cg, CGRectMake(0, 0, o->win.px->w, o->win.px->h - o->tb)); }		/* window background (dark); menus: the material of the window server under a transparent window */
    NSView *cv = [w contentView];
    if (cv) { @try { OpenDrawView(cv, o->cg); } @catch (NSException *ex) { fprintf(stderr, "open: exception while drawing: %s: %s\n", [[ex name] UTF8String], [[ex reason] UTF8String]); } }
    if (o->tb) {
        NSGraphicsContext *gc = [NSGraphicsContext graphicsContextWithCGContext:o->cg flipped:NO];
        NSGraphicsContext *old = [NSGraphicsContext currentContext]; [NSGraphicsContext setCurrentContext:gc];
        NSUInteger sm = [w styleMask];
        OpenDrawTitleBar(o->cg, o->win.px->w, o->win.px->h, [w title], sKeyWindow == w, o->hover, o->pressed, OpenWindowEdited(w), (sm & 2) != 0, (sm & 4) != 0, (sm & 8) != 0);
        [NSGraphicsContext setCurrentContext:old];
    }
    CGContextRestoreGState(o->cg);
    int fr_ = ws_win_flush(sConn, &o->win); if (getenv("OPEN_DEBUG")) fprintf(stderr, "open: display flush rc %d\n", fr_);
}

NSWindow *OpenKeyWindow(void) { return sKeyWindow; }
void OpenWindowOrderFront(NSWindow *w)
{
    OpenWin *o = OpenWinOf(w, YES);
    if (!o) return;
    OpenWindowDisplay(w);
    ws_win_order(sConn, &o->win, WS_ABOVE, 0);
    o->shown = YES;
    ws_win_set_key(sConn, &o->win); sKeyWindow = w; OpenMenuPublish(YES);
}

void OpenWindowOrderOut(NSWindow *w)
{
    OpenWin *o = OpenWinOf(w, NO);
    if (o && o->shown) { ws_win_order(sConn, &o->win, WS_OUT, 0); o->shown = NO; }
}

static NSView *sMouseView;				/* the view that took the mouse down: it gets the drag and the up */
extern BOOL OpenMenuKeyEquivalent(int keyCode, BOOL shift);
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
    if (o && o->tb && (e->type == WS_EV_MOUSE_DOWN || e->type == WS_EV_MOUSE_MOVE || e->type == WS_EV_MOUSE_UP)) {	/* the title bar: the three buttons (16 pt at x = 8, 31, 54), hover over the group, dragging */
        BOOL inBar = e->y < o->tb, grp = inBar && e->x >= 4 && e->x < 8 + 23 * 2 + 16 + 4;
        if (grp != o->hover) { o->hover = grp; OpenWindowDisplay(w); }
        int bi = -1; for (int i = 0; i < 3; i++) if (inBar && e->x >= 8 + 23 * i && e->x < 8 + 23 * i + 16) bi = i;
        if (e->type == WS_EV_MOUSE_DOWN && bi >= 0) { o->pressed = bi; OpenWindowDisplay(w); return; }
        if (o->pressed >= 0) {
            if (e->type == WS_EV_MOUSE_UP) {
                int i = o->pressed; o->pressed = -1; OpenWindowDisplay(w);
                if (bi == i) { if (i == 0 && [w respondsToSelector:@selector(performClose:)]) [w performSelector:@selector(performClose:) withObject:nil]; else if (i == 1 && [w respondsToSelector:@selector(performMiniaturize:)]) [w performSelector:@selector(performMiniaturize:) withObject:nil]; }
            }
            return;
        }
        if (e->type == WS_EV_MOUSE_DOWN && inBar) { sDragWid = e->wid; sDragX = e->x; sDragY = e->y; return; }
        if (inBar && !sDragWid) return;
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
    case WS_EV_FOCUS_IN: { OpenWin *fo = OpenWinOf(w, NO); if (fo && fo->tb) { sKeyWindow = w; OpenMenuPublish(YES); } break; }
    case WS_EV_FOCUS_OUT: { if ([cv respondsToSelector:@selector(_openFocusOut)]) [cv performSelector:@selector(_openFocusOut)]; break; }
    case WS_EV_SCROLL: {
        NSView *v = [cv hitTest:p];
        while (v && ![v respondsToSelector:@selector(_openScrollBy:)]) v = [v superview];
        if (v) [v performSelector:@selector(_openScrollBy:) withObject:@((double)e->dy)];
        break; }
    case WS_EV_KEY_DOWN: case WS_EV_KEY_UP: {
        if (getenv("OPEN_DEBUG")) fprintf(stderr, "open: key %d flags %lx type %d\n", (int)e->key, (unsigned long)fl, (int)e->type);
        NSEvent *ev = [NSEvent keyEventWithType:e->type == WS_EV_KEY_DOWN ? NSEventTypeKeyDown : NSEventTypeKeyUp location:CGPointZero modifierFlags:fl timestamp:t windowNumber:e->wid context:nil characters:OpenKeyChars((unsigned short)e->key, (fl & NSEventModifierFlagShift) != 0) charactersIgnoringModifiers:OpenKeyChars((unsigned short)e->key, NO) isARepeat:NO keyCode:(unsigned short)e->key];
        if (e->type == WS_EV_KEY_DOWN && (fl & 0x100000) && OpenMenuKeyEquivalent(e->key, (fl & NSEventModifierFlagShift) != 0)) break;
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
    id dc = NSClassFromString(@"NSDocumentController");
    if (dc && [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDocumentTypes"] count]) {		/* a document-based program opens an untitled document at launch */
        id sdc = [dc performSelector:@selector(sharedDocumentController)];
        BOOL should = ![(id)d respondsToSelector:@selector(applicationShouldOpenUntitledFile:)] || (BOOL)(NSInteger)[(id)d performSelector:@selector(applicationShouldOpenUntitledFile:) withObject:self];
        NSMutableArray *files = [NSMutableArray new];			/* files given as arguments are opened instead of the untitled document */
        for (NSString *a in [[NSProcessInfo processInfo] arguments]) if ([a hasPrefix:@"/"] && [[NSFileManager defaultManager] fileExistsAtPath:a] && ![a isEqualToString:[[NSBundle mainBundle] executablePath]]) [files addObject:a];
        if ([files count]) {
            for (NSString *f in files) {
                if ([(id)d respondsToSelector:@selector(application:openFile:)]) ((BOOL(*)(id, SEL, id, id))objc_msgSend)(d, @selector(application:openFile:), self, f);
                else { NSError *err = nil; ((id(*)(id, SEL, id, BOOL, NSError **))objc_msgSend)(sdc, @selector(openDocumentWithContentsOfURL:display:error:), [NSURL fileURLWithPath:f], YES, &err); }
            }
            should = NO;
        }
        if (should && ![[sdc performSelector:@selector(documents)] count]) { NSError *err = nil; ((id(*)(id, SEL, BOOL, NSError **))objc_msgSend)(sdc, @selector(openUntitledDocumentAndDisplay:error:), YES, &err); }
    }
    OpenMenuBarShow();
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
    CGRect b = [self bounds];
    NSInteger kind = [self respondsToSelector:@selector(_openKind)] ? (NSInteger)[self performSelector:@selector(_openKind)] : 0;
    BOOL down = [objc_getAssociatedObject(self, kOpenPressed) boolValue];
    if (kind) {		/* check box (1) / radio (2): the 16 pt box of the theme, then the title */
        OpenDrawCheck(cg, CGRectMake(1, (b.size.height - 16) / 2, 16, 16), kind == 2, [self state] != 0);
        NSDictionary *a2 = @{ NSFontAttributeName: [NSFont systemFontOfSize:13], NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:1 alpha:0.85] };
        CGSize t2 = [[self title] sizeWithAttributes:a2]; [[self title] drawAtPoint:CGPointMake(24, (b.size.height - t2.height) / 2) withAttributes:a2];
        return;
    }
    BOOL def = [self respondsToSelector:@selector(keyEquivalent)] && [[self performSelector:@selector(keyEquivalent)] isEqual:@"\r"];
    OpenDrawPushButton(cg, CGRectInset(b, 1, 0), [self title], def, YES, down);
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
    if ([self isBezeled]) OpenDrawTextBezel(cg, b);
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

/* ---- the gaps of our AppKit: a selector that a class of ours (or a subclass of one, e.g. the Document of an application) does not implement is logged once and answers 0 through the forwarding path
 * (not resolveInstanceMethod: that one is also asked by respondsToSelector:, and the answer YES would be wrong; OPEN_STRICT=1 keeps the exception) ---- */
static BOOL OpenInheritsOurs(Class c)
{
    for (; c; c = class_getSuperclass(c)) { const char *img = class_getImageName(c); if (img && strstr(img, "/open/")) return YES; }
    return NO;
}
static IMP sOrigSig, sOrigFwd, sOrigCSig, sOrigCFwd;
static NSMutableSet *sLogged;
static void OpenLogGap(Class c, SEL s, BOOL cls)
{
    if (!sLogged) sLogged = [NSMutableSet new];
    NSString *k = [NSString stringWithFormat:@"%c%s %s", cls ? '+' : '-', class_getName(c), sel_getName(s)];
    if ([sLogged containsObject:k]) return; [sLogged addObject:k];
    { char ch[256] = ""; for (Class k = class_getSuperclass(c); k && strlen(ch) < 200; k = class_getSuperclass(k)) { strcat(ch, " < "); strcat(ch, class_getName(k)); } fprintf(stderr, "open: unimplemented %c[%s %s]  (%s)\n", cls ? '+' : '-', class_getName(c), sel_getName(s), ch); }
}
static id OpenSig(id self, SEL _cmd, SEL s)
{
    id sig = ((id(*)(id, SEL, SEL))sOrigSig)(self, _cmd, s);
    if (!sig && !getenv("OPEN_STRICT") && OpenInheritsOurs(object_getClass(self))) { OpenLogGap(object_getClass(self), s, NO); sig = [NSMethodSignature signatureWithObjCTypes:"@@:"]; }
    return sig;
}
static void OpenFwd(id self, SEL _cmd, NSInvocation *inv)
{
    if (getenv("OPEN_DEBUG")) fprintf(stderr, "open: fwd %s on %s inherits=%d\n", sel_getName([inv selector]), class_getName(object_getClass(self)), (int)OpenInheritsOurs(object_getClass(self)));
    if (!getenv("OPEN_STRICT") && OpenInheritsOurs(object_getClass(self)) ) { id zero = nil; if ([[inv methodSignature] methodReturnLength] == sizeof(id)) [inv setReturnValue:&zero]; return; }
    ((void(*)(id, SEL, id))sOrigFwd)(self, _cmd, inv);
}
static id OpenCSig(id self, SEL _cmd, SEL s)
{
    id sig = ((id(*)(id, SEL, SEL))sOrigCSig)(self, _cmd, s);
    if (!sig && !getenv("OPEN_STRICT") && OpenInheritsOurs((Class)self)) { OpenLogGap((Class)self, s, YES); sig = [NSMethodSignature signatureWithObjCTypes:"@@:"]; }
    return sig;
}
static void OpenCFwd(id self, SEL _cmd, NSInvocation *inv)
{
    if (!getenv("OPEN_STRICT") && OpenInheritsOurs((Class)self) ) { id zero = nil; if ([[inv methodSignature] methodReturnLength] == sizeof(id)) [inv setReturnValue:&zero]; return; }
    ((void(*)(id, SEL, id))sOrigCFwd)(self, _cmd, inv);
}
#define _XOPEN_SOURCE 600
#include <signal.h>
#include <execinfo.h>
#include <dlfcn.h>
#include <ucontext.h>
static void OpenCrash(int sig, siginfo_t *si, void *uc)
{
    ucontext_t *u = uc; unsigned long long rip = u->uc_mcontext->__ss.__rip; Dl_info di;
    fprintf(stderr, "open: CRASH signal %d at address %p, rip %#llx", sig, si->si_addr, rip);
    if (dladdr((void *)rip, &di)) fprintf(stderr, " in %s (%s)", di.dli_sname ? di.dli_sname : "?", di.dli_fname);
    fprintf(stderr, "\n"); void *bt[30]; int n = backtrace(bt, 30); backtrace_symbols_fd(bt, n, 2); _exit(139);
}
__attribute__((constructor)) static void OpenInstallGaps(void)
{
    struct sigaction sa; memset(&sa, 0, sizeof sa); sa.sa_sigaction = OpenCrash; sa.sa_flags = SA_SIGINFO;
    sigaction(SIGSEGV, &sa, NULL); sigaction(SIGBUS, &sa, NULL); sigaction(SIGILL, &sa, NULL); sigaction(SIGTRAP, &sa, NULL); sigaction(SIGABRT, &sa, NULL);
    Class no = [NSObject class], meta = object_getClass(no);
    Method m;
    m = class_getInstanceMethod(no, @selector(methodSignatureForSelector:)); sOrigSig = method_setImplementation(m, (IMP)OpenSig);
    m = class_getInstanceMethod(no, @selector(forwardInvocation:)); sOrigFwd = method_setImplementation(m, (IMP)OpenFwd);
    m = class_getClassMethod(no, @selector(methodSignatureForSelector:)); sOrigCSig = method_setImplementation(m, (IMP)OpenCSig); (void)meta;
    m = class_getClassMethod(no, @selector(forwardInvocation:)); if (m) sOrigCFwd = method_setImplementation(m, (IMP)OpenCFwd);
}

@implementation NSGraphicsContext (OpenScreen)
- (BOOL)isDrawingToScreen { return YES; }
@end
@implementation NSApplication (OpenEvent)
- (NSEvent *)currentEvent { return nil; }
@end

/* ---- the real AppKit must not come in next to ours: UIFoundation dlopens /System/Library/Frameworks/AppKit.framework/AppKit to find NSAppearance and others.  The call is redirected to our AppKit
 * (a dyld interposing tuple of this dylib) ---- */
#include <dlfcn.h>
static void *OpenDlopen(const char *p, int f)
{
    if (p && strstr(p, "/AppKit.framework/") && !strstr(p, "/open/")) { if (getenv("OPEN_DEBUG")) fprintf(stderr, "open: dlopen(%s) -> /open/AppKit\n", p); return dlopen("/open/AppKit", f); }
    return dlopen(p, f);
}

/* ---- the user database: the Mac's getpwuid asks the directory service, which is not there; the answer comes from /etc/passwd (programs take pw_dir without looking at the result) ---- */
#include <pwd.h>
static struct passwd sPw; static char sPwBuf[1024];
static struct passwd *OpenPwLookup(const char *name, uid_t uid, BOOL byName)
{
    FILE *f = fopen("/etc/passwd", "r"); char line[512]; struct passwd *res = NULL;
    while (f && fgets(line, sizeof line, f)) {
        char *fld[7]; int n = 0; char *p = line; fld[n++] = p;
        for (; *p && n < 7; p++) if (*p == ':') { *p = 0; fld[n++] = p + 1; } else if (*p == '\n') *p = 0;
        if (n < 7) continue;
        if (byName ? strcmp(fld[0], name) == 0 : (uid_t)atoi(fld[2]) == uid) {
            snprintf(sPwBuf, sizeof sPwBuf, "%s%c%s%c%s%c%s%c%s", fld[0], 0, fld[1], 0, fld[4], 0, fld[5], 0, fld[6]);
            char *q = sPwBuf; sPw.pw_name = q; q += strlen(q) + 1; sPw.pw_passwd = q; q += strlen(q) + 1; sPw.pw_gecos = q; q += strlen(q) + 1; sPw.pw_dir = q; q += strlen(q) + 1; sPw.pw_shell = q;
            sPw.pw_uid = (uid_t)atoi(fld[2]); sPw.pw_gid = (gid_t)atoi(fld[3]); sPw.pw_change = 0; sPw.pw_expire = 0; sPw.pw_class = (char *)""; res = &sPw; break;
        }
    }
    if (f) fclose(f);
    if (!res) { snprintf(sPwBuf, sizeof sPwBuf, "user%c*%c%c%s%c/bin/sh", 0, 0, 0, getenv("HOME") ?: "/", 0); char *q = sPwBuf; sPw.pw_name = q; q += 5; sPw.pw_passwd = q; q += 2; sPw.pw_gecos = q; q += 1; sPw.pw_dir = q; q += strlen(q) + 1; sPw.pw_shell = q; sPw.pw_uid = uid; sPw.pw_gid = 0; sPw.pw_class = (char *)""; res = &sPw; }
    return res;
}
static struct passwd *OpenGetpwuid(uid_t u) { return OpenPwLookup(NULL, u, NO); }
static struct passwd *OpenGetpwnam(const char *n) { return OpenPwLookup(n, 0, YES); }
__attribute__((used)) static struct { const void *r, *o; } sOpenInterpose[] __attribute__((section("__DATA,__interpose"))) = { { (const void *)OpenDlopen, (const void *)dlopen }, { (const void *)OpenGetpwuid, (const void *)getpwuid }, { (const void *)OpenGetpwnam, (const void *)getpwnam } };
