/* test_nstextparagraph.m */
#import "../src/NSTextParagraph.h"
#import <Foundation/Foundation.h>

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
        NSAttributedString *as = [[NSAttributedString alloc] initWithString:@"Hello"];
        NSTextParagraph *p = [[NSTextParagraph alloc] initWithAttributedString:as];

        CHECK([p isKindOfClass:[NSTextElement class]], "is NSTextElement");
        CHECK(p.attributedString == as, "attributedString is same object");
        CHECK([p.attributedString.string isEqual:@"Hello"], "string content");
        CHECK(p.paragraphContentRange == nil, "contentRange nil until assigned");
        CHECK(p.paragraphSeparatorRange == nil, "separatorRange nil until assigned");
        CHECK(p.isRepresentedElement, "inherits isRepresentedElement YES");

        /* nil init */
        NSTextParagraph *n = [[NSTextParagraph alloc] initWithAttributedString:nil];
        CHECK(n.attributedString == nil, "nil attributedString");

        /* ranges assignable (as a content manager would) */
        NSTextRange *content = [[NSTextRange alloc] initWithLocation:L(0) endLocation:L(5)];
        NSTextRange *sep = [[NSTextRange alloc] initWithLocation:L(5) endLocation:L(6)];
        p.paragraphContentRange = content;
        p.paragraphSeparatorRange = sep;
        CHECK(p.paragraphContentRange == content, "contentRange assigned");
        CHECK(p.paragraphSeparatorRange == sep, "separatorRange assigned");

        /* inherited elementRange still works */
        p.elementRange = [[NSTextRange alloc] initWithLocation:L(0) endLocation:L(6)];
        CHECK(p.elementRange != nil, "inherited elementRange settable");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
