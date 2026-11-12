/*
 * NSTextCheckingController.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSTextCheckingController, which bridges a custom NSTextInputClient-style view
 * to the system spell/grammar/substitution checking.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSTextCheckingController_interface.txt (the live class is huge —
 * ~230 methods, almost all private _*). Real ivars include _client,
 * _spellCheckerDocumentTag and extensive checking-state bitfields.
 *
 * This core reproduces the construction + identity surface: initWithClient:
 * (weak client), spellCheckerDocumentTag (a unique tag, 1 for the first
 * controller — measured), and validAnnotations (the fixed ~33-key annotation
 * set — measured). The actual checking pipeline (checkSpelling:, didChangeText,
 * menuAtIndex:…, candidate handling, correction indicators) drives NSSpellChecker
 * and the client and is TODO(stage2); -didChangeText / -didChangeSelectedRange
 * are provided as safe no-op hooks.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSTextCheckingController : NSObject

- (instancetype)initWithClient:(id)client;

@property (readonly, weak) id client;
@property NSInteger spellCheckerDocumentTag;
@property (readonly, copy) NSArray<NSString *> *validAnnotations;

- (void)didChangeTextInRange:(NSRange)range;
- (void)didChangeText;
- (void)didChangeSelectedRange;
- (void)invalidate;

@end

NS_ASSUME_NONNULL_END
