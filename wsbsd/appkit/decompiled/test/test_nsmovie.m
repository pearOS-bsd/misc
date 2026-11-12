/* test_nsmovie.m */
#import "../src/NSMovie.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        /* plain init: empty wrapper (measured) */
        NSMovie *m = [[NSMovie alloc] init];
        CHECK(m != nil, "init returns an instance");
        CHECK(m.data == nil, "data nil (no public data initializer)");
        CHECK(m.URL == nil, "URL nil");
        CHECK(m.QTMovie == nil, "QTMovie nil (QuickTime removed)");

        /* NSCoding round-trips _data/_URL */
        NSKeyedArchiver *a = [[NSKeyedArchiver alloc] initRequiringSecureCoding:NO];
        /* seed via archive: encode a movie that a subclass/archive populated — here
           we exercise the coder path by hand through a dictionary-free archive. */
        NSMovie *seed = [[NSMovie alloc] init];
        [a encodeObject:seed forKey:@"root"];
        [a finishEncoding];
        NSKeyedUnarchiver *u = [[NSKeyedUnarchiver alloc] initForReadingFromData:a.encodedData error:NULL];
        u.requiresSecureCoding = NO;
        NSMovie *decoded = [u decodeObjectForKey:@"root"];
        CHECK([decoded isKindOfClass:[NSMovie class]], "coding round-trip yields an NSMovie");
        CHECK(decoded.data == nil && decoded.URL == nil, "empty movie stays empty after coding");

        /* initWithMovie: copies data/URL (both nil here) */
        NSMovie *copy = [[NSMovie alloc] initWithMovie:m];
        CHECK(copy != nil && copy.data == nil, "initWithMovie copies (empty)");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
