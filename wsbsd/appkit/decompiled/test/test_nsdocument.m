/* test_nsdocument.m — NSDocument change tracking + window controllers. */
#import "../src/NSDocument.h"
#import "../src/NSWindowController.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSDocument *doc = [[NSDocument alloc] init];
        CHECK(!doc.isDocumentEdited, "fresh document not edited");
        CHECK([doc.displayName isEqualToString:@"Untitled"], "default display name Untitled");

        doc.fileURL = [NSURL fileURLWithPath:@"/tmp/Report.txt"];
        doc.fileType = @"public.plain-text";
        CHECK([doc.fileType isEqualToString:@"public.plain-text"], "fileType set");
        CHECK([doc.displayName isEqualToString:@"Report"], "display name from file URL without extension");

        /* explicit display name overrides */
        [doc setDisplayName:@"My Report"];
        CHECK([doc.displayName isEqualToString:@"My Report"], "explicit display name wins");

        /* change count */
        [doc updateChangeCount:NSChangeDone];
        CHECK(doc.isDocumentEdited, "NSChangeDone marks edited");
        [doc updateChangeCount:NSChangeDone];
        [doc updateChangeCount:NSChangeUndone];
        CHECK(doc.isDocumentEdited, "still edited after one undo of two edits");
        [doc updateChangeCount:NSChangeUndone];
        CHECK(!doc.isDocumentEdited, "fully undone -> not edited");

        [doc updateChangeCount:NSChangeDone];
        [doc updateChangeCount:NSChangeCleared];
        CHECK(!doc.isDocumentEdited, "NSChangeCleared resets edited state");

        /* redo increments like done */
        [doc updateChangeCount:NSChangeRedone];
        CHECK(doc.isDocumentEdited, "NSChangeRedone marks edited");
        [doc updateChangeCount:NSChangeCleared];

        /* window controllers */
        NSWindowController *wc1 = [[NSWindowController alloc] init];
        NSWindowController *wc2 = [[NSWindowController alloc] init];
        [doc addWindowController:wc1];
        [doc addWindowController:wc2];
        CHECK(doc.windowControllers.count == 2, "two window controllers added");
        CHECK(wc1.document == doc, "addWindowController links back to document");
        [doc addWindowController:wc1];
        CHECK(doc.windowControllers.count == 2, "adding the same controller twice is a no-op");

        [doc removeWindowController:wc1];
        CHECK(doc.windowControllers.count == 1, "window controller removed");
        CHECK(wc1.document == nil, "removed controller unlinked from document");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
