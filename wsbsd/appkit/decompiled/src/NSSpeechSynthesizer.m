/*
 * NSSpeechSynthesizer.m — behavioral-1:1 core. See the header.
 */

#import "NSSpeechSynthesizer.h"

/* measured default voice identifier on the probe host. */
static NSString *const kDefaultVoice = @"com.apple.voice.compact.en-US.Samantha";

/* process-wide "is any synthesizer speaking" flag, mirroring the real
   +isAnyApplicationSpeaking which is really cross-process (stage2). */
static NSInteger gSpeakingCount = 0;

@implementation NSSpeechSynthesizer {
    __weak id<NSSpeechSynthesizerDelegate> _delegate;
    NSSpeechSynthesizerVoiceName _voice;
    float _rate;
    float _volume;
    BOOL _usesFeedbackWindow;
    BOOL _speaking;
    BOOL _paused;
}

- (instancetype)init { return [self initWithVoice:nil]; }

- (instancetype)initWithVoice:(NSSpeechSynthesizerVoiceName)voice
{
    self = [super init];
    if (self) {
        _voice = [voice copy] ?: [[self class] defaultVoice];
        _rate = 175.0f;   /* measured words-per-minute default */
        _volume = 1.0f;   /* measured */
    }
    return self;
}

- (id<NSSpeechSynthesizerDelegate>)delegate { return _delegate; }
- (void)setDelegate:(id<NSSpeechSynthesizerDelegate>)d { _delegate = d; }
- (BOOL)isSpeaking { return _speaking; }
- (BOOL)isPaused { return _paused; }
- (float)rate { return _rate; }
- (void)setRate:(float)r { _rate = r; }
- (float)volume { return _volume; }
- (void)setVolume:(float)v { _volume = v; }
- (BOOL)usesFeedbackWindow { return _usesFeedbackWindow; }
- (void)setUsesFeedbackWindow:(BOOL)v { _usesFeedbackWindow = v; }

- (NSSpeechSynthesizerVoiceName)voice { return _voice; }
- (BOOL)setVoice:(NSSpeechSynthesizerVoiceName)voice
{
    /* Changing voice while speaking is rejected by the real class. */
    if (_speaking) return NO;
    NSSpeechSynthesizerVoiceName v = voice ?: [[self class] defaultVoice];
    if (![[[self class] availableVoices] containsObject:v]) return NO;
    _voice = [v copy];
    return YES;
}

- (BOOL)startSpeakingString:(NSString *)string
{
    if (string == nil) return NO;
    if (_speaking && !_paused) return NO;   /* already speaking */
    if (!_speaking) { _speaking = YES; gSpeakingCount++; }
    _paused = NO;
    /* TODO(stage2): hand the string to the speech server; completion arrives
       asynchronously and is modelled by -_finishSpeaking:. */
    return YES;
}

- (BOOL)stopSpeaking { [self stopSpeakingAtBoundary:NSSpeechImmediateBoundary]; return YES; }

- (void)stopSpeakingAtBoundary:(NSSpeechBoundary)boundary
{
    (void)boundary;  /* stage2: honour word/sentence boundary before stopping */
    if (!_speaking) return;
    [self _finishSpeaking:NO];   /* interrupted */
}

- (void)pauseSpeakingAtBoundary:(NSSpeechBoundary)boundary
{
    (void)boundary;
    if (_speaking) _paused = YES;
}

- (void)continueSpeaking { if (_speaking) _paused = NO; }

- (void)_finishSpeaking:(BOOL)finished
{
    if (!_speaking) return;
    _speaking = NO;
    _paused = NO;
    if (gSpeakingCount > 0) gSpeakingCount--;
    if ([_delegate respondsToSelector:@selector(speechSynthesizer:didFinishSpeaking:)]) {
        [_delegate speechSynthesizer:self didFinishSpeaking:finished];
    }
}

#pragma mark - class

+ (NSArray<NSSpeechSynthesizerVoiceName> *)availableVoices
{
    /* stage2: the real catalogue (184 host-specific entries) comes from the
       speech server. We expose at least the default so -setVoice: is testable. */
    return @[kDefaultVoice];
}

+ (NSSpeechSynthesizerVoiceName)defaultVoice { return kDefaultVoice; }
+ (BOOL)isAnyApplicationSpeaking { return gSpeakingCount > 0; }

@end
