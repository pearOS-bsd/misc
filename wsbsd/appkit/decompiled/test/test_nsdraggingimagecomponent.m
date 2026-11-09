/* test_nsdraggingimagecomponent.m — NSDraggingImageComponent value object. */
#import "../src/NSDraggingImageComponent.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSDraggingImageComponent *c = [NSDraggingImageComponent draggingImageComponentWithKey:NSDraggingImageComponentIconKey];
        CHECK([c.key isEqualToString:@"icon"], "icon key from factory");
        CHECK([NSDraggingImageComponentIconKey isEqualToString:@"icon"], "icon key constant");
        CHECK([NSDraggingImageComponentLabelKey isEqualToString:@"label"], "label key constant");
        CHECK(CGRectEqualToRect(c.frame, CGRectZero), "default frame zero");
        CHECK(c.contents == nil, "no contents by default");

        id img = [NSObject new];
        c.contents = img;
        c.frame = CGRectMake(0, 0, 32, 32);
        CHECK(c.contents == img, "contents set");
        CHECK(c.frame.size.width == 32, "frame set");

        c.key = NSDraggingImageComponentLabelKey;
        CHECK([c.key isEqualToString:@"label"], "key changed");

        NSDraggingImageComponent *l = [[NSDraggingImageComponent alloc] initWithKey:@"custom"];
        CHECK([l.key isEqualToString:@"custom"], "custom key via init");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
