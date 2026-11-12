/* test_nscolorpickertouchbaritem.m */
#import "../src/NSColorPickerTouchBarItem.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSColorPickerTouchBarItem *c = [NSColorPickerTouchBarItem colorPickerWithIdentifier:@"id"];
        CHECK([c isKindOfClass:[NSTouchBarItem class]], "is NSTouchBarItem");
        CHECK([c.identifier isEqual:@"id"], "identifier set");

        /* measured defaults */
        CHECK(c.showsAlpha, "showsAlpha default YES");
        CHECK(c.isEnabled, "enabled default YES");
        CHECK(c.allowedColorSpaces.count == 0, "allowedColorSpaces empty");

        /* setters */
        id col = [NSObject new];
        c.color = (id)col; CHECK(c.color == col, "color stored");
        c.showsAlpha = NO; CHECK(!c.showsAlpha, "showsAlpha set");
        c.allowedColorSpaces = @[@"a", @"b"]; CHECK(c.allowedColorSpaces.count == 2, "allowedColorSpaces set");
        c.colorListSupportsPressAndHoldVariants = YES; CHECK(c.colorListSupportsPressAndHoldVariants, "press-and-hold variants flag");
        id tgt = [NSObject new]; c.target = tgt; c.action = @selector(copy);
        CHECK(c.target == tgt && c.action == @selector(copy), "target/action set");
        c.customizationLabel = @"Pick"; CHECK([c.customizationLabel isEqual:@"Pick"], "customizationLabel set");

        /* button title/image factories */
        NSColorPickerTouchBarItem *bt = [NSColorPickerTouchBarItem colorPickerWithIdentifier:@"t" buttonTitle:@"Color"];
        CHECK([bt.buttonTitle isEqual:@"Color"], "buttonTitle factory");
        id img = [NSObject new];
        NSColorPickerTouchBarItem *bi = [NSColorPickerTouchBarItem colorPickerWithIdentifier:@"i" buttonImage:(id)img];
        CHECK(bi.buttonImage == img, "buttonImage factory");

        /* stroke / text pickers are distinct instances */
        CHECK([NSColorPickerTouchBarItem strokeColorPickerWithIdentifier:@"s"] != nil
              && [NSColorPickerTouchBarItem textColorPickerWithIdentifier:@"x"] != nil, "stroke/text factories");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
