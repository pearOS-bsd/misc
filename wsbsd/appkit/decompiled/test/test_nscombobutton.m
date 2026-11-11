/* test_nscombobutton.m — behaviour checks for NSComboButton core */
#import "../src/NSComboButton.h"
#import "../src/NSMenu.h"
#import "../src/NSApplication.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];

        NSComboButton *d = [[NSComboButton alloc] initWithFrame:NSMakeRect(0, 0, 80, 24)];
        CHECK([d isKindOfClass:[NSControl class]], "is an NSControl");

        /* measured defaults */
        CHECK([d.title isEqual:@""], "title default empty");
        CHECK(d.style == NSComboButtonStyleSplit, "style default Split(0)");
        CHECK(d.imageScaling == NSImageScaleProportionallyDown, "imageScaling default 0");
        CHECK(d.image == nil, "image nil");
        CHECK(NSComboButtonStyleSplit == 0 && NSComboButtonStyleUnified == 1, "style enum values");

        /* title is null_resettable -> "" */
        d.title = @"Export";
        CHECK([d.title isEqual:@"Export"], "title set");
        NSString *nilTitle = nil;
        d.title = nilTitle;
        CHECK([d.title isEqual:@""], "setting nil title coerces to empty");

        /* factory: title + menu + target/action */
        NSMenu *m = [[NSMenu alloc] initWithTitle:@"Actions"];
        id tgt = [NSObject new];
        NSComboButton *b = [NSComboButton comboButtonWithTitle:@"Save" menu:m target:tgt action:@selector(copy)];
        CHECK([b.title isEqual:@"Save"], "factory sets title");
        CHECK(b.menu == m, "factory sets menu");
        CHECK(b.target == tgt && b.action == @selector(copy), "factory sets target/action");
        CHECK(b.image == nil, "title-only factory has no image");

        /* image factory */
        NSComboButton *bi = [NSComboButton comboButtonWithImage:(NSImage *)[NSObject new] menu:m target:nil action:NULL];
        CHECK([bi.title isEqual:@""] && bi.image != nil, "image factory: empty title + image set");

        /* style/imageScaling setters */
        b.style = NSComboButtonStyleUnified;
        CHECK(b.style == NSComboButtonStyleUnified, "style setter");
        b.imageScaling = NSImageScaleNone;
        CHECK(b.imageScaling == NSImageScaleNone, "imageScaling setter");

        /* menu round-trip incl. clearing */
        b.menu = nil;
        CHECK(b.menu == nil, "menu cleared");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
