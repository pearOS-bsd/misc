/*
 * NSSpeechSynthesizer.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSSpeechSynthesizer, the classic text-to-speech synthesizer.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSSpeechSynthesizer_interface.txt. Real storage is an opaque
 * _privateNSSpeechSynthesizerVars blob.
 *
 * This core reproduces the configuration + speaking state machine: voice
 * (defaults to +defaultVoice), rate (default 175 wpm), volume (default 1.0),
 * usesFeedbackWindow, weak delegate; start/stop/pause/continue drive isSpeaking
 * and the -didFinishSpeaking: callback. The actual audio engine, the real voice
 * catalogue (+availableVoices is host-specific, 184 entries on the probe box),
 * phoneme synthesis and the feedback window are TODO(stage2). -_finishSpeaking:
 * models the engine completing so the delegate contract is testable.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSString *NSSpeechSynthesizerVoiceName;

typedef NS_ENUM(NSInteger, NSSpeechBoundary) {
    NSSpeechImmediateBoundary = 0,
    NSSpeechWordBoundary = 1,
    NSSpeechSentenceBoundary = 2,
};

@class NSSpeechSynthesizer;

@protocol NSSpeechSynthesizerDelegate <NSObject>
@optional
- (void)speechSynthesizer:(NSSpeechSynthesizer *)sender didFinishSpeaking:(BOOL)finishedSpeaking;
- (void)speechSynthesizer:(NSSpeechSynthesizer *)sender willSpeakWord:(NSRange)characterRange ofString:(NSString *)string;
- (void)speechSynthesizer:(NSSpeechSynthesizer *)sender willSpeakPhoneme:(short)phonemeOpcode;
@end

@interface NSSpeechSynthesizer : NSObject

- (nullable instancetype)initWithVoice:(nullable NSSpeechSynthesizerVoiceName)voice;

@property (nullable, weak) id<NSSpeechSynthesizerDelegate> delegate;
@property (readonly, getter=isSpeaking) BOOL speaking;
@property float rate;
@property float volume;
@property BOOL usesFeedbackWindow;

- (BOOL)startSpeakingString:(NSString *)string;
- (BOOL)stopSpeaking;
- (void)stopSpeakingAtBoundary:(NSSpeechBoundary)boundary;
- (void)pauseSpeakingAtBoundary:(NSSpeechBoundary)boundary;
- (void)continueSpeaking;

- (nullable NSSpeechSynthesizerVoiceName)voice;
- (BOOL)setVoice:(nullable NSSpeechSynthesizerVoiceName)voice;

@property (readonly, getter=isPaused) BOOL paused;  /* SPI-ish, testable */

+ (NSArray<NSSpeechSynthesizerVoiceName> *)availableVoices;
+ (nullable NSSpeechSynthesizerVoiceName)defaultVoice;
+ (BOOL)isAnyApplicationSpeaking;

/* models the engine finishing a phrase (success or interrupted). */
- (void)_finishSpeaking:(BOOL)finished;

@end

NS_ASSUME_NONNULL_END
