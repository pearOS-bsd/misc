/* test_nspathcontrolitem.m — NSPathControlItem title/URL/image. */
#import "../src/NSPathControlItem.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSPathControlItem *item = [[NSPathControlItem alloc] init];
        CHECK([item.title isEqualToString:@""], "title defaults empty");
        CHECK([item.attributedTitle.string isEqualToString:@""], "attributed title defaults empty");

        item.title = @"Documents";
        CHECK([item.title isEqualToString:@"Documents"], "title set");
        CHECK([item.attributedTitle.string isEqualToString:@"Documents"], "attributed title tracks plain title");

        item.attributedTitle = [[NSAttributedString alloc] initWithString:@"Reports"];
        CHECK([item.title isEqualToString:@"Reports"], "plain title tracks attributed title");

        item.URL = [NSURL fileURLWithPath:@"/Users/me/Documents"];
        CHECK([item.URL.path isEqualToString:@"/Users/me/Documents"], "URL set");

        id img = [NSObject new];
        item.image = img;
        CHECK(item.image == img, "image set");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
