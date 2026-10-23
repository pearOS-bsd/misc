/* the names Rename N Items… produces: Replace Text, Add Text, Format (index, counter) */
#import "TFinderViews.h"
static int fails;
static void Check(NSArray *got, NSArray *want, const char *what) { if (![got isEqual: want]) { printf("FAIL %s: %s\n", what, [[got description] UTF8String]); fails++; } }
int main(void)
{
	@autoreleasepool {
		NSArray *p = @[ @"/t/a.txt", @"/t/b.txt", @"/t/c" ];
		Check(TFBulkRenamedNames(p, @{ @"mode": @0, @"find": @"txt", @"replace": @"md" }), (@[ @"a.md", @"b.md", @"c" ]), "replace");
		Check(TFBulkRenamedNames(p, @{ @"mode": @1, @"text": @"_x", @"after": @YES }), (@[ @"a_x.txt", @"b_x.txt", @"c_x" ]), "add after");
		Check(TFBulkRenamedNames(p, @{ @"mode": @1, @"text": @"x_", @"after": @NO }), (@[ @"x_a.txt", @"x_b.txt", @"x_c" ]), "add before");
		Check(TFBulkRenamedNames(p, @{ @"mode": @2, @"format": @0, @"custom": @"Photo ", @"after": @YES, @"start": @5 }), (@[ @"Photo 5.txt", @"Photo 6.txt", @"Photo 7" ]), "index after");
		Check(TFBulkRenamedNames(p, @{ @"mode": @2, @"format": @1, @"custom": @" Photo", @"after": @NO, @"start": @1 }), (@[ @"00001 Photo.txt", @"00002 Photo.txt", @"00003 Photo" ]), "counter before");
	}
	printf(fails ? "bulk rename: %d failed\n" : "bulk rename: 5 cases ok\n", fails); return fails != 0;
}
