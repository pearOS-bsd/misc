/* test_nssortdescriptor.m — granular imports. */
#import "../src/NSSortDescriptor.h"
#import <Foundation/NSString.h>
#import <Foundation/NSDictionary.h>
#import <stdio.h>

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSSortDescriptor *s = [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES];
        CHECK([s.key isEqualToString:@"name"], "key stored");
        CHECK(s.ascending, "ascending YES");
        CHECK(s.selector == @selector(compare:), "selector defaults to compare:");

        /* reversed */
        NSSortDescriptor *r = [s reversedSortDescriptor];
        CHECK(!r.ascending && [r.key isEqualToString:@"name"], "reversed flips ascending, keeps key");

        /* compareObject:toObject: via KVC on dictionaries */
        id a = @{@"name": @"apple"};
        id b = @{@"name": @"banana"};
        CHECK([s compareObject:a toObject:b] == NSOrderedAscending, "apple < banana ascending");
        CHECK([s compareObject:b toObject:a] == NSOrderedDescending, "banana > apple ascending");
        CHECK([s compareObject:a toObject:a] == NSOrderedSame, "equal -> Same");

        /* descending negates */
        CHECK([r compareObject:a toObject:b] == NSOrderedDescending, "descending negates the result");

        /* explicit selector */
        NSSortDescriptor *sd = [NSSortDescriptor sortDescriptorWithKey:@"x" ascending:NO selector:@selector(caseInsensitiveCompare:)];
        CHECK(sd.selector == @selector(caseInsensitiveCompare:) && !sd.ascending, "explicit selector stored");

        /* nil selector falls back to compare: */
        NSSortDescriptor *n = [[NSSortDescriptor alloc] initWithKey:@"x" ascending:YES selector:NULL];
        CHECK(n.selector == @selector(compare:), "nil selector -> compare:");

        CHECK([s copy] == s, "immutable copy == self");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
