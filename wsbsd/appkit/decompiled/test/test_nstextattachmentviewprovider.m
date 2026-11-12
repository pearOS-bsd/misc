/* test_nstextattachmentviewprovider.m */
#import "../src/NSTextAttachmentViewProvider.h"

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

/* a subclass that actually loads a view, like a real provider */
@interface MyProvider : NSTextAttachmentViewProvider
@property BOOL loaded;
@end
@implementation MyProvider
- (void)loadView { self.loaded = YES; self.view = (id)[NSObject new]; }
@end

int main(void) {
    @autoreleasepool {
        id att = [NSObject new];          /* stand-in NSTextAttachment */
        Loc *loc = [Loc new]; loc.v = 4;

        NSTextAttachmentViewProvider *vp =
            [[NSTextAttachmentViewProvider alloc] initWithTextAttachment:(id)att
                                                             parentView:nil
                                                      textLayoutManager:nil
                                                               location:loc];
        /* measured defaults */
        CHECK((id)vp.textAttachment == att, "textAttachment stored (weak)");
        CHECK(vp.textLayoutManager == nil, "textLayoutManager nil");
        CHECK((id)vp.location == loc, "location stored");
        CHECK(vp.view == nil, "view nil default");
        CHECK(!vp.tracksTextAttachmentViewBounds, "tracks NO default");

        /* base loadView leaves view nil */
        [vp loadView];
        CHECK(vp.view == nil, "base loadView leaves view nil");

        /* base attachment bounds = zero */
        CGRect b = [vp attachmentBoundsForAttributes:@{}
                                            location:loc
                                       textContainer:nil
                                proposedLineFragment:CGRectMake(0,0,100,20)
                                            position:CGPointZero];
        CHECK(CGRectEqualToRect(b, CGRectZero), "base attachment bounds zero");

        /* setters */
        vp.tracksTextAttachmentViewBounds = YES;
        CHECK(vp.tracksTextAttachmentViewBounds, "tracks set");
        id v = [NSObject new]; vp.view = (id)v;
        CHECK((id)vp.view == v, "view set");
        Loc *loc2 = [Loc new]; loc2.v = 9; vp.location = loc2;
        CHECK((id)vp.location == loc2, "location set");

        /* subclass that loads a view */
        MyProvider *mp = [[MyProvider alloc] initWithTextAttachment:(id)att parentView:nil textLayoutManager:nil location:loc];
        [mp loadView];
        CHECK(mp.loaded && mp.view != nil, "subclass loadView creates a view");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
