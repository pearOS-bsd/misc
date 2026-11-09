/* test_nstextattachment.m — NSTextAttachment value object. */
#import "../src/NSTextAttachment.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSData *d = [@"PNGDATA" dataUsingEncoding:NSUTF8StringEncoding];
        NSTextAttachment *a = [[NSTextAttachment alloc] initWithData:d ofType:@"public.png"];
        CHECK([a.contents isEqualToData:d], "contents from init");
        CHECK([a.fileType isEqualToString:@"public.png"], "fileType from init");
        CHECK(CGRectEqualToRect(a.bounds, CGRectZero), "default bounds zero");
        CHECK(a.lineLayoutPadding == 0.0, "default padding 0");
        CHECK(a.allowsTextAttachmentView == NO, "default allowsTextAttachmentView NO");

        a.bounds = CGRectMake(0, -2, 16, 16);
        a.lineLayoutPadding = 3.0;
        a.allowsTextAttachmentView = YES;
        id img = [NSObject new];
        a.image = img;
        CHECK(a.bounds.size.width == 16 && a.bounds.origin.y == -2, "bounds set");
        CHECK(a.lineLayoutPadding == 3.0, "padding set");
        CHECK(a.allowsTextAttachmentView == YES, "allowsTextAttachmentView set");
        CHECK(a.image == img, "image set");

        /* plain init */
        NSTextAttachment *e = [[NSTextAttachment alloc] init];
        CHECK(e.contents == nil && e.fileType == nil, "plain init empty");
        e.contents = d;
        CHECK([e.contents isEqualToData:d], "contents settable after init");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
