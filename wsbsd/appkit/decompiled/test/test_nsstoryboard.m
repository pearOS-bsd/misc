/* test_nsstoryboard.m — behaviour checks for NSStoryboard core */
#import "../src/NSStoryboard.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        /* missing storyboard raises NSInvalidArgumentException (measured) */
        BOOL raised = NO;
        @try {
            (void)[NSStoryboard storyboardWithName:@"NopeStoryboard" bundle:[NSBundle mainBundle]];
        } @catch (NSException *e) {
            raised = [e.name isEqual:NSInvalidArgumentException];
        }
        CHECK(raised, "missing storyboard raises NSInvalidArgumentException");

        /* map-based core: identity + lookups */
        NSStoryboard *s = [[NSStoryboard alloc] initWithBundle:[NSBundle mainBundle]
                                            storyboardFileName:@"Main"
                                        identifierToNibNameMap:@{@"login": @"LoginScene", @"home": @"HomeScene"}
                 identifierToExternalStoryboardReferenceMap:@{}
                                           identifierToUUIDMap:@{@"login": @"UUID-1", @"home": @"UUID-2"}
                               designatedEntryPointIdentifier:@"home"
                                                      mainMenu:nil];
        CHECK([s.name isEqual:@"Main"], "name is the storyboard file name");
        CHECK(s.containingBundle == [NSBundle mainBundle], "containingBundle stored");

        CHECK([[s nibForControllerWithIdentifier:@"login"] isEqual:@"LoginScene"], "nib for identifier");
        CHECK([s nibForControllerWithIdentifier:@"missing"] == nil, "unknown identifier -> nil nib");
        CHECK([s containsNibNamed:@"HomeScene"], "containsNibNamed finds a mapped nib");
        CHECK(![s containsNibNamed:@"Ghost"], "containsNibNamed NO for unmapped nib");
        CHECK([[s uniqueIDForControllerIdentifier:@"home"] isEqual:@"UUID-2"], "uniqueID for identifier");

        /* instantiateInitialController stage2 -> nil (no decode) */
        CHECK([s instantiateInitialController] == nil, "instantiateInitialController stage2 nil");

        /* unknown identifier instantiation raises */
        BOOL raised2 = NO;
        @try { (void)[s instantiateControllerWithIdentifier:@"ghost"]; }
        @catch (NSException *e) { raised2 = [e.name isEqual:NSInvalidArgumentException]; }
        CHECK(raised2, "unknown controller identifier raises");

        /* known identifier: no raise (decode itself is stage2 -> nil) */
        BOOL raised3 = NO; id known = nil;
        @try { known = [s instantiateControllerWithIdentifier:@"login"]; }
        @catch (NSException *e) { raised3 = YES; }
        CHECK(!raised3 && known == nil, "known identifier does not raise (decode stage2)");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
