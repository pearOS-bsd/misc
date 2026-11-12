/* test_nstextcheckingcontroller.m */
#import "../src/NSTextCheckingController.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        id client = [NSObject new];
        NSTextCheckingController *t = [[NSTextCheckingController alloc] initWithClient:client];

        CHECK(t.client == client, "client stored (weak)");
        CHECK(t.spellCheckerDocumentTag == 1, "first controller gets document tag 1 (measured)");

        /* a second controller gets a distinct, higher tag */
        NSTextCheckingController *t2 = [[NSTextCheckingController alloc] initWithClient:[NSObject new]];
        CHECK(t2.spellCheckerDocumentTag == 2, "second controller gets tag 2");

        /* validAnnotations: the measured fixed set */
        NSArray *va = t.validAnnotations;
        CHECK(va.count == 32, "validAnnotations has the measured 32 keys");
        CHECK([va containsObject:@"NSSpellingState"], "includes NSSpellingState");
        CHECK([va containsObject:@"NSLink"], "includes NSLink");
        CHECK([va containsObject:@"NSTextChecked"], "includes NSTextChecked");

        /* tag settable */
        t.spellCheckerDocumentTag = 99;
        CHECK(t.spellCheckerDocumentTag == 99, "spellCheckerDocumentTag set");

        /* lifecycle hooks are safe no-ops (stage2) */
        [t didChangeTextInRange:NSMakeRange(0,1)];
        [t didChangeText];
        [t didChangeSelectedRange];
        [t invalidate];
        CHECK(1, "lifecycle hooks do not crash");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
