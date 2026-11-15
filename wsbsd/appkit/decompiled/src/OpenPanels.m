/* OpenPanels.m — modal windows: runModalForWindow: (a nested run loop on the main thread) and NSAlert on top of it */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "NSColor.h"
#import "NSGraphicsContext.h"
#import "NSEvent.h"
#import "NSWindow.h"
#import "NSView.h"
#import "NSApplication.h"
#import "NSButton.h"
#import "NSTextField.h"
#import "NSAlert.h"
#import "OpenBackend.h"
#import "NSFont.h"

@interface NSWindow (OpenFrame) - (CGRect)_openFrame; @end
static BOOL sModalRunning; static NSInteger sModalCode;

@implementation NSApplication (OpenModal)
- (NSInteger)runModalForWindow:(NSWindow *)w
{
    sModalRunning = YES; sModalCode = 0;
    [w makeKeyAndOrderFront:nil];
    while (sModalRunning) CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.02, false);
    [w orderOut:nil];
    return sModalCode;
}
- (void)stopModalWithCode:(NSInteger)code { sModalCode = code; sModalRunning = NO; }
- (void)stopModal { [self stopModalWithCode:-1000]; }
- (void)abortModal { [self stopModalWithCode:-1001]; }
@end

@interface OpenAlertTarget : NSObject @end
@implementation OpenAlertTarget
- (void)pressed:(NSButton *)b { [NSApp stopModalWithCode:[b tag]]; }
@end

@implementation NSAlert (OpenRun)
- (NSInteger)runModal
{
    NSArray *btns = [self buttons];
    if (![btns count]) [self addButtonWithTitle:@"OK"];
    btns = [self buttons];
    CGFloat W = 420, H = 150, x = W - 20;
    NSWindow *w = [[NSWindow alloc] initWithContentRect:CGRectMake((1280 - W) / 2, (800 - H) / 2, W, H) styleMask:0 backing:NSBackingStoreBuffered defer:NO];
    NSView *cv = [w contentView];
    NSTextField *m = [NSTextField labelWithString:[self messageText] ?: @""]; [m setFrame:CGRectMake(20, H - 44, W - 40, 20)]; [cv addSubview:m];
    NSTextField *i = [NSTextField labelWithString:[self informativeText] ?: @""]; [i setFrame:CGRectMake(20, H - 70, W - 40, 20)]; [cv addSubview:i];
    static OpenAlertTarget *tg; if (!tg) tg = [OpenAlertTarget new];
    NSInteger n = [btns count];
    for (NSInteger k = 0; k < n; k++) {			/* the first button is the right-most, 28 pt high */
        NSButton *b = btns[k]; CGFloat bw = 90; x -= bw;
        [b setFrame:CGRectMake(x, 16, bw, 32)]; [b setTag:1000 + k]; [b setTarget:tg]; [b setAction:@selector(pressed:)];
        [cv addSubview:b]; x -= 10;
    }
    return [NSApp runModalForWindow:w];
}
@end

/* ---- application: activation, termination ---- */
static NSInteger sPolicy; static BOOL sActive = YES;
@implementation NSApplication (OpenLifecycle)
- (BOOL)setActivationPolicy:(NSInteger)p { sPolicy = p; return YES; }
- (NSInteger)activationPolicy { return sPolicy; }
- (void)activateIgnoringOtherApps:(BOOL)f { sActive = YES; }
- (void)activate { sActive = YES; }
- (BOOL)isActive { return sActive; }
- (void)deactivate { sActive = NO; }
- (void)hide:(id)s { }
- (void)unhide:(id)s { }
- (void)terminate:(id)sender
{
    id d = [self delegate];
    if ([d respondsToSelector:@selector(applicationShouldTerminate:)]) { NSInteger r = (NSInteger)[d performSelector:@selector(applicationShouldTerminate:) withObject:self]; if (r == 0) return; }
    if ([d respondsToSelector:@selector(applicationWillTerminate:)]) [d performSelector:@selector(applicationWillTerminate:) withObject:nil];
    exit(0);
}
- (void)stop:(id)sender { CFRunLoopStop(CFRunLoopGetMain()); }
@end

/* ---- pop-up menu: a borderless window with the items; the click on an item (or Escape / losing the focus) ends the modal loop ---- */
@interface OpenMenuView : NSView { @public NSArray *items; NSInteger hot, sel; } @end
@implementation OpenMenuView
- (BOOL)acceptsFirstResponder { return YES; }
- (void)drawRect:(CGRect)dirty
{
    CGContextRef cg = [[NSGraphicsContext currentContext] CGContext]; if (!cg) return;
    CGRect b = [self bounds];
    CGPathRef p = CGPathCreateWithRoundedRect(CGRectInset(b, 0.5, 0.5), 10, 10, NULL);
    CGContextSetRGBFillColor(cg, 44 / 255.0, 44 / 255.0, 46 / 255.0, 1); CGContextAddPath(cg, p); CGContextFillPath(cg);
    CGContextSetRGBStrokeColor(cg, 1, 1, 1, 0.14); CGContextAddPath(cg, p); CGContextStrokePath(cg); CGPathRelease(p);
    for (NSUInteger i = 0; i < [items count]; i++) {
        CGRect r = CGRectMake(5, b.size.height - 5 - (i + 1) * 22, b.size.width - 10, 22);		/* y up: the first item is at the top */
        if ((NSInteger)i == hot) { CGPathRef hp = CGPathCreateWithRoundedRect(r, 5, 5, NULL); CGContextSetRGBFillColor(cg, 0, 122 / 255.0, 1, 1); CGContextAddPath(cg, hp); CGContextFillPath(cg); CGPathRelease(hp); }
        NSDictionary *at = @{ NSFontAttributeName: [NSFont systemFontOfSize:13], NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:1 alpha:0.9] };
        NSString *t = [((NSInteger)i == sel ? @"✓ " : @"   ") stringByAppendingString:items[i]];
        CGSize ts = [t sizeWithAttributes:at];
        [t drawAtPoint:CGPointMake(r.origin.x + 8, r.origin.y + (r.size.height - ts.height) / 2) withAttributes:at];
    }
}
- (NSInteger)_idx:(NSEvent *)e { CGPoint p = [e locationInWindow]; NSInteger i = (NSInteger)(([self frame].size.height - 5 - p.y) / 22); return i >= 0 && i < (NSInteger)[items count] ? i : -1; }
- (void)mouseMoved:(NSEvent *)e { NSInteger i = [self _idx:e]; if (i != hot) { hot = i; [self display]; } }
- (void)mouseDown:(NSEvent *)e { NSInteger i = [self _idx:e]; if (i >= 0) [NSApp stopModalWithCode:1000 + i]; }
- (void)keyDown:(NSEvent *)e { if ([e keyCode] == 53) [NSApp stopModalWithCode:-1000]; }
- (void)_openFocusOut { [NSApp stopModalWithCode:-1000]; }
@end

NSInteger OpenPopupMenu(NSView *anchor, NSArray *titles, NSInteger sel)
{
    NSWindow *aw = [anchor window]; if (!aw) { NSView *r = anchor; while ([r superview]) r = [r superview]; aw = nil; }
    CGRect wf = [aw _openFrame]; CGFloat x = wf.origin.x, y = wf.origin.y;
    for (NSView *v = anchor; v && v != [aw contentView]; v = [v superview]) { x += [v frame].origin.x; y += [v frame].origin.y; }
    CGFloat W = MAX([anchor frame].size.width, 140), H = [titles count] * 22 + 10;
    NSWindow *w = [[NSWindow alloc] initWithContentRect:CGRectMake(x, y - H + 4, W, H) styleMask:0 backing:NSBackingStoreBuffered defer:NO];
    OpenMenuView *mv = [[OpenMenuView alloc] initWithFrame:CGRectMake(0, 0, W, H)]; mv->items = titles; mv->hot = -1; mv->sel = sel;
    [w setContentView:mv];
    [w makeFirstResponder:mv];
    NSInteger r = [NSApp runModalForWindow:w];
    return r >= 1000 ? r - 1000 : -1;
}
