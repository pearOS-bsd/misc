/* test_nstextlinefragment.m */
#import "../src/NSTextLineFragment.h"
#import <Foundation/Foundation.h>

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSAttributedString *as = [[NSAttributedString alloc] initWithString:@"Hello"];
        NSTextLineFragment *lf = [[NSTextLineFragment alloc] initWithAttributedString:as range:NSMakeRange(0,5)];

        CHECK(lf.attributedString == as, "attributedString stored");
        CHECK(lf.characterRange.location == 0 && lf.characterRange.length == 5, "characterRange stored");

        /* measured standalone contract: all geometry zero until laid out */
        CHECK(CGPointEqualToPoint(lf.glyphOrigin, CGPointZero), "glyphOrigin zero until laid out");
        CHECK(CGRectEqualToRect(lf.typographicBounds, CGRectZero), "typographicBounds zero until laid out");
        CHECK(CGPointEqualToPoint([lf locationForCharacterAtIndex:2], CGPointZero), "locationForCharacterAtIndex zero standalone");
        CHECK([lf characterIndexForPoint:CGPointMake(20,5)] == 0, "characterIndexForPoint = range start standalone");

        /* string+attributes initializer */
        NSTextLineFragment *lf2 = [[NSTextLineFragment alloc] initWithString:@"Hi" attributes:@{} range:NSMakeRange(3,2)];
        CHECK([lf2.attributedString.string isEqual:@"Hi"], "string init builds attributed string");
        CHECK(lf2.characterRange.location == 3, "range from string init");
        CHECK([lf2 characterIndexForPoint:CGPointZero] == 3, "characterIndexForPoint uses range start");

        /* engine fills geometry; getters reflect it */
        [lf setGlyphOrigin:CGPointMake(2,3)];
        [lf setTypographicBounds:CGRectMake(0,0,40,15)];
        CHECK(CGPointEqualToPoint(lf.glyphOrigin, CGPointMake(2,3)), "glyphOrigin set by engine");
        CHECK(lf.typographicBounds.size.width == 40, "typographicBounds set by engine");

        /* stored flags */
        lf.padding = 1.5; CHECK(lf.padding == 1.5, "padding set");
        lf.extra = YES; CHECK(lf.isExtra, "isExtra set");
        id tlf = [NSObject new]; lf.textLayoutFragment = (id)tlf;
        CHECK((id)lf.textLayoutFragment == tlf, "textLayoutFragment weak set");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
