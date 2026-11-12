/* test_nscandidatelisttouchbaritem.m */
#import "../src/NSCandidateListTouchBarItem.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

@interface Spy : NSObject <NSCandidateListTouchBarItemDelegate>
@property NSInteger visChanges; @property BOOL lastVisible;
@end
@implementation Spy
- (void)candidateListTouchBarItem:(NSCandidateListTouchBarItem *)i changedCandidateListVisibility:(BOOL)v { self.visChanges++; self.lastVisible = v; }
@end

int main(void) {
    @autoreleasepool {
        NSCandidateListTouchBarItem *c = [[NSCandidateListTouchBarItem alloc] initWithIdentifier:@"cl"];
        CHECK([c isKindOfClass:[NSTouchBarItem class]], "is NSTouchBarItem");
        CHECK([c.identifier isEqual:@"cl"], "identifier carried");

        /* measured defaults */
        CHECK(!c.isCollapsed, "not collapsed default");
        CHECK(c.allowsCollapsing, "allowsCollapsing YES default");
        CHECK(c.isCandidateListVisible, "candidateListVisible YES default");
        CHECK(c.allowsTextInputContextCandidates, "allowsTextInputContextCandidates YES default");
        CHECK(c.candidates.count == 0, "candidates empty default");
        CHECK([c.customizationLabel isEqual:@""], "customizationLabel empty default");
        CHECK(c.client == nil && c.delegate == nil, "client/delegate nil default");
        CHECK(c.attributedStringForCandidate == nil, "formatting block nil default");

        Spy *spy = [Spy new];
        c.delegate = spy;

        /* setCandidates stores them; visibility unaffected by count */
        [c setCandidates:@[@"foo", @"bar"] forSelectedRange:NSMakeRange(0,0) inString:@"f"];
        CHECK(c.candidates.count == 2 && [c.candidates[1] isEqual:@"bar"], "candidates stored");
        CHECK(c.isCandidateListVisible, "still visible with candidates (not collapsed)");

        /* collapsing hides the list + notifies delegate */
        c.collapsed = YES;
        CHECK(c.isCollapsed && !c.isCandidateListVisible, "collapsed -> not visible");
        CHECK(spy.visChanges == 1 && spy.lastVisible == NO, "delegate told visibility NO");

        /* idempotent set does not re-notify */
        c.collapsed = YES;
        CHECK(spy.visChanges == 1, "no re-notify on same value");

        /* expanding notifies again */
        c.collapsed = NO;
        CHECK(c.isCandidateListVisible && spy.visChanges == 2 && spy.lastVisible == YES, "expand -> visible + notify");

        /* formatting block */
        c.attributedStringForCandidate = ^NSAttributedString *(id cand, NSInteger idx) { return nil; };
        CHECK(c.attributedStringForCandidate != nil, "formatting block set");

        /* other setters */
        c.allowsCollapsing = NO; CHECK(!c.allowsCollapsing, "allowsCollapsing set");
        c.allowsTextInputContextCandidates = NO; CHECK(!c.allowsTextInputContextCandidates, "allowsICC set");
        c.customizationLabel = @"Suggestions"; CHECK([c.customizationLabel isEqual:@"Suggestions"], "customizationLabel set");
        id client = [NSObject new]; c.client = client; CHECK(c.client == client, "client set");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
