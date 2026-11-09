/* test_nstextblock.m — NSTextBlock dimension + layer-width stores. */
#import "../src/NSTextBlock.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSTextBlock *b = [[NSTextBlock alloc] init];
        CHECK([b valueForDimension:NSTextBlockWidth] == 0, "dimension default 0");
        CHECK([b valueTypeForDimension:NSTextBlockWidth] == NSTextBlockAbsoluteValueType, "dimension type default absolute");
        CHECK(b.verticalAlignment == NSTextBlockTopAlignment, "vertical alignment default top");

        [b setValue:200 type:NSTextBlockAbsoluteValueType forDimension:NSTextBlockWidth];
        [b setValue:50 type:NSTextBlockPercentageValueType forDimension:NSTextBlockMaximumWidth];
        CHECK([b valueForDimension:NSTextBlockWidth] == 200, "width value stored");
        CHECK([b valueForDimension:NSTextBlockMaximumWidth] == 50, "max-width value stored");
        CHECK([b valueTypeForDimension:NSTextBlockMaximumWidth] == NSTextBlockPercentageValueType, "max-width type percentage");

        /* contentWidth maps to the Width dimension */
        CHECK(b.contentWidth == 200, "contentWidth reflects Width dimension");
        [b setContentWidth:300 type:NSTextBlockAbsoluteValueType];
        CHECK([b valueForDimension:NSTextBlockWidth] == 300, "setContentWidth updates Width dimension");

        /* layer widths per edge */
        [b setWidth:4 type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockBorder edge:NSMinXEdge];
        CHECK([b widthForLayer:NSTextBlockBorder edge:NSMinXEdge] == 4, "border MinX width stored");
        CHECK([b widthForLayer:NSTextBlockBorder edge:NSMaxXEdge] == 0, "other edge still 0");

        /* set-all-edges convenience */
        [b setWidth:8 type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockPadding];
        CHECK([b widthForLayer:NSTextBlockPadding edge:NSMinXEdge] == 8, "padding MinX set by all-edges");
        CHECK([b widthForLayer:NSTextBlockPadding edge:NSMaxYEdge] == 8, "padding MaxY set by all-edges");
        /* padding uses layer -1: distinct storage from border */
        CHECK([b widthForLayer:NSTextBlockBorder edge:NSMinXEdge] == 4, "border MinX unaffected by padding set");

        b.verticalAlignment = NSTextBlockMiddleAlignment;
        id color = [NSObject new];
        b.backgroundColor = color;
        CHECK(b.verticalAlignment == NSTextBlockMiddleAlignment, "vertical alignment set");
        CHECK(b.backgroundColor == color, "background color set");

        /* copy independence */
        NSTextBlock *c = [b copy];
        [c setContentWidth:999 type:NSTextBlockAbsoluteValueType];
        CHECK(b.contentWidth == 300, "copy independent");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
