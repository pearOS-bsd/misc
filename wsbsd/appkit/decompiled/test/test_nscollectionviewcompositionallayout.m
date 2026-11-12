/* test_nscollectionviewcompositionallayout.m */
#import "../src/NSCollectionViewCompositionalLayout.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

@interface NSCollectionViewCompositionalLayout (Testing)
- (NSCollectionLayoutSection *)_sectionForIndex:(NSInteger)index environment:(id)environment;
@end

static NSCollectionLayoutSection *mkSection(void) {
    NSCollectionLayoutSize *sz = [NSCollectionLayoutSize
        sizeWithWidthDimension:[NSCollectionLayoutDimension fractionalWidthDimension:1]
               heightDimension:[NSCollectionLayoutDimension absoluteDimension:44]];
    NSCollectionLayoutItem *item = [NSCollectionLayoutItem itemWithLayoutSize:sz];
    NSCollectionLayoutGroup *g = [NSCollectionLayoutGroup verticalGroupWithLayoutSize:sz subitems:@[item]];
    return [NSCollectionLayoutSection sectionWithGroup:g];
}

int main(void) {
    @autoreleasepool {
        NSCollectionLayoutSection *sec = mkSection();
        NSCollectionViewCompositionalLayout *l = [[NSCollectionViewCompositionalLayout alloc] initWithSection:sec];

        CHECK([l isKindOfClass:[NSCollectionViewLayout class]], "is-a NSCollectionViewLayout");
        CHECK(l.configuration != nil, "configuration auto-created (non-nil, measured)");
        CHECK(l.configuration.scrollDirection == NSCollectionViewScrollDirectionVertical, "default config vertical");
        CHECK([l _sectionForIndex:0 environment:nil] == sec, "fixed section resolves for any index");
        CHECK([l _sectionForIndex:5 environment:nil] == sec, "fixed section same for other index");

        /* configuration settable */
        NSCollectionViewCompositionalLayoutConfiguration *cfg = [[NSCollectionViewCompositionalLayoutConfiguration alloc] init];
        cfg.interSectionSpacing = 10;
        l.configuration = cfg;
        CHECK(l.configuration.interSectionSpacing == 10, "configuration set");

        /* section-provider initializer */
        __block NSInteger lastIndex = -1;
        NSCollectionViewCompositionalLayout *lp = [[NSCollectionViewCompositionalLayout alloc]
            initWithSectionProvider:^NSCollectionLayoutSection *(NSInteger section, id env) { lastIndex = section; return mkSection(); }];
        CHECK(lp.configuration != nil, "provider init auto-config");
        NSCollectionLayoutSection *resolved = [lp _sectionForIndex:3 environment:nil];
        CHECK(resolved != nil && lastIndex == 3, "provider invoked with the section index");

        /* explicit configuration initializer */
        NSCollectionViewCompositionalLayout *lc = [[NSCollectionViewCompositionalLayout alloc] initWithSection:sec configuration:cfg];
        CHECK(lc.configuration.interSectionSpacing == 10, "explicit configuration carried");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
