/* test_nspasteboarditem.m — NSPasteboardItem data/string/plist. */
#import "../src/NSPasteboardItem.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSPasteboardItem *item = [[NSPasteboardItem alloc] init];
        CHECK(item.types.count == 0, "no types initially");

        [item setString:@"hello" forType:@"public.utf8-plain-text"];
        CHECK(item.types.count == 1, "one type after setString");
        CHECK([[item stringForType:@"public.utf8-plain-text"] isEqualToString:@"hello"], "string round-trips");

        NSData *d = [@"bytes" dataUsingEncoding:NSUTF8StringEncoding];
        [item setData:d forType:@"public.data"];
        CHECK([[item dataForType:@"public.data"] isEqualToData:d], "data round-trips");
        CHECK(item.types.count == 2, "two types; declaration order preserved");
        CHECK([item.types[0] isEqualToString:@"public.utf8-plain-text"], "first declared type first");

        /* property list round-trip */
        NSDictionary *plist = @{ @"k": @"v", @"n": @42 };
        CHECK([item setPropertyList:plist forType:@"com.app.plist"], "setPropertyList YES");
        id back = [item propertyListForType:@"com.app.plist"];
        CHECK([back isEqual:plist], "property list round-trips");

        /* availableTypeFromArray */
        NSString *avail = [item availableTypeFromArray:@[@"public.html", @"public.data"]];
        CHECK([avail isEqualToString:@"public.data"], "availableTypeFromArray finds present type");
        CHECK([item availableTypeFromArray:@[@"public.html"]] == nil, "absent -> nil");

        /* overwrite keeps single type entry */
        [item setString:@"world" forType:@"public.utf8-plain-text"];
        CHECK([[item stringForType:@"public.utf8-plain-text"] isEqualToString:@"world"], "overwrite updates data");
        CHECK(item.types.count == 3, "overwrite does not add a duplicate type");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
