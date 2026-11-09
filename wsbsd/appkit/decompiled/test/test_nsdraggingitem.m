/* test_nsdraggingitem.m — NSDraggingItem. */
#import "../src/NSDraggingItem.h"
#import "../src/NSDraggingImageComponent.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        id writer = [NSObject new];
        NSDraggingItem *di = [[NSDraggingItem alloc] initWithPasteboardWriter:writer];
        CHECK(di.item == writer, "item is the pasteboard writer");
        CHECK(CGRectEqualToRect(di.draggingFrame, CGRectZero), "default frame zero");
        CHECK(di.imageComponents.count == 0, "no image components by default");

        id local = [NSObject new];
        di.localObject = local;
        CHECK(di.localObject == local, "local object set");

        /* setDraggingFrame:contents: makes a single icon component */
        id img = [NSObject new];
        [di setDraggingFrame:CGRectMake(5, 5, 48, 48) contents:img];
        CHECK(di.draggingFrame.size.width == 48, "dragging frame set");
        CHECK(di.imageComponents.count == 1, "one image component created");
        NSDraggingImageComponent *c = di.imageComponents[0];
        CHECK([c.key isEqualToString:NSDraggingImageComponentIconKey], "icon component key");
        CHECK(c.contents == img, "component contents set");
        CHECK(c.frame.size.width == 48 && c.frame.origin.x == 0, "component frame is item bounds");

        /* provider block used when no explicit components */
        NSDraggingItem *di2 = [[NSDraggingItem alloc] initWithPasteboardWriter:writer];
        __block int called = 0;
        di2.imageComponentsProvider = ^NSArray *{
            called++;
            NSDraggingImageComponent *cc = [NSDraggingImageComponent draggingImageComponentWithKey:NSDraggingImageComponentLabelKey];
            return @[ cc ];
        };
        NSArray *comps = di2.imageComponents;
        CHECK(comps.count == 1, "provider supplies components");
        CHECK(called == 1, "provider block evaluated on demand");
        CHECK([[comps[0] key] isEqualToString:NSDraggingImageComponentLabelKey], "provider component key");

        /* explicit components win over provider */
        NSDraggingImageComponent *ec = [NSDraggingImageComponent draggingImageComponentWithKey:NSDraggingImageComponentIconKey];
        di2.imageComponents = @[ ec ];
        CHECK(di2.imageComponents.count == 1 && [[di2.imageComponents[0] key] isEqualToString:@"icon"],
              "explicit components override provider");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
