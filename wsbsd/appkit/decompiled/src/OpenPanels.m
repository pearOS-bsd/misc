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
