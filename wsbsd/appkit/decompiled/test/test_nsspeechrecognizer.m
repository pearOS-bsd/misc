/* test_nsspeechrecognizer.m */
#import "../src/NSSpeechRecognizer.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

@interface Spy : NSObject <NSSpeechRecognizerDelegate>
@property (copy) NSString *last;
@property NSInteger count;
@end
@implementation Spy
- (void)speechRecognizer:(NSSpeechRecognizer *)s didRecognizeCommand:(NSString *)c { self.last = c; self.count++; }
@end

int main(void) {
    @autoreleasepool {
        NSSpeechRecognizer *r = [[NSSpeechRecognizer alloc] init];
        /* measured defaults */
        CHECK(r.commands == nil && r.displayedCommandsTitle == nil, "commands/title nil default");
        CHECK(!r.listensInForegroundOnly && !r.blocksOtherRecognizers, "flags NO default");
        CHECK(r.delegate == nil && !r.isListening, "delegate nil, not listening");

        /* setters */
        r.commands = @[@"Open", @"Close"];
        CHECK(r.commands.count == 2, "commands set");
        r.displayedCommandsTitle = @"Commands";
        CHECK([r.displayedCommandsTitle isEqual:@"Commands"], "title set");
        r.listensInForegroundOnly = YES; r.blocksOtherRecognizers = YES;
        CHECK(r.listensInForegroundOnly && r.blocksOtherRecognizers, "flags set");

        Spy *spy = [Spy new];
        r.delegate = spy;
        CHECK(r.delegate == spy, "delegate set");

        /* not listening -> result ignored */
        [r _processRecognitionResult:@"Open"];
        CHECK(spy.count == 0, "result ignored while not listening");

        [r startListening];
        CHECK(r.isListening, "startListening sets listening");

        /* member command dispatched */
        [r _processRecognitionResult:@"Open"];
        CHECK(spy.count == 1 && [spy.last isEqual:@"Open"], "member command forwarded");

        /* non-member command filtered out */
        [r _processRecognitionResult:@"Nonsense"];
        CHECK(spy.count == 1, "non-member command filtered");

        /* nil command ignored */
        [r _processRecognitionResult:nil];
        CHECK(spy.count == 1, "nil command ignored");

        [r stopListening];
        CHECK(!r.isListening, "stopListening clears listening");
        [r _processRecognitionResult:@"Close"];
        CHECK(spy.count == 1, "after stop, nothing forwarded");

        /* nil commands => any phrase passes the grammar filter */
        r.commands = nil;
        [r startListening];
        [r _processRecognitionResult:@"Anything"];
        CHECK(spy.count == 2 && [spy.last isEqual:@"Anything"], "nil commands accepts any phrase");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
