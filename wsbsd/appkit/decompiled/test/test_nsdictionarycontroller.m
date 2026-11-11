/* test_nsdictionarycontroller.m — behaviour checks for NSDictionaryController core */
#import "../src/NSDictionaryController.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

static NSDictionaryControllerKeyValuePair *PairForKey(NSArray *arr, NSString *key) {
    for (NSDictionaryControllerKeyValuePair *p in arr) if ([p.key isEqual:key]) return p;
    return nil;
}

int main(void) {
    @autoreleasepool {
        NSDictionaryController *d = [[NSDictionaryController alloc] init];
        CHECK([d isKindOfClass:[NSArrayController class]], "is an NSArrayController");

        /* measured defaults */
        CHECK([d.initialKey isEqual:@"key"], "initialKey default 'key'");
        CHECK(d.includedKeys.count == 0 && d.excludedKeys.count == 0, "included/excluded empty");

        /* dictionary content -> key-value pairs */
        d.content = @{@"alpha": @1, @"beta": @2};
        NSArray *arr = d.arrangedObjects;
        CHECK(arr.count == 2, "two pairs for two keys");
        CHECK([arr[0] isKindOfClass:[NSDictionaryControllerKeyValuePair class]], "elements are key-value pairs");
        NSDictionaryControllerKeyValuePair *pa = PairForKey(arr, @"alpha");
        CHECK(pa != nil && [pa.value isEqual:@1], "alpha pair has value 1");
        CHECK([pa.localizedKey isEqual:@"alpha"], "localizedKey defaults to key");
        CHECK(!pa.isExplicitlyIncluded, "dictionary-derived pair not explicitlyIncluded");

        /* content reads the dictionary back */
        NSDictionary *back = d.content;
        CHECK([back isKindOfClass:[NSDictionary class]] && [back[@"beta"] isEqual:@2], "content rebuilds dictionary");

        /* newObject returns an empty pair */
        NSDictionaryControllerKeyValuePair *np = [d newObject];
        CHECK([np isKindOfClass:[NSDictionaryControllerKeyValuePair class]] && np.key == nil && np.value == nil,
              "newObject is an empty pair");

        /* excludedKeys hides a key */
        NSDictionaryController *d2 = [[NSDictionaryController alloc] init];
        d2.excludedKeys = @[@"secret"];
        d2.content = @{@"visible": @10, @"secret": @99};
        CHECK([(NSArray *)d2.arrangedObjects count] == 1 && PairForKey(d2.arrangedObjects, @"secret") == nil, "excludedKeys hidden");

        /* includedKeys adds an explicitly-included pair with no dict entry */
        NSDictionaryController *d3 = [[NSDictionaryController alloc] init];
        d3.includedKeys = @[@"forced"];
        d3.content = @{@"real": @1};
        NSDictionaryControllerKeyValuePair *fp = PairForKey(d3.arrangedObjects, @"forced");
        CHECK([(NSArray *)d3.arrangedObjects count] == 2 && fp != nil && fp.isExplicitlyIncluded && fp.value == nil,
              "includedKeys adds explicitlyIncluded empty pair");

        /* localizedKeyDictionary maps the shown key */
        NSDictionaryController *d4 = [[NSDictionaryController alloc] init];
        d4.localizedKeyDictionary = @{@"k": @"Clé"};
        d4.content = @{@"k": @5};
        CHECK([PairForKey(d4.arrangedObjects, @"k").localizedKey isEqual:@"Clé"], "localizedKeyDictionary maps localizedKey");

        /* pair equality by key */
        NSDictionaryControllerKeyValuePair *p1 = [NSDictionaryControllerKeyValuePair new]; p1.key = @"x"; p1.value = @1;
        NSDictionaryControllerKeyValuePair *p2 = [NSDictionaryControllerKeyValuePair new]; p2.key = @"x"; p2.value = @2;
        CHECK([p1 isEqual:p2], "pairs equal by key");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
