/* test_nsnib.m — behaviour checks for NSNib core */
#import "../src/NSNib.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

@interface NSNib (TestInternals)
- (NSData *)_data;
- (NSBundle *)_bundle;
- (NSString *)_path;
@end

int main(void) {
    @autoreleasepool {
        /* from data: keeps the archive bytes, defaults bundle to main */
        NSData *d = [@"NIBARCHIVE" dataUsingEncoding:NSUTF8StringEncoding];
        NSNib *n = [[NSNib alloc] initWithNibData:d bundle:nil];
        CHECK(n != nil, "initWithNibData: returns an object");
        CHECK([[n _data] isEqualToData:d], "data retained");
        CHECK([n _bundle] == [NSBundle mainBundle], "nil bundle -> main bundle");

        /* missing named nib raises NSInternalInconsistencyException (1:1) */
        BOOL raised = NO;
        @try {
            (void)[[NSNib alloc] initWithNibNamed:@"ThisNibDoesNotExist" bundle:[NSBundle mainBundle]];
        } @catch (NSException *e) {
            raised = [e.name isEqual:NSInternalInconsistencyException];
        }
        CHECK(raised, "missing named nib raises NSInternalInconsistencyException");

        /* explicit bundle is honoured on the data path */
        NSNib *nb = [[NSNib alloc] initWithNibData:d bundle:[NSBundle mainBundle]];
        CHECK([nb _bundle] == [NSBundle mainBundle], "explicit bundle honoured");

        /* instantiate: stage2 — returns NO, empty top-level objects, no crash */
        NSArray *tlo = nil;
        BOOL ok = [n instantiateWithOwner:nil topLevelObjects:&tlo];
        CHECK(!ok && tlo != nil && tlo.count == 0, "instantiate stage2: NO + empty topLevelObjects");

        /* inheritsDecodeTimeBundlePath flag round-trips */
        CHECK(![n inheritsDecodeTimeBundlePath], "inheritsDecodeTimeBundlePath default NO");
        [n setInheritsDecodeTimeBundlePath:YES];
        CHECK([n inheritsDecodeTimeBundlePath], "inheritsDecodeTimeBundlePath set");

        /* initWithContentsOfURL: for a missing file still yields an object (path kept) */
        NSNib *nu = [[NSNib alloc] initWithContentsOfURL:[NSURL fileURLWithPath:@"/tmp/none.nib"]];
        CHECK(nu != nil && [[nu _path] isEqual:@"/tmp/none.nib"], "initWithContentsOfURL keeps path");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
