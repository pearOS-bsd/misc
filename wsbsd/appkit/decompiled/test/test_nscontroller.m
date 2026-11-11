/* test_nscontroller.m — behaviour checks for NSController editor-registration core */
#import "../src/NSController.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

/* A mock editor that can refuse a commit and records the calls it got. */
@interface MockEditor : NSObject <NSEditor>
@property BOOL allowCommit;
@property BOOL committed;
@property BOOL discarded;
@end
@implementation MockEditor
- (instancetype)init { if ((self = [super init])) _allowCommit = YES; return self; }
- (void)discardEditing { _discarded = YES; }
- (BOOL)commitEditing { if (_allowCommit) { _committed = YES; return YES; } return NO; }
- (void)commitEditingWithDelegate:(id)d didCommitSelector:(SEL)s contextInfo:(void *)c {}
- (BOOL)commitEditingAndReturnError:(NSError **)e { return [self commitEditing]; }
@end

@interface CommitListener : NSObject
@property BOOL gotCallback;
@property BOOL reportedDidCommit;
@end
@implementation CommitListener
- (void)editor:(id)editor didCommit:(BOOL)didCommit contextInfo:(void *)ctx {
    _gotCallback = YES; _reportedDidCommit = didCommit;
}
@end

int main(void) {
    @autoreleasepool {
        NSController *c = [[NSController alloc] init];
        CHECK(!c.isEditing, "not editing initially");
        CHECK(!c.alwaysPresentsApplicationModalAlerts, "default modal-alerts NO");

        /* begin editing tracks editors + idempotent registration */
        MockEditor *e1 = [MockEditor new];
        [c objectDidBeginEditing:e1];
        CHECK(c.isEditing, "editing after objectDidBeginEditing:");
        [c objectDidBeginEditing:e1];   /* duplicate ignored */

        MockEditor *e2 = [MockEditor new];
        [c objectDidBeginEditing:e2];

        /* end one, still editing; end the other, stops */
        [c objectDidEndEditing:e1];
        CHECK(c.isEditing, "still editing with one editor outstanding");
        [c objectDidEndEditing:e2];
        CHECK(!c.isEditing, "editing ends when last editor ends");

        /* commitEditing drives each editor and clears state */
        MockEditor *e3 = [MockEditor new];
        [c objectDidBeginEditing:e3];
        CHECK([c commitEditing], "commitEditing succeeds when editors allow");
        CHECK(e3.committed && !c.isEditing, "committed editor + editing cleared");

        /* a refusing editor blocks the commit and leaves editing in progress */
        MockEditor *bad = [MockEditor new];
        bad.allowCommit = NO;
        [c objectDidBeginEditing:bad];
        CHECK(![c commitEditing], "commitEditing fails when an editor refuses");
        CHECK(c.isEditing, "editing still in progress after refused commit");

        /* discardEditing drops everything */
        [c discardEditing];
        CHECK(bad.discarded && !c.isEditing, "discardEditing discards + clears");

        /* commitEditingWithDelegate: fires the callback with the result */
        MockEditor *e4 = [MockEditor new];
        [c objectDidBeginEditing:e4];
        CommitListener *lis = [CommitListener new];
        [c commitEditingWithDelegate:lis
                    didCommitSelector:@selector(editor:didCommit:contextInfo:)
                          contextInfo:NULL];
        CHECK(lis.gotCallback && lis.reportedDidCommit, "delegate callback reports success");

        /* commitEditingAndReturnError: mirrors commitEditing */
        NSError *err = nil;
        CHECK([c commitEditingAndReturnError:&err], "commitEditingAndReturnError YES when idle");

        /* conforms to the bindings protocols */
        CHECK([c conformsToProtocol:@protocol(NSEditor)]
              && [c conformsToProtocol:@protocol(NSEditorRegistration)], "conforms to NSEditor(+Registration)");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
