/* test_nsprintoperation.m */
#import "../src/NSPrintOperation.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        id view = [NSObject new];   /* stand-in NSView */
        NSPrintOperation *op = [NSPrintOperation printOperationWithView:(id)view];

        /* measured defaults */
        CHECK((id)op.view == view, "view stored");
        CHECK(op.printInfo != nil, "printInfo non-nil (defaults from shared)");
        CHECK(op.showsPrintPanel, "showsPrintPanel YES default");
        CHECK(op.showsProgressPanel, "showsProgressPanel YES default");
        CHECK(op.jobTitle == nil, "jobTitle nil default");
        CHECK(op.pageOrder == NSAscendingPageOrder, "pageOrder Ascending default");
        CHECK(!op.canSpawnSeparateThread, "canSpawnSeparateThread NO default");
        CHECK(!op.isCopyingOperation, "isCopyingOperation NO");

        /* page order enum */
        CHECK(NSDescendingPageOrder == -1 && NSAscendingPageOrder == 1 && NSUnknownPageOrder == 2, "page order enum");

        /* currentOperation is nil outside a run */
        CHECK([NSPrintOperation currentOperation] == nil, "currentOperation nil by default");
        [NSPrintOperation setCurrentOperation:op];
        CHECK([NSPrintOperation currentOperation] == op, "setCurrentOperation sets thread-local");
        [NSPrintOperation setCurrentOperation:nil];
        CHECK([NSPrintOperation currentOperation] == nil, "clearing currentOperation");

        /* setters */
        op.jobTitle = @"Report"; CHECK([op.jobTitle isEqual:@"Report"], "jobTitle set");
        op.showsPrintPanel = NO; CHECK(!op.showsPrintPanel, "showsPrintPanel set");
        op.pageOrder = NSDescendingPageOrder; CHECK(op.pageOrder == NSDescendingPageOrder, "pageOrder set");
        op.canSpawnSeparateThread = YES; CHECK(op.canSpawnSeparateThread, "canSpawnSeparateThread set");

        /* explicit printInfo */
        NSPrintInfo *pi = [[NSPrintInfo alloc] initWithDictionary:nil];
        NSPrintOperation *op2 = [NSPrintOperation printOperationWithView:(id)view printInfo:pi];
        CHECK(op2.printInfo != nil, "explicit printInfo stored");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
