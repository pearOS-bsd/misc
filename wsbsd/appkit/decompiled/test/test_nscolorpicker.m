/* test_nscolorpicker.m */
#import "../src/NSColorPicker.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

/* a trivial subclass that supplies a tool tip + image, like a real plug-in */
@interface MyPicker : NSColorPicker
@end
@implementation MyPicker
- (NSString *)buttonToolTip { return @"My Colors"; }
@end

int main(void) {
    @autoreleasepool {
        id panel = [NSObject new];  /* stand-in NSColorPanel */
        NSColorPicker *p = [[NSColorPicker alloc] initWithPickerMask:0xffff colorPanel:(id)panel];

        CHECK((id)p.colorPanel == panel, "colorPanel stored");
        CHECK(p.pickerMask == 0xffff, "picker mask stored");

        /* measured: base tool tip defaults to the class name */
        CHECK([p.buttonToolTip isEqual:@"NSColorPicker"], "buttonToolTip defaults to class name");

        /* abstract members return zero/nil in this core (subclass responsibility) */
        CHECK(p.provideNewButtonImage == nil, "base provideNewButtonImage nil");
        CHECK(CGSizeEqualToSize(p.minContentSize, CGSizeZero), "base minContentSize zero");

        /* setMode stores; hooks are no-ops that must not crash */
        [p setMode:7];
        CHECK(p.currentMode == 7, "setMode stored");
        [p attachColorList:nil]; [p detachColorList:nil];
        [p alphaControlAddedOrRemoved:nil]; [p viewSizeChanged:nil];
        CHECK(1, "base hooks are safe no-ops");

        /* subclass overrides tool tip */
        MyPicker *mp = [[MyPicker alloc] initWithPickerMask:1 colorPanel:(id)panel];
        CHECK([mp.buttonToolTip isEqual:@"My Colors"], "subclass tool tip overrides");
        CHECK(mp.pickerMask == 1, "subclass carries mask");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
