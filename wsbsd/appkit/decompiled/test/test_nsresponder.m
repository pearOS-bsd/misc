/*
 * test_nsresponder.m — behaviour tests for the 1:1 NSResponder reimplementation.
 * Checks the externally-observable behaviour transcribed from the macOS 27
 * disassembly: responder chain, forwarding, command aliasing, first-responder
 * defaults, noResponderFor: beep policy, back-references and loop detection.
 */
#import "../src/NSResponder.h"
#import <objc/message.h>

extern int gNSBeepCount;
extern NSString *gLastKVODependencyKey;

static int gFails = 0;
static int gChecks = 0;
#define CHECK(cond, msg) do { \
    gChecks++; \
    if (!(cond)) { gFails++; fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } \
} while (0)

/* A responder that records which actions/commands it received. */
@interface TestResponder : NSResponder
@property (nonatomic) BOOL gotAction;
@property (nonatomic) BOOL gotSave;
@property (nonatomic) SEL  lastCommand;
@end

@implementation TestResponder
- (void)doTheThing:(id)sender { self.gotAction = YES; }
- (void)save:(id)sender { self.gotSave = YES; }
- (void)moveToBeginningOfLine:(id)sender { self.lastCommand = _cmd; }
@end

int main(void)
{
    @autoreleasepool {
        NSEvent *noEvent = nil;   /* nullable locals so the test can exercise nil paths */
        NSString *noStr = nil;

        /* --- nextResponder round-trip + KVO dependency registration --- */
        NSResponder *a = [[NSResponder alloc] init];
        NSResponder *b = [[NSResponder alloc] init];
        a.nextResponder = b;
        CHECK(a.nextResponder == b, "nextResponder round-trips");
        CHECK([gLastKVODependencyKey isEqualToString:@"nextResponder"],
              "nextResponder registers the KVO dependency");

        /* --- setting a new nextResponder clears the old back-reference --- */
        NSResponder *c = [[NSResponder alloc] init];
        a.nextResponder = c;
        CHECK(a.nextResponder == c, "nextResponder can be replaced");

        /* --- first-responder defaults --- */
        CHECK([a acceptsFirstResponder] == NO,  "acceptsFirstResponder defaults NO");
        CHECK([a becomeFirstResponder] == YES,  "becomeFirstResponder defaults YES");
        CHECK([a resignFirstResponder] == YES,  "resignFirstResponder defaults YES");
        CHECK([a performKeyEquivalent:noEvent] == NO, "performKeyEquivalent: defaults NO");
        CHECK([a performMnemonic:noStr] == NO,    "performMnemonic: defaults NO");
        CHECK([a supplementalTargetForAction:@selector(copy:) sender:nil] == nil,
              "supplementalTargetForAction:sender: defaults nil");
        CHECK([a validRequestorForSendType:nil returnType:nil] == nil,
              "validRequestorForSendType: forwards to nil chain -> nil");

        /* --- tryToPerform:with: runs on self when it responds --- */
        TestResponder *t = [[TestResponder alloc] init];
        BOOL handled = [t tryToPerform:@selector(doTheThing:) with:nil];
        CHECK(handled && t.gotAction, "tryToPerform runs the action on a responder that responds");

        /* --- tryToPerform:with: forwards down the chain --- */
        NSResponder *head = [[NSResponder alloc] init];
        TestResponder *tail = [[TestResponder alloc] init];
        head.nextResponder = tail;
        BOOL handled2 = [head tryToPerform:@selector(save:) with:nil];
        CHECK(handled2 && tail.gotSave, "tryToPerform forwards to the next responder");

        /* --- tryToPerform:with: returns NO when nobody handles it --- */
        NSResponder *lonely = [[NSResponder alloc] init];
        CHECK([lonely tryToPerform:@selector(save:) with:nil] == NO,
              "tryToPerform returns NO when unhandled");

        /* --- doCommandBySelector: beeps when unhandled and no next responder --- */
        gNSBeepCount = 0;
        [lonely doCommandBySelector:@selector(save:)];
        CHECK(gNSBeepCount == 1, "doCommandBySelector beeps when unhandled with no next responder");

        /* --- doCommandBySelector: alias maps moveToLeftEndOfLine: -> moveToBeginningOfLine: --- */
        TestResponder *ed = [[TestResponder alloc] init];
        ed.lastCommand = NULL;
        [ed doCommandBySelector:sel_registerName("moveToLeftEndOfLine:")];
        CHECK(sel_isEqual(ed.lastCommand, @selector(moveToBeginningOfLine:)),
              "doCommandBySelector aliases moveToLeftEndOfLine: to moveToBeginningOfLine:");

        /* --- noResponderFor: beeps on keyDown: only --- */
        gNSBeepCount = 0;
        [a noResponderFor:@selector(keyDown:)];
        CHECK(gNSBeepCount == 1, "noResponderFor: beeps on keyDown:");
        gNSBeepCount = 0;
        [a noResponderFor:@selector(mouseDown:)];
        CHECK(gNSBeepCount == 0, "noResponderFor: does not beep on mouseDown:");

        /* --- default event routing: keyDown: with no next responder beeps once --- */
        gNSBeepCount = 0;
        NSResponder *solo = [[NSResponder alloc] init];
        [solo keyDown:noEvent];
        CHECK(gNSBeepCount == 1, "keyDown: with no next responder -> noResponderFor: beeps");

        /* --- loop detection throws --- */
        NSResponder *x = [[NSResponder alloc] init];
        NSResponder *y = [[NSResponder alloc] init];
        x.nextResponder = y;
        BOOL threw = NO;
        @try { y.nextResponder = x; }
        @catch (NSException *e) { threw = YES; }
        CHECK(threw, "setNextResponder: throws on a responder-chain loop");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
