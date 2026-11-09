/* test_nsimage.m — NSImage core: size derivation, name registry, reps. */
#import "../src/NSImage.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

/* Minimal NSImageRep stand-in exposing a size. */
@interface FakeRep : NSObject <NSImageRepSizing>
@property CGSize s;
@end
@implementation FakeRep
- (CGSize)size { return _s; }
+ (FakeRep *)repWithSize:(CGSize)s { FakeRep *r = [FakeRep new]; r.s = s; return r; }
@end

int main(void)
{
    @autoreleasepool {
        NSImage *img = [[NSImage alloc] initWithSize:CGSizeMake(64, 64)];
        CHECK(img.size.width == 64 && img.size.height == 64, "explicit size from init");
        CHECK(!img.isTemplate, "not a template by default");
        CHECK(img.representations.count == 0, "no reps initially");

        [img setTemplate:YES];
        CHECK(img.isTemplate, "setTemplate: sets template flag");

        /* name registry */
        CHECK([img setName:@"MyImage"], "setName: returns YES");
        CHECK([[img name] isEqualToString:@"MyImage"], "name stored");
        CHECK([NSImage imageNamed:@"MyImage"] == img, "imageNamed: returns the registered image");
        CHECK([NSImage imageNamed:@"Nonexistent"] == nil, "unknown name -> nil");

        /* reps */
        [img addRepresentation:[FakeRep repWithSize:CGSizeMake(32, 32)]];
        [img addRepresentation:[FakeRep repWithSize:CGSizeMake(16, 16)]];
        CHECK(img.representations.count == 2, "two reps added");

        /* size derivation when not explicitly set */
        NSImage *derived = [[NSImage alloc] initWithSize:CGSizeZero];
        [derived addRepresentation:[FakeRep repWithSize:CGSizeMake(10, 10)]];
        [derived addRepresentation:[FakeRep repWithSize:CGSizeMake(40, 40)]]; /* largest */
        [derived addRepresentation:[FakeRep repWithSize:CGSizeMake(20, 20)]];
        CHECK(derived.size.width == 40 && derived.size.height == 40, "size derives from largest rep");

        /* explicit size overrides derivation */
        derived.size = CGSizeMake(5, 5);
        CHECK(derived.size.width == 5, "explicit setSize: overrides rep-derived size");

        /* removal */
        id<NSImageRepSizing> r = [FakeRep repWithSize:CGSizeMake(8, 8)];
        [img addRepresentation:r];
        CHECK(img.representations.count == 3, "rep added");
        [img removeRepresentation:r];
        CHECK(img.representations.count == 2, "rep removed");

        /* re-registering a new image under same name replaces */
        NSImage *img2 = [[NSImage alloc] initWithSize:CGSizeMake(8, 8)];
        [img2 setName:@"MyImage"];
        CHECK([NSImage imageNamed:@"MyImage"] == img2, "re-registering name replaces mapping");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
