/*
 * NSSpeechRecognizer.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSSpeechRecognizer, the command-grammar speech recognizer.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSSpeechRecognizer_interface.txt. Real storage is an opaque
 * _privateNSSpeechRecognizerVars blob.
 *
 * This core reproduces the configuration model (commands/displayedCommandsTitle,
 * listensInForegroundOnly/blocksOtherRecognizers, weak delegate) and the
 * listening on/off state. Measured defaults: every property nil/NO.
 * TODO(stage2): the actual recognition engine (startListening/stopListening
 * wiring to the speech server and -speechRecognizer:didRecognizeCommand:
 * delegate callbacks). -_processRecognitionResult: models the dispatch so the
 * delegate contract is testable without the engine.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class NSSpeechRecognizer;

@protocol NSSpeechRecognizerDelegate <NSObject>
@optional
- (void)speechRecognizer:(NSSpeechRecognizer *)sender didRecognizeCommand:(NSString *)command;
@end

@interface NSSpeechRecognizer : NSObject

@property (nullable, weak) id<NSSpeechRecognizerDelegate> delegate;
@property (nullable, copy) NSArray<NSString *> *commands;
@property (nullable, copy) NSString *displayedCommandsTitle;
@property BOOL listensInForegroundOnly;
@property BOOL blocksOtherRecognizers;

- (void)startListening;
- (void)stopListening;

/* readonly in this core: whether -startListening is in effect (SPI-ish, testable). */
@property (readonly, getter=isListening) BOOL listening;

/* models the engine callback path so the delegate contract is testable. */
- (void)_processRecognitionResult:(NSString *)command;

@end

NS_ASSUME_NONNULL_END
