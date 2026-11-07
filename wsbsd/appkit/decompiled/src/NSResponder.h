/*
 * NSResponder.h — 1:1 reimplementation of AppKit's NSResponder.
 *
 * Reconstructed from the real AppKit.framework on macOS 27 (build 26A5416b,
 * arm64e), read out of the dyld shared cache with ipsw. Class shape taken from
 * `ipsw dyld macho ... --objc` (see ../reference/NSResponder.h); method logic
 * transcribed from the disassembly under ../evidence/ (addresses cited in the
 * .m). Not copied from Apple binaries; rewritten from the decompile.
 *
 * Scope of this first pass: the responder chain, first-responder defaults,
 * default event routing, command dispatch and the service/requestor forwarding
 * that View/Window/Application inherit. Accessibility, Touch Bar, state
 * restoration, user activity and the services machinery are separate passes.
 */
#import <Foundation/Foundation.h>

@class NSEvent, NSMenu, NSUndoManager, NSError, NSWindow, NSTouchBar;
@class NSKeyValueDependencyInfo;

typedef NSString *NSPasteboardType;

NS_ASSUME_NONNULL_BEGIN

@interface NSResponder : NSObject <NSCoding>

@property (nullable, assign) NSResponder *nextResponder;

- (BOOL)tryToPerform:(SEL)anAction with:(nullable id)anObject;
- (nullable id)validRequestorForSendType:(nullable NSPasteboardType)sendType
                              returnType:(nullable NSPasteboardType)returnType;

- (BOOL)acceptsFirstResponder;
- (BOOL)becomeFirstResponder;
- (BOOL)resignFirstResponder;

- (void)mouseDown:(NSEvent *)event;
- (void)mouseDragged:(NSEvent *)event;
- (void)mouseUp:(NSEvent *)event;
- (void)mouseMoved:(NSEvent *)event;
- (void)rightMouseDown:(NSEvent *)event;
- (void)rightMouseDragged:(NSEvent *)event;
- (void)rightMouseUp:(NSEvent *)event;
- (void)otherMouseDown:(NSEvent *)event;
- (void)otherMouseDragged:(NSEvent *)event;
- (void)otherMouseUp:(NSEvent *)event;
- (void)scrollWheel:(NSEvent *)event;
- (void)keyDown:(NSEvent *)event;
- (void)keyUp:(NSEvent *)event;
- (void)flagsChanged:(NSEvent *)event;

- (void)interpretKeyEvents:(NSArray<NSEvent *> *)eventArray;
- (void)doCommandBySelector:(SEL)aSelector;

- (BOOL)performKeyEquivalent:(NSEvent *)event;
- (BOOL)performMnemonic:(NSString *)string;

- (void)noResponderFor:(SEL)eventSelector;
- (nullable id)supplementalTargetForAction:(SEL)action sender:(nullable id)sender;

- (nullable NSMenu *)menu;
- (void)setMenu:(nullable NSMenu *)menu;

/* AppKit-internal, used by NSView/NSWindow event routing. */
- (nullable NSResponder *)_nextResponderForEvent:(NSEvent *)event;
- (nullable NSResponder *)_firstResponderForEvent:(NSEvent *)event;

@end

NS_ASSUME_NONNULL_END
