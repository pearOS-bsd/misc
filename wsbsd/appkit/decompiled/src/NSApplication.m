/*
 * NSApplication.m — 1:1 reimplementation of AppKit's NSApplication (core).
 * Addresses cite the macOS 27 arm64e disassembly under ../evidence/app.
 *
 * Shipping ivars: _delegate 0xe28 (weak), _running 0xe40 (short >0 => running),
 * _mainMenu 0xe44. The shared instance is cached in __DATA.__bss and published
 * as the global NSApp.
 */
#import "NSApplication.h"
#import "NSMenu.h"
#import <objc/message.h>

__weak NSApplication *NSApp = nil;
static NSApplication *sSharedApplication = nil;   /* strong owner of the singleton */

@implementation NSApplication {
    __weak id _delegate;      /* 0xe28 */
    short _running;           /* 0xe40 */
    NSMenu *_mainMenu;        /* 0xe44 */
    NSMutableArray<NSWindow *> *_windows;
}

/* +[NSApplication sharedApplication]: create once, publish as NSApp. */
+ (NSApplication *)sharedApplication
{
    if (!sSharedApplication) {
        sSharedApplication = [[self alloc] init];
        NSApp = sSharedApplication;
    }
    return sSharedApplication;
}

- (instancetype)init
{
    self = [super init];
    if (self)
        _windows = [NSMutableArray array];
    return self;
}

/* -[NSApplication delegate] 0x184eefb58 (weak) / setDelegate: 0x184ed14f0
 * (the real setter also (de)registers notification observers — stage2). */
- (id)delegate { return _delegate; }
- (void)setDelegate:(id)delegate { _delegate = delegate; }

/* -[NSApplication mainMenu] 0x184ef1b3c / setMainMenu: 0x184eed368 (NSMenu kind). */
- (NSMenu *)mainMenu { return _mainMenu; }
- (void)setMainMenu:(NSMenu *)mainMenu
{
    if (mainMenu && ![mainMenu isKindOfClass:[NSMenu class]])
        return;                        /* binary wraps NSMenuTemplate here — stage2 */
    _mainMenu = mainMenu;
}

/* -[NSApplication isRunning] 0x184f00e74 (_running > 0). */
- (BOOL)isRunning { return _running > 0; }

- (NSArray<NSWindow *> *)windows { return [_windows copy]; }

/* -[NSApplication targetForAction:to:from:]
 * With an explicit target, return it when it (or its supplemental target chain)
 * handles the action. With a nil target, AppKit walks the key window's responder
 * chain, then the main window's, then the app and its delegate; that full walk
 * needs key/main-window tracking, so here we resolve the app + delegate tail.
 * TODO(stage2): the key/main window responder walk. */
- (id)targetForAction:(SEL)action to:(id)target from:(id)sender
{
    if (action == NULL)
        return nil;
    if (target) {
        if ([target respondsToSelector:action])
            return target;
        if ([target respondsToSelector:@selector(supplementalTargetForAction:sender:)]) {
            id supp = [target supplementalTargetForAction:action sender:sender];
            if ([supp respondsToSelector:action])
                return supp;
        }
        return nil;
    }
    if ([self respondsToSelector:action])
        return self;
    if ([_delegate respondsToSelector:action])
        return _delegate;
    return nil;
}

/* -[NSApplication sendAction:to:from:]
 * Resolve the target, then send it the action with the sender. */
- (BOOL)sendAction:(SEL)action to:(id)target from:(id)sender
{
    if (action == NULL)
        return NO;
    id resolved = [self targetForAction:action to:target from:sender];
    if (!resolved)
        return NO;
    ((void (*)(id, SEL, id))objc_msgSend)(resolved, action, sender);
    return YES;
}

@end
