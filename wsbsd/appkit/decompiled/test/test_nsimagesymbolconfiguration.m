/* test — NSImageSymbolConfiguration factories + layering. */
#import "../src/NSImageSymbolConfiguration.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSImageSymbolConfiguration *ps = [NSImageSymbolConfiguration configurationWithPointSize:18 weight:0.4 scale:NSImageSymbolScaleLarge];
        CHECK(ps.pointSize == 18, "point size set");
        CHECK(ps.weight == 0.4, "weight set");
        CHECK(ps.scale == NSImageSymbolScaleLarge, "scale set");
        CHECK(!ps.prefersMulticolor, "not multicolor");

        NSImageSymbolConfiguration *sc = [NSImageSymbolConfiguration configurationWithScale:NSImageSymbolScaleSmall];
        CHECK(sc.scale == NSImageSymbolScaleSmall && sc.pointSize == 0, "scale-only config");

        NSImageSymbolConfiguration *mc = [NSImageSymbolConfiguration configurationPreferringMulticolor];
        CHECK(mc.prefersMulticolor, "multicolor config");

        id color = [NSObject new];
        NSImageSymbolConfiguration *hc = [NSImageSymbolConfiguration configurationWithHierarchicalColor:color];
        CHECK(hc.colors.count == 1 && hc.colors[0] == color, "hierarchical color stored");

        /* layering: scale-only on top of point-size config keeps size/weight, overrides scale */
        NSImageSymbolConfiguration *merged = [ps configurationByApplyingConfiguration:sc];
        CHECK(merged.pointSize == 18, "merge keeps point size");
        CHECK(merged.weight == 0.4, "merge keeps weight");
        CHECK(merged.scale == NSImageSymbolScaleSmall, "merge overrides scale");

        /* layering multicolor preserves earlier size */
        NSImageSymbolConfiguration *merged2 = [ps configurationByApplyingConfiguration:mc];
        CHECK(merged2.prefersMulticolor, "merge applies multicolor");
        CHECK(merged2.pointSize == 18, "merge keeps point size under multicolor");

        /* original unchanged (copy semantics) */
        CHECK(ps.scale == NSImageSymbolScaleLarge, "original config unchanged by merge");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
