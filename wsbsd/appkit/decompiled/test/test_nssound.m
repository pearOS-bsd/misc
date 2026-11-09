/* test_nssound.m — NSSound: volume clamp, loops, name, isPlaying. */
#import "../src/NSSound.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSSound *s = [[NSSound alloc] init];
        CHECK(s.volume == 1.0f, "default volume 1");
        CHECK(s.loops == NO, "loops defaults NO");
        CHECK(s.isPlaying == NO, "not playing initially");

        s.volume = 0.5f;
        CHECK(s.volume == 0.5f, "volume in range");
        s.volume = 2.0f;
        CHECK(s.volume == 1.0f, "volume clamped to 1");
        s.volume = -1.0f;
        CHECK(s.volume == 0.0f, "volume clamped to 0");

        s.loops = YES;
        CHECK(s.loops == YES, "loops round-trips");
        /* loops (bit0) and playing (bit1) are independent */
        CHECK(s.isPlaying == NO, "setting loops does not start playback");

        s.name = @"Submarine";
        CHECK([s.name isEqualToString:@"Submarine"], "name round-trips");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
