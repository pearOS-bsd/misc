/* test_nstextcontentmanager.m */
#import "../src/NSTextContentManager.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSTextContentManager *m = [[NSTextContentManager alloc] init];

        /* measured defaults */
        CHECK(m.textLayoutManagers.count == 0, "no layout managers default");
        CHECK(m.primaryTextLayoutManager == nil, "primary nil default");
        CHECK(!m.hasEditingTransaction, "no editing transaction default");
        CHECK(m.automaticallySynchronizesTextLayoutManagers, "autoSyncTLM YES default");
        CHECK(!m.automaticallySynchronizesToBackingStore, "autoSyncBackingStore NO default");
        CHECK(m.delegate == nil, "delegate nil default");
        CHECK(m.documentRange == nil, "documentRange nil in base");

        /* add/remove layout managers (stored as opaque ids here) */
        id lm1 = [NSObject new];
        id lm2 = [NSObject new];
        [m addTextLayoutManager:(id)lm1];
        CHECK(m.textLayoutManagers.count == 1, "one manager added");
        CHECK(m.primaryTextLayoutManager == nil, "first add does NOT auto-set primary (measured)");
        [m addTextLayoutManager:(id)lm1];
        CHECK(m.textLayoutManagers.count == 1, "duplicate add deduped");
        [m addTextLayoutManager:(id)lm2];
        CHECK(m.textLayoutManagers.count == 2, "second manager added");

        /* primary is independently settable and joins the list */
        m.primaryTextLayoutManager = (id)lm2;
        CHECK((id)m.primaryTextLayoutManager == lm2, "primary set");
        CHECK(m.textLayoutManagers.count == 2, "setting existing primary doesn't duplicate");

        [m removeTextLayoutManager:(id)lm2];
        CHECK(m.textLayoutManagers.count == 1 && m.primaryTextLayoutManager == nil, "removing primary clears it");

        /* editing transaction toggles hasEditingTransaction, restores after (nesting) */
        __block BOOL inside = NO; __block BOOL innerInside = NO;
        [m performEditingTransactionUsingBlock:^{
            inside = m.hasEditingTransaction;
            [m performEditingTransactionUsingBlock:^{ innerInside = m.hasEditingTransaction; }];
            /* still in a transaction after the nested one returns */
            CHECK(m.hasEditingTransaction, "still in transaction after nested block");
        }];
        CHECK(inside && innerInside, "hasEditingTransaction YES inside block (nested too)");
        CHECK(!m.hasEditingTransaction, "hasEditingTransaction NO after block");

        /* base content hook returns empty */
        CHECK(m.textLayoutManagers != nil, "textLayoutManagers never nil");
        CHECK([m textElementsForRange:nil].count == 0, "base textElementsForRange empty");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
