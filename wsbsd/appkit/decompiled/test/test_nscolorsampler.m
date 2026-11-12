/* test_nscolorsampler.m */
#import "../src/NSColorSampler.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

@interface NSColorSampler (TestInternals)
- (void)selectedColor:(id)color;
@end

int main(void) {
    @autoreleasepool {
        NSColorSampler *s = [[NSColorSampler alloc] init];
        CHECK(s != nil, "sampler created");

        /* show queues a handler; selectedColor: fires it with the picked color */
        __block id picked = (id)@"sentinel";
        __block int calls = 0;
        [s showSamplerWithSelectionHandler:^(id c) { picked = c; calls++; }];
        CHECK(calls == 0, "handler not fired until a colour is selected");
        id color = [NSObject new];
        [s selectedColor:(id)color];
        CHECK(calls == 1 && picked == color, "selectedColor fires the handler with the colour");

        /* queue cleared after delivery */
        [s selectedColor:(id)color];
        CHECK(calls == 1, "handlers cleared after delivery");

        /* cancellation delivers nil */
        __block id got = (id)@"x";
        [s showSamplerWithSelectionHandler:^(id c) { got = c; }];
        [s selectedColor:nil];
        CHECK(got == nil, "cancellation delivers nil colour");

        /* multiple pending handlers all fire */
        __block int n = 0;
        [s showSamplerWithSelectionHandler:^(id c) { n++; }];
        [s showSamplerWithSelectionHandler:^(id c) { n++; }];
        [s selectedColor:(id)color];
        CHECK(n == 2, "all queued handlers fire");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
