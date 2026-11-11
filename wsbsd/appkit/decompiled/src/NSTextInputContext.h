/*
 * NSTextInputContext.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSTextInputContext (the object a text view uses to talk to the text input
 * management system).
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSTextInputContext_interface.txt. The real class is enormous —
 * nearly all of it is the TSM/RTI input-method engine (handleEvent:, marked
 * text, candidates, the touch-bar IM controllers, per-character geometry
 * callbacks). All of that is TODO(stage2).
 *
 * Measured on this Mac: initWithClient: stores the client (weak); acceptsGlyphInfo
 * defaults to NO; allowedInputSourceLocales is nil; +currentInputContext is nil
 * with no key window, and -activate did not flip it in a standalone tool because
 * the active context is gated by TSM and the app's key-window first responder.
 * keyboardInputSources / selectedKeyboardInputSource come from the live TIS
 * input-source registry.
 *
 * This core reproduces the client/value model plus a documented
 * +currentInputContext / activate / deactivate contract (the TSM gating is
 * stage2). The input-source registry and the input-method engine are stage2.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol NSTextInputClient;

@interface NSTextInputContext : NSObject

@property (class, readonly, nullable, strong) NSTextInputContext *currentInputContext;

- (instancetype)initWithClient:(id<NSTextInputClient>)client NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property (readonly, weak) id<NSTextInputClient> client;
@property BOOL acceptsGlyphInfo;                                   /* default NO */
@property (nullable, copy) NSArray<NSString *> *allowedInputSourceLocales;

@property (readonly, copy) NSArray<NSString *> *keyboardInputSources;   /* stage2: TIS */
@property (nullable, copy) NSString *selectedKeyboardInputSource;       /* stage2: TIS */

- (void)activate;
- (void)deactivate;

- (BOOL)handleEvent:(id)event;                /* stage2: TSM/RTI engine */
- (void)discardMarkedText;                    /* stage2 */
- (void)invalidateCharacterCoordinates;       /* stage2 */

@end

NS_ASSUME_NONNULL_END
