/*
 * NSApplication.h — 1:1 reimplementation of AppKit's NSApplication (core).
 *
 * Shape from ../reference/NSApplication.h; logic from ../evidence/app. Covers the
 * shared singleton, delegate (weak), main menu, running flag, the window list,
 * and action dispatch (sendAction:to:from: / targetForAction:to:from:) — the
 * path NSControl uses to fire its action. Staged (need the run loop / server /
 * key-window tracking): run/stop, the full first-responder targeting chain,
 * event delivery. TODO(stage2) in the .m.
 */
#import "NSResponder.h"

@class NSMenu, NSWindow;

NS_ASSUME_NONNULL_BEGIN

@interface NSApplication : NSResponder

@property (class, readonly, strong) NSApplication *sharedApplication;

@property (nullable, weak) id delegate;
@property (nullable, strong) NSMenu *mainMenu;
@property (readonly, getter=isRunning) BOOL running;
@property (readonly, copy) NSArray<NSWindow *> *windows;

- (BOOL)sendAction:(SEL)action to:(nullable id)target from:(nullable id)sender;
- (nullable id)targetForAction:(SEL)action to:(nullable id)target from:(nullable id)sender;

@end

/* The process-wide application instance (set by +sharedApplication). */
extern __weak NSApplication *NSApp;

NS_ASSUME_NONNULL_END
