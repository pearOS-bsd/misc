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
#import "NSMenu.h"
#import "NSMenuItem.h"

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
extern NSMenuItem *PopupMenu(NSMenu *m, CGFloat x, CGFloat y);
NSInteger OpenPopupMenu(NSView *anchor, NSArray *titles, NSInteger sel)
{
    NSWindow *aw = [anchor window]; if (!aw) return -1;
    CGRect wf = [aw _openFrame]; CGFloat x = wf.origin.x, y = wf.origin.y;
    for (NSView *v = anchor; v && v != [aw contentView]; v = [v superview]) { x += [v frame].origin.x; y += [v frame].origin.y; }
    NSMenu *m = [[NSMenu alloc] initWithTitle:@""]; NSInteger i = 0;
    for (NSString *t in titles) { NSMenuItem *it = [[NSMenuItem alloc] initWithTitle:t action:NULL keyEquivalent:@""]; [it setState:i == sel ? 1 : 0]; [m addItem:it]; i++; }
    NSMenuItem *chosen = PopupMenu(m, x, y + 4);
    return chosen ? [[m itemArray] indexOfObject:chosen] : -1;
}

/* ---- entry point of every Cocoa program, and the fill/frame functions with an operation ---- */
@interface NSBundle (OpenNibDecl) - (BOOL)loadNibNamed:(NSString *)n owner:(id)o topLevelObjects:(NSArray **)t; @end
int NSApplicationMain(int argc, const char *argv[])
{
    @autoreleasepool {
        NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
        Class pc = NSClassFromString(info[@"NSPrincipalClass"] ?: @"NSApplication") ?: [NSApplication class];
        NSApplication *app = [pc sharedApplication];
        NSString *nib = info[@"NSMainNibFile"];
        if ([nib length]) { BOOL ok = [[NSBundle mainBundle] loadNibNamed:nib owner:app topLevelObjects:nil]; fprintf(stderr, "open: main nib %s: %s\n", [nib UTF8String], ok ? "loaded" : "NOT loaded (no nib loader yet)"); }
        [app run];
    }
    return 0;
}
void NSRectFillUsingOperation(CGRect r, NSInteger op) { NSRectFill(r); }
void NSFrameRectWithWidthUsingOperation(CGRect r, CGFloat w, NSInteger op)
{
    CGContextRef cg = [[NSGraphicsContext currentContext] CGContext]; if (!cg) return;
    CGContextFillRect(cg, CGRectMake(r.origin.x, r.origin.y, r.size.width, w)); CGContextFillRect(cg, CGRectMake(r.origin.x, r.origin.y + r.size.height - w, r.size.width, w));
    CGContextFillRect(cg, CGRectMake(r.origin.x, r.origin.y, w, r.size.height)); CGContextFillRect(cg, CGRectMake(r.origin.x + r.size.width - w, r.origin.y, w, r.size.height));
}
/* Swift overlay: CGRect.fill(using:) / CGRect.frame(withWidth:using:) — the arguments come in registers like in C (x y w h in xmm0-3, the operation in rdi) */
void open_swift_fill(double x, double y, double w, double h, long op) __asm__("_$sSo6CGRectV6AppKitE4fill5usingySo22NSCompositingOperationV_tF");
void open_swift_fill(double x, double y, double w, double h, long op) { NSRectFill(CGRectMake(x, y, w, h)); }
void open_swift_frame(double x, double y, double w, double h, double fw, long op) __asm__("_$sSo6CGRectV6AppKitE5frame9withWidth5usingy12CoreGraphics7CGFloatV_So22NSCompositingOperationVtF");
void open_swift_frame(double x, double y, double w, double h, double fw, long op) { NSFrameRectWithWidthUsingOperation(CGRectMake(x, y, w, h), fw, op); }
