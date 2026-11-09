/* test_nspasteboard.m — NSPasteboard in-process model. */
#import "../src/NSPasteboard.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSPasteboard *pb = [NSPasteboard pasteboardWithName:@"test.pb"];
        CHECK([pb.name isEqualToString:@"test.pb"], "name stored");
        CHECK([NSPasteboard pasteboardWithName:@"test.pb"] == pb, "named pasteboard is cached");
        CHECK([NSPasteboard generalPasteboard] == [NSPasteboard generalPasteboard], "general is a singleton");
        CHECK(pb.types == nil, "no types before declaration");

        NSInteger c0 = pb.changeCount;
        NSInteger c1 = [pb declareTypes:@[NSPasteboardTypeString] owner:nil];
        CHECK(c1 == c0 + 1, "declareTypes bumps changeCount");
        CHECK(pb.types.count == 1 && [pb.types[0] isEqualToString:NSPasteboardTypeString], "declared type present");

        CHECK([pb setString:@"hello" forType:NSPasteboardTypeString], "setString returns YES");
        CHECK([[pb stringForType:NSPasteboardTypeString] isEqualToString:@"hello"], "stringForType round-trips");

        /* data round-trip */
        NSData *d = [@"bytes" dataUsingEncoding:NSUTF8StringEncoding];
        [pb setData:d forType:@"public.data"];
        CHECK([[pb dataForType:@"public.data"] isEqualToData:d], "dataForType round-trips");

        /* availableTypeFromArray */
        NSString *avail = [pb availableTypeFromArray:@[@"public.html", @"public.data", NSPasteboardTypeString]];
        CHECK([avail isEqualToString:@"public.data"], "availableTypeFromArray returns first present type");
        CHECK([pb availableTypeFromArray:@[@"public.html"]] == nil, "absent type -> nil");

        /* clearContents wipes and bumps */
        NSInteger before = pb.changeCount;
        NSInteger after = [pb clearContents];
        CHECK(after == before + 1, "clearContents bumps changeCount");
        CHECK(pb.types == nil, "types cleared");
        CHECK([pb stringForType:NSPasteboardTypeString] == nil, "data cleared");

        /* declareTypes clears previous data */
        [pb declareTypes:@[NSPasteboardTypeString] owner:nil];
        [pb setString:@"v1" forType:NSPasteboardTypeString];
        [pb declareTypes:@[NSPasteboardTypeString] owner:nil];
        CHECK([pb stringForType:NSPasteboardTypeString] == nil, "re-declareTypes clears old data");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
