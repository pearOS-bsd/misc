/* test_nstableviewrowaction.m — NSTableViewRowAction. */
#import "../src/NSTableViewRowAction.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        __block NSInteger firedRow = -1;
        NSTableViewRowAction *del = [NSTableViewRowAction rowActionWithStyle:NSTableViewRowActionStyleDestructive
                                                                      title:@"Delete"
                                                                    handler:^(NSTableViewRowAction *a, NSInteger row) {
            firedRow = row;
        }];
        CHECK(del.style == NSTableViewRowActionStyleDestructive, "destructive style");
        CHECK([del.title isEqualToString:@"Delete"], "title set");
        CHECK(del.handler != nil, "handler stored");
        CHECK(del.allowsFullSwipe, "allowsFullSwipe default YES");

        /* handler fires with the row */
        del.handler(del, 7);
        CHECK(firedRow == 7, "handler receives the row");

        del.allowsFullSwipe = NO;
        id color = [NSObject new];
        del.backgroundColor = color;
        CHECK(!del.allowsFullSwipe, "allowsFullSwipe cleared");
        CHECK(del.backgroundColor == color, "background color set");

        del.title = @"Trash";
        CHECK([del.title isEqualToString:@"Trash"], "title changed");

        /* regular style */
        NSTableViewRowAction *more = [NSTableViewRowAction rowActionWithStyle:NSTableViewRowActionStyleRegular
                                                                       title:@"More" handler:^(NSTableViewRowAction *a, NSInteger r){}];
        CHECK(more.style == NSTableViewRowActionStyleRegular, "regular style");

        /* copy keeps handler + fields */
        NSTableViewRowAction *c = [del copy];
        CHECK(c.style == NSTableViewRowActionStyleDestructive && !c.allowsFullSwipe, "copy carries fields");
        CHECK(c.handler != nil, "copy keeps handler");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
