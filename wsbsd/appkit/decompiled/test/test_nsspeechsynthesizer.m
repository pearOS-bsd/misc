/* test_nsspeechsynthesizer.m */
#import "../src/NSSpeechSynthesizer.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

@interface Spy : NSObject <NSSpeechSynthesizerDelegate>
@property NSInteger finishes;
@property BOOL lastFinished;
@end
@implementation Spy
- (void)speechSynthesizer:(NSSpeechSynthesizer *)s didFinishSpeaking:(BOOL)f { self.finishes++; self.lastFinished = f; }
@end

int main(void) {
    @autoreleasepool {
        /* measured defaults */
        NSSpeechSynthesizer *s = [[NSSpeechSynthesizer alloc] init];
        CHECK(s.rate == 175.0f, "rate 175 default");
        CHECK(s.volume == 1.0f, "volume 1.0 default");
        CHECK(!s.isSpeaking && !s.isPaused, "not speaking/paused default");
        CHECK(!s.usesFeedbackWindow && s.delegate == nil, "feedback/delegate default");
        CHECK([s.voice isEqual:[NSSpeechSynthesizer defaultVoice]], "voice = defaultVoice");
        CHECK([[NSSpeechSynthesizer defaultVoice] isEqual:@"com.apple.voice.compact.en-US.Samantha"], "default voice id");
        CHECK(![NSSpeechSynthesizer isAnyApplicationSpeaking], "no app speaking at start");

        /* initWithVoice: nil falls back to default */
        NSSpeechSynthesizer *s2 = [[NSSpeechSynthesizer alloc] initWithVoice:nil];
        CHECK([s2.voice isEqual:[NSSpeechSynthesizer defaultVoice]], "initWithVoice:nil -> default");

        Spy *spy = [Spy new];
        s.delegate = spy;

        /* start -> speaking, app-speaking flag set */
        CHECK([s startSpeakingString:@"hello"], "startSpeaking returns YES");
        CHECK(s.isSpeaking && [NSSpeechSynthesizer isAnyApplicationSpeaking], "speaking + global flag");

        /* re-start while speaking rejected */
        CHECK(![s startSpeakingString:@"again"], "re-start rejected while speaking");

        /* setVoice rejected while speaking */
        CHECK(![s setVoice:[NSSpeechSynthesizer defaultVoice]], "setVoice rejected while speaking");

        /* pause / continue */
        [s pauseSpeakingAtBoundary:NSSpeechWordBoundary];
        CHECK(s.isPaused && s.isSpeaking, "paused but still speaking");
        [s continueSpeaking];
        CHECK(!s.isPaused && s.isSpeaking, "continue clears pause");

        /* engine finishes normally */
        [s _finishSpeaking:YES];
        CHECK(!s.isSpeaking && spy.finishes == 1 && spy.lastFinished, "finish fires delegate (finished=YES)");
        CHECK(![NSSpeechSynthesizer isAnyApplicationSpeaking], "global flag cleared after finish");

        /* stop interrupts -> delegate with finished=NO */
        [s startSpeakingString:@"x"];
        CHECK([s stopSpeaking], "stopSpeaking returns YES");
        CHECK(!s.isSpeaking && spy.finishes == 2 && !spy.lastFinished, "stop fires delegate (finished=NO)");

        /* nil string rejected */
        CHECK(![s startSpeakingString:nil], "nil string rejected");

        /* setVoice to a valid (available) voice succeeds when idle */
        CHECK([s setVoice:[NSSpeechSynthesizer defaultVoice]], "setVoice succeeds when idle");
        /* unknown voice rejected */
        CHECK(![s setVoice:@"com.example.bogus"], "unknown voice rejected");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
