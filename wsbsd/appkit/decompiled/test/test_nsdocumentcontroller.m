/* test_nsdocumentcontroller.m — NSDocumentController list + recents. */
#import "../src/NSDocumentController.h"
#import "../src/NSDocument.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSDocumentController *dc = [NSDocumentController sharedDocumentController];
        CHECK(dc != nil, "shared controller exists");
        CHECK([NSDocumentController sharedDocumentController] == dc, "shared is a singleton");
        CHECK(dc.documents.count == 0, "no documents initially");
        CHECK(dc.maximumRecentDocumentCount == 10, "default max recents 10");

        NSDocument *d1 = [[NSDocument alloc] init];
        d1.fileURL = [NSURL fileURLWithPath:@"/tmp/a.txt"];
        NSDocument *d2 = [[NSDocument alloc] init];
        d2.fileURL = [NSURL fileURLWithPath:@"/tmp/b.txt"];

        [dc addDocument:d1];
        [dc addDocument:d2];
        CHECK(dc.documents.count == 2, "two documents added");
        CHECK(dc.currentDocument == d2, "currentDocument is most recently added");
        [dc addDocument:d1]; /* dup */
        CHECK(dc.documents.count == 2, "duplicate add is a no-op");

        /* documentForURL */
        CHECK([dc documentForURL:[NSURL fileURLWithPath:@"/tmp/a.txt"]] == d1, "documentForURL finds a.txt");
        CHECK([dc documentForURL:[NSURL fileURLWithPath:@"/tmp/missing.txt"]] == nil, "unknown URL -> nil");

        /* remove updates currentDocument */
        [dc removeDocument:d2];
        CHECK(dc.documents.count == 1, "document removed");
        CHECK(dc.currentDocument == d1, "currentDocument falls back after removal");

        /* recents: most-recent-first, de-duplicated, capped */
        for (int i = 0; i < 12; i++) {
            NSURL *u = [NSURL fileURLWithPath:[NSString stringWithFormat:@"/tmp/doc%d.txt", i]];
            [dc noteNewRecentDocumentURL:u];
        }
        CHECK(dc.recentDocumentURLs.count == 10, "recents capped at max");
        CHECK([dc.recentDocumentURLs[0].path isEqualToString:@"/tmp/doc11.txt"], "most recent is first");

        /* re-noting an existing URL moves it to front, no growth */
        NSURL *again = [NSURL fileURLWithPath:@"/tmp/doc5.txt"];
        [dc noteNewRecentDocumentURL:again];
        CHECK([dc.recentDocumentURLs[0].path isEqualToString:@"/tmp/doc5.txt"], "re-noted URL moves to front");
        CHECK(dc.recentDocumentURLs.count == 10, "still capped after re-note");

        [dc removeDocument:d1];
        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
