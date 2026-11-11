/* test_nstablecellview.m — behaviour checks for NSTableCellView core */
#import "../src/NSTableCellView.h"
#import "../src/NSDraggingImageComponent.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSTableCellView *v = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 100, 24)];
        CHECK([v isKindOfClass:[NSView class]], "is an NSView");

        /* measured defaults */
        CHECK(v.backgroundStyle == NSBackgroundStyleNormal, "backgroundStyle default Normal");
        CHECK(v.rowSizeStyle == NSTableViewRowSizeStyleCustom, "rowSizeStyle default Custom(0)");
        CHECK(v.objectValue == nil && v.textField == nil && v.imageView == nil, "outlets/value nil");
        CHECK(v.draggingImageComponents.count == 1, "one drag component by default (view fallback)");

        /* enum sanity */
        CHECK(NSBackgroundStyleNormal == 0 && NSBackgroundStyleLowered == 3, "NSBackgroundStyle values");
        CHECK(NSTableViewRowSizeStyleDefault == -1 && NSTableViewRowSizeStyleLarge == 3, "NSTableViewRowSizeStyle values");

        /* value + outlets round-trip */
        v.objectValue = @"Ada";
        CHECK([v.objectValue isEqual:@"Ada"], "objectValue stored");
        v.backgroundStyle = NSBackgroundStyleEmphasized;
        CHECK(v.backgroundStyle == NSBackgroundStyleEmphasized, "backgroundStyle set");
        v.rowSizeStyle = NSTableViewRowSizeStyleMedium;
        CHECK(v.rowSizeStyle == NSTableViewRowSizeStyleMedium, "rowSizeStyle set");

        /* drag components grow with populated outlets */
        v.imageView = (NSImageView *)[NSObject new];   /* opaque stand-in; core only checks non-nil */
        CHECK(v.draggingImageComponents.count == 1, "one component with just an imageView");
        v.textField = (NSTextField *)[NSObject new];
        NSArray *comps = v.draggingImageComponents;
        CHECK(comps.count == 2, "two components with image + text");
        CHECK([[comps[0] key] isEqual:NSDraggingImageComponentIconKey]
              && [[comps[1] key] isEqual:NSDraggingImageComponentLabelKey], "component keys are icon then label");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
