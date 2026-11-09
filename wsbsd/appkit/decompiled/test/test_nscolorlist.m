/* test_nscolorlist.m — NSColorList ordered key->color mapping. */
#import "../src/NSColorList.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSColorList *list = [[NSColorList alloc] initWithName:@"Brand"];
        CHECK([list.name isEqualToString:@"Brand"], "name stored");
        CHECK(list.isEditable, "in-memory list editable");
        CHECK(list.allKeys.count == 0, "empty initially");

        NSColor *red = [NSColor colorWithSRGBRed:1 green:0 blue:0 alpha:1];
        NSColor *green = [NSColor colorWithSRGBRed:0 green:1 blue:0 alpha:1];
        NSColor *blue = [NSColor colorWithSRGBRed:0 green:0 blue:1 alpha:1];

        [list setColor:red forKey:@"Red"];
        [list setColor:green forKey:@"Green"];
        CHECK(list.allKeys.count == 2, "two colors added");
        CHECK([list.allKeys[0] isEqualToString:@"Red"], "insertion order preserved (Red first)");
        CHECK([list colorWithKey:@"Red"] == red, "colorWithKey Red");
        CHECK([list colorWithKey:@"Green"] == green, "colorWithKey Green");
        CHECK([list colorWithKey:@"Missing"] == nil, "unknown key -> nil");

        /* setColor:forKey: on existing key replaces, keeps order */
        [list setColor:blue forKey:@"Red"];
        CHECK([list colorWithKey:@"Red"] == blue, "existing key replaced");
        CHECK(list.allKeys.count == 2, "replace does not grow the list");
        CHECK([list.allKeys[0] isEqualToString:@"Red"], "replaced key keeps its position");

        /* insert at index */
        [list insertColor:red key:@"Accent" atIndex:0];
        CHECK([list.allKeys[0] isEqualToString:@"Accent"], "inserted at index 0");
        CHECK(list.allKeys.count == 3, "insert grows list");
        CHECK([list colorWithKey:@"Accent"] == red, "inserted color retrievable");

        /* index map stays correct after insert */
        CHECK([list colorWithKey:@"Green"] == green, "Green still correct after insert");

        /* remove */
        [list removeColorWithKey:@"Red"];
        CHECK([list colorWithKey:@"Red"] == nil, "removed key gone");
        CHECK(list.allKeys.count == 2, "remove shrinks list");
        CHECK([list colorWithKey:@"Green"] == green, "Green still correct after remove");
        CHECK([list colorWithKey:@"Accent"] == red, "Accent still correct after remove");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
