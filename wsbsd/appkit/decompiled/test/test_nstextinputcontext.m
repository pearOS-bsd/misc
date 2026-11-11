/* test_nstextinputcontext.m — behaviour checks for NSTextInputContext public core */
#import "../src/NSTextInputContext.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

@protocol NSTextInputClient <NSObject> @end
@interface Client : NSObject <NSTextInputClient> @end
@implementation Client @end

int main(void) {
    @autoreleasepool {
        Client *c = [Client new];
        NSTextInputContext *ic = [[NSTextInputContext alloc] initWithClient:(id)c];
        CHECK(ic.client == (id)c, "client stored (weak)");
        CHECK(!ic.acceptsGlyphInfo, "acceptsGlyphInfo default NO");
        CHECK(ic.allowedInputSourceLocales == nil, "allowedInputSourceLocales default nil");

        /* acceptsGlyphInfo + allowedInputSourceLocales round-trip */
        ic.acceptsGlyphInfo = YES;
        CHECK(ic.acceptsGlyphInfo, "acceptsGlyphInfo set");
        NSMutableArray *loc = [@[@"en"] mutableCopy];
        ic.allowedInputSourceLocales = loc;
        [loc addObject:@"fr"];
        CHECK(ic.allowedInputSourceLocales.count == 1, "allowedInputSourceLocales snapshot-copied");

        /* currentInputContext / activate / deactivate contract */
        CHECK([NSTextInputContext currentInputContext] == nil, "no current context initially");
        [ic activate];
        CHECK([NSTextInputContext currentInputContext] == ic, "activate sets currentInputContext");
        [ic deactivate];
        CHECK([NSTextInputContext currentInputContext] == nil, "deactivate clears currentInputContext");

        /* deactivate of a non-current context does not clear another's */
        NSTextInputContext *ic2 = [[NSTextInputContext alloc] initWithClient:(id)c];
        [ic activate];
        [ic2 deactivate];   /* ic2 is not current */
        CHECK([NSTextInputContext currentInputContext] == ic, "deactivate only clears when current");
        [ic deactivate];

        /* stage2 members are safe */
        CHECK(ic.keyboardInputSources.count == 0, "keyboardInputSources stage2 empty");
        CHECK(ic.selectedKeyboardInputSource == nil, "selectedKeyboardInputSource stage2 nil");
        ic.selectedKeyboardInputSource = @"com.apple.keylayout.US";
        CHECK([ic.selectedKeyboardInputSource isEqual:@"com.apple.keylayout.US"], "selectedKeyboardInputSource stored");
        CHECK(![ic handleEvent:[NSObject new]], "handleEvent stage2 returns NO");
        [ic discardMarkedText];
        [ic invalidateCharacterCoordinates];
        CHECK(1, "discardMarkedText/invalidateCharacterCoordinates safe no-ops");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
