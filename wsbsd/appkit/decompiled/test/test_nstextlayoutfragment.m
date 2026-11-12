/* test_nstextlayoutfragment.m */
#import "../src/NSTextLayoutFragment.h"
#import "../src/NSTextElement.h"
#import "../src/NSTextLineFragment.h"

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

int main(void) {
    @autoreleasepool {
        NSTextElement *el = [[NSTextElement alloc] initWithTextContentManager:nil];
        NSTextRange *range = [[NSTextRange alloc] initWithLocation:L(0) endLocation:L(2)];
        el.elementRange = range;

        NSTextLayoutFragment *f = [[NSTextLayoutFragment alloc] initWithTextElement:el range:range];
        /* measured pre-layout state */
        CHECK(f.textElement == el, "textElement same object (weak)");
        CHECK(f.rangeInElement == range, "rangeInElement same object");
        CHECK(f.textLineFragments == nil, "textLineFragments nil until laid out");
        CHECK(f.state == NSTextLayoutFragmentStateNone, "state None default");
        CHECK(CGRectEqualToRect(f.layoutFragmentFrame, CGRectZero), "layoutFragmentFrame zero");
        CHECK(CGRectEqualToRect(f.renderingSurfaceBounds, CGRectZero), "renderingSurfaceBounds zero");
        CHECK(f.textLayoutManager == nil, "textLayoutManager nil default");

        /* enum */
        CHECK(NSTextLayoutFragmentStateNone == 0 && NSTextLayoutFragmentStateLayoutAvailable == 3, "state enum");

        /* engine populates layout */
        NSTextLineFragment *line = [[NSTextLineFragment alloc] initWithString:@"hi" attributes:@{} range:NSMakeRange(0,2)];
        [f setTextLineFragments:@[line]];
        [f setLayoutFragmentFrame:CGRectMake(0,0,50,16)];
        f.state = NSTextLayoutFragmentStateLayoutAvailable;
        CHECK(f.textLineFragments.count == 1, "line fragments populated");
        CHECK(f.layoutFragmentFrame.size.width == 50, "frame populated");
        CHECK(f.state == NSTextLayoutFragmentStateLayoutAvailable, "state advanced");
        id tlm = [NSObject new]; [f setTextLayoutManager:(id)tlm];
        CHECK((id)f.textLayoutManager == tlm, "textLayoutManager wired");

        /* invalidateLayout resets */
        [f invalidateLayout];
        CHECK(f.state == NSTextLayoutFragmentStateNone, "invalidate resets state");
        CHECK(f.textLineFragments == nil, "invalidate clears line fragments");
        CHECK(CGRectEqualToRect(f.layoutFragmentFrame, CGRectZero), "invalidate clears frame");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
