/* test_nsindexpath.m — granular Foundation sub-header imports only. */
#import "../src/NSIndexPath.h"
#import <stdio.h>

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSUInteger idx[3] = {2, 5, 9};
        NSIndexPath *p = [NSIndexPath indexPathWithIndexes:idx length:3];
        CHECK(p.length == 3, "length 3");
        CHECK([p indexAtPosition:0] == 2 && [p indexAtPosition:1] == 5 && [p indexAtPosition:2] == 9, "indexes stored");
        CHECK([p indexAtPosition:3] == NSNotFound, "out-of-range -> NSNotFound (measured)");

        NSIndexPath *one = [NSIndexPath indexPathWithIndex:7];
        CHECK(one.length == 1 && [one indexAtPosition:0] == 7, "single-index path");

        NSIndexPath *add = [one indexPathByAddingIndex:3];
        CHECK(add.length == 2 && [add indexAtPosition:1] == 3, "indexPathByAddingIndex appends");

        NSIndexPath *rem = [add indexPathByRemovingLastIndex];
        CHECK(rem.length == 1 && [rem indexAtPosition:0] == 7, "indexPathByRemovingLastIndex drops last");

        NSIndexPath *empty = [[NSIndexPath alloc] init];
        CHECK(empty.length == 0 && [empty indexAtPosition:0] == NSNotFound, "empty path");
        CHECK([empty indexPathByRemovingLastIndex].length == 0, "removing from empty stays empty");

        /* getIndexes:range: */
        NSUInteger out[2] = {0,0};
        [p getIndexes:out range:NSMakeRange(1,2)];
        CHECK(out[0] == 5 && out[1] == 9, "getIndexes:range: copies the slice");

        /* equality + compare */
        NSIndexPath *same = [NSIndexPath indexPathWithIndexes:idx length:3];
        CHECK([p isEqual:same] && p.hash == same.hash, "isEqual + hash by contents");
        CHECK([p compare:same] == NSOrderedSame, "compare equal -> Same");
        CHECK([one compare:p] == NSOrderedDescending, "[7] > [2,5,9] at position 0");
        CHECK([[NSIndexPath indexPathWithIndex:2] compare:p] == NSOrderedAscending, "[2] < [2,5,9] (prefix shorter)");

        CHECK([p copy] == p, "immutable copy == self");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
