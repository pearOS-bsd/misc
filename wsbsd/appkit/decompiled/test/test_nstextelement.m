/* test_nstextelement.m */
#import "../src/NSTextElement.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

@interface Loc : NSObject <NSTextLocation>
@property NSInteger v;
@end
@implementation Loc
- (NSComparisonResult)compare:(id<NSTextLocation>)o { NSInteger b = [(Loc *)o v]; return _v < b ? NSOrderedAscending : (_v > b ? NSOrderedDescending : NSOrderedSame); }
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[Loc class]] && [(Loc *)o v] == _v; }
- (NSUInteger)hash { return (NSUInteger)_v; }
@end
static Loc *L(NSInteger v) { Loc *l = [Loc new]; l.v = v; return l; }

/* expose the internal wiring for the test */
@interface NSTextElement (Testing)
- (void)_addChildElement:(NSTextElement *)child;
@end

int main(void) {
    @autoreleasepool {
        NSTextElement *e = [[NSTextElement alloc] initWithTextContentManager:nil];
        /* measured defaults */
        CHECK(e.elementRange == nil, "elementRange nil default");
        CHECK(e.childElements != nil && e.childElements.count == 0, "childElements empty array default");
        CHECK(e.parentElement == nil, "parentElement nil default");
        CHECK(e.isRepresentedElement, "isRepresentedElement YES default");
        CHECK(e.textContentManager == nil, "textContentManager nil");
        CHECK(e.coalescingType == 0, "coalescingType 0 default");

        /* elementRange settable */
        NSTextRange *r = [[NSTextRange alloc] initWithLocation:L(0) endLocation:L(4)];
        e.elementRange = r;
        CHECK(e.elementRange == r, "elementRange set");

        /* weak content manager */
        id cm = [NSObject new];
        e.textContentManager = (id)cm;
        CHECK((id)e.textContentManager == cm, "textContentManager set");

        /* coalescingType */
        e.coalescingType = 2;
        CHECK(e.coalescingType == 2, "coalescingType set");

        /* internal child wiring: parent/child relationship */
        NSTextElement *c1 = [[NSTextElement alloc] initWithTextContentManager:nil];
        NSTextElement *c2 = [[NSTextElement alloc] initWithTextContentManager:nil];
        [e _addChildElement:c1];
        [e _addChildElement:c2];
        CHECK(e.childElements.count == 2, "two children added");
        CHECK(c1.parentElement == e && c2.parentElement == e, "children reference parent");
        [e _addChildElement:c1];
        CHECK(e.childElements.count == 2, "duplicate child add deduped");

        /* childElements getter returns an independent copy */
        NSArray *snapshot = e.childElements;
        [e _addChildElement:[[NSTextElement alloc] initWithTextContentManager:nil]];
        CHECK(snapshot.count == 2, "previously returned childElements is a snapshot");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
